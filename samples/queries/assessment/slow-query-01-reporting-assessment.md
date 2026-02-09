# Assessment Report: Monthly Revenue Report

> **Source File:** `samples/queries/before/slow-query-01-reporting.sql`
> **Assessed On:** 2026-02-09
> **Database:** ECommerceDemo (SQL Server 2019/2022)

---

## Summary

| Metric               | Value                              |
|----------------------|------------------------------------|
| Total Issues Found   | 7                                  |
| Critical             | 3                                  |
| High                 | 2                                  |
| Medium               | 1                                  |
| Low                  | 1                                  |
| Overall Risk Rating  | Critical                           |

---

## Performance Issues Found

### Issue 1: Non-SARGable Date Functions on `sale_date`
- **Severity**: Critical
- **Category**: SARGability
- **Problem**: `YEAR(sh.sale_date)`, `MONTH(sh.sale_date)`, and `DATENAME(MONTH, sh.sale_date)` are applied directly to the `sale_date` column throughout the query — in the `GROUP BY` clause, correlated subquery `WHERE` clauses, and `ORDER BY`. Wrapping a column in a function prevents SQL Server from performing an index seek on that column.
- **Impact**: Every reference to `sale_date` forces a full table/index scan on `SalesHistory`, even if a nonclustered index exists on `sale_date`. This is multiplied across every correlated subquery, resulting in potentially 6+ full scans per query execution.
- **Line(s)**: 29–31 (SELECT list), 39–40, 46–47, 53–54, 58–59, 62–63, 69–70 (correlated subquery WHERE clauses), 76–78 (GROUP BY)

### Issue 2: Correlated Subqueries in SELECT List (N+1 Pattern)
- **Severity**: Critical
- **Category**: Subqueries
- **Problem**: Four separate correlated subqueries appear in the SELECT list (`prev_month_revenue`, `same_month_last_year`, `yoy_growth_pct` block, `top_product`). Each correlated subquery executes once per output row (one per distinct year/month combination). This is the classic N+1 query pattern.
- **Impact**: If there are 36 year/month groups, the correlated subqueries execute up to 36 × 6 = 216 additional scans of `SalesHistory` (6 subquery references total). This produces catastrophic I/O amplification on large tables.
- **Line(s)**: 38–42, 44–49, 51–64, 66–73

### Issue 3: Duplicated Correlated Subqueries for YoY Calculation
- **Severity**: Critical
- **Category**: Subqueries
- **Problem**: The YoY growth percentage calculation on lines 51–64 contains three separate correlated subqueries (`s4`, `s5`, `s6`) that all query the exact same data — `SUM(revenue)` for the same month in the previous year. This triples the cost of what should be a single lookup.
- **Impact**: Three redundant full scans of `SalesHistory` per output row, all returning the same result. These could be replaced by a single CTE or window function (`LAG`) to compute YoY values with zero additional scans.
- **Line(s)**: 51–64

### Issue 4: Correlated Subquery for Top Product per Month
- **Severity**: High
- **Category**: Subqueries
- **Problem**: The `top_product` subquery (lines 66–73) joins `SalesHistory` to `Products`, groups by `p.name`, and orders by `SUM(sub.revenue)` — once for every output row. This is an expensive aggregation repeated N times.
- **Impact**: For each year/month group, SQL Server must scan `SalesHistory`, join to `Products`, aggregate, and sort. This is significantly more expensive than the scalar subqueries because it involves a join and a sort operator per execution.
- **Line(s)**: 66–73

### Issue 5: Redundant Table Scans Across Subqueries
- **Severity**: High
- **Category**: Aggregation
- **Problem**: The main query scans `SalesHistory` once for the outer `GROUP BY`, and then each correlated subquery triggers additional scans. All of these subqueries could instead be satisfied by a single pass over `SalesHistory` using window functions (`LAG`, `SUM() OVER`) or pre-aggregated CTEs.
- **Impact**: Total logical reads scale as `O(N × S)` where N = number of output rows and S = number of subqueries. Replacing with a single-pass CTE approach reduces this to `O(1)` scan of the table.
- **Line(s)**: 28–79 (entire query structure)

### Issue 6: Unnecessary DISTINCT with GROUP BY
- **Severity**: Medium
- **Category**: Aggregation
- **Problem**: `SELECT DISTINCT` is used on line 28, but the query already has a `GROUP BY YEAR(sh.sale_date), MONTH(sh.sale_date), DATENAME(MONTH, sh.sale_date)` on lines 76–78, which guarantees unique rows. The `DISTINCT` forces an additional sort/hash operation that is completely redundant.
- **Impact**: An extra sort or hash match operator appears in the execution plan, consuming CPU and memory for no benefit. On large result sets this adds measurable overhead.
- **Line(s)**: 28

### Issue 7: Implicit Conversion Risk on `sale_date` Predicates
- **Severity**: Low
- **Category**: SARGability
- **Problem**: The comment header mentions implicit conversion as an intended anti-pattern. While no explicit `CONVERT` is visible, the `YEAR()` and `MONTH()` return `INT`, and comparisons like `MONTH(s2.sale_date) = MONTH(sh.sale_date) - 1` perform arithmetic that does not handle the January boundary (month 1 − 1 = 0, which never matches December of the previous year). This is also a correctness bug for December → January transitions.
- **Impact**: Beyond performance, this is a **data correctness issue**: the `prev_month_revenue` column will return `NULL` for every January because `MONTH = 0` matches no rows. The fix (using `DATEADD`-based range predicates or `LAG`) solves both correctness and performance.
- **Line(s)**: 40

---

## Recommended Indexes

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| SalesHistory | `IX_SalesHistory_SaleDate` | `sale_date` | `revenue`, `cost`, `customer_id`, `product_id`, `region` | Enables range seeks on `sale_date` once predicates are rewritten to be SARGable; covers the main aggregation columns |
| SalesHistory | `IX_SalesHistory_ProductId_SaleDate` | `product_id`, `sale_date` | `revenue` | Supports the top-product subquery (or its CTE replacement) with a seek on `product_id` and range on `sale_date` |
| Products | `PK_Products` (existing) | `id` | — | Join to `Products` for top-product lookup; should already exist as the primary key |

---

## Performance Verification

```sql
-- Run these commands before and after applying the optimized query
-- to measure the improvement.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Original query (baseline) — from samples/queries/before/slow-query-01-reporting.sql
SELECT DISTINCT
    YEAR(sh.sale_date) AS sale_year,
    MONTH(sh.sale_date) AS sale_month,
    DATENAME(MONTH, sh.sale_date) AS month_name,
    SUM(sh.revenue) AS monthly_revenue,
    SUM(sh.cost) AS monthly_cost,
    SUM(sh.revenue) - SUM(sh.cost) AS monthly_profit,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT sh.customer_id) AS unique_customers,
    (SELECT SUM(s2.revenue)
     FROM SalesHistory s2
     WHERE YEAR(s2.sale_date) = YEAR(sh.sale_date)
       AND MONTH(s2.sale_date) = MONTH(sh.sale_date) - 1
    ) AS prev_month_revenue,
    (SELECT SUM(s3.revenue)
     FROM SalesHistory s3
     WHERE YEAR(s3.sale_date) = YEAR(sh.sale_date) - 1
       AND MONTH(s3.sale_date) = MONTH(sh.sale_date)
    ) AS same_month_last_year,
    CASE 
        WHEN (SELECT SUM(s4.revenue)
              FROM SalesHistory s4
              WHERE YEAR(s4.sale_date) = YEAR(sh.sale_date) - 1
                AND MONTH(s4.sale_date) = MONTH(sh.sale_date)) > 0
        THEN ROUND(
            (SUM(sh.revenue) - 
             (SELECT SUM(s5.revenue)
              FROM SalesHistory s5
              WHERE YEAR(s5.sale_date) = YEAR(sh.sale_date) - 1
                AND MONTH(s5.sale_date) = MONTH(sh.sale_date))
            ) / 
            (SELECT SUM(s6.revenue)
             FROM SalesHistory s6
             WHERE YEAR(s6.sale_date) = YEAR(sh.sale_date) - 1
               AND MONTH(s6.sale_date) = MONTH(sh.sale_date)) * 100
        , 2)
        ELSE NULL
    END AS yoy_growth_pct,
    (SELECT TOP 1 p.name
     FROM SalesHistory sub
     INNER JOIN Products p ON sub.product_id = p.id
     WHERE YEAR(sub.sale_date) = YEAR(sh.sale_date)
       AND MONTH(sub.sale_date) = MONTH(sh.sale_date)
     GROUP BY p.name
     ORDER BY SUM(sub.revenue) DESC
    ) AS top_product
FROM SalesHistory sh
GROUP BY 
    YEAR(sh.sale_date),
    MONTH(sh.sale_date),
    DATENAME(MONTH, sh.sale_date)
ORDER BY 
    sale_year DESC,
    sale_month DESC;

-- Optimized query here for comparison (after running @sql-performance-tuner)

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## Next Steps

1. Run `@sql-performance-tuner` agent to implement the fixes and optimized query based on this assessment.
2. Deploy recommended indexes in a non-production environment first.
3. Compare `SET STATISTICS IO/TIME` output before and after optimization.
4. Review execution plan with `SET SHOWPLAN_XML ON` to verify index seeks replace scans.
5. Monitor in production with `sys.dm_exec_query_stats` and `sys.dm_db_index_usage_stats`.
