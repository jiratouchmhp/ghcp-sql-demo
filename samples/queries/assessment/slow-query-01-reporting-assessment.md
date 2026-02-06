# Assessment Report: Monthly Revenue Report

> **Source File:** `samples/queries/before/slow-query-01-reporting.sql`
> **Assessed On:** 2026-02-06
> **Database:** ECommerceDemo (SQL Server 2019/2022)

---

## Summary

| Metric               | Value                              |
|----------------------|------------------------------------|
| Total Issues Found   | 7                                  |
| Critical             | 2                                  |
| High                 | 3                                  |
| Medium               | 1                                  |
| Low                  | 1                                  |
| Overall Risk Rating  | Critical                           |

---

## Performance Issues Found

### Issue 1: Non-SARGable Date Functions in GROUP BY and WHERE
- **Severity**: Critical
- **Category**: SARGability
- **Problem**: `YEAR(sh.sale_date)` and `MONTH(sh.sale_date)` are applied directly to the `sale_date` column in the `GROUP BY` clause and in every correlated subquery's `WHERE` clause. Wrapping a column in a function prevents SQL Server from performing an index seek on that column.
- **Impact**: Forces a full table/index scan on `SalesHistory` for every reference to `sale_date`. With a large fact table, this turns what could be a range seek into an O(n) scan. This is also repeated in each correlated subquery, multiplying the scan cost.
- **Line(s)**: 29-30 (GROUP BY), 38-39, 44-45, 51-52, 56-57, 60-61, 66-67

### Issue 2: Multiple Correlated Subqueries in SELECT (N+1 Pattern)
- **Severity**: Critical
- **Category**: Subqueries
- **Problem**: Six correlated subqueries (`s2` through `s6`, plus `sub`) each execute once per output row. They all scan `SalesHistory` to compute prior-period metrics and top product. Three of these (`s4`, `s5`, `s6`) compute the exact same value — same month last year's revenue.
- **Impact**: For R output rows, the query performs approximately 6×R additional scans of `SalesHistory`. With ~60 months of data, that's ~360 extra scans of the entire fact table. This is the single largest performance bottleneck.
- **Line(s)**: 36-40, 43-47, 50-63, 66-72

### Issue 3: Duplicated Correlated Subqueries for YoY Calculation
- **Severity**: High
- **Category**: Subqueries
- **Problem**: The YoY growth percentage calculation uses three separate correlated subqueries (`s4`, `s5`, `s6`) that all compute `SUM(revenue)` for the same month in the prior year. This identical work is performed three times per output row.
- **Impact**: Triples the I/O cost for the YoY calculation. Even without the broader correlated-subquery issue, this duplication alone adds two unnecessary full scans per row.
- **Line(s)**: 50-63

### Issue 4: Correlated Subquery for Previous Month Revenue Has a Logic Bug
- **Severity**: High
- **Category**: Subqueries
- **Problem**: The previous month subquery uses `MONTH(s2.sale_date) = MONTH(sh.sale_date) - 1`. When `MONTH(sh.sale_date) = 1` (January), this evaluates to `MONTH(s2.sale_date) = 0`, which matches no rows. It should wrap around to December of the prior year.
- **Impact**: Returns `NULL` for every January row instead of December's revenue, producing incorrect results in the report.
- **Line(s)**: 38-39

### Issue 5: Unnecessary DISTINCT
- **Severity**: High
- **Category**: Aggregation
- **Problem**: `SELECT DISTINCT` is applied to a query that already has a `GROUP BY` on `YEAR(sh.sale_date), MONTH(sh.sale_date), DATENAME(MONTH, sh.sale_date)`. The `GROUP BY` guarantees uniqueness of these columns, making `DISTINCT` redundant.
- **Impact**: Forces an additional sort/hash operation on the entire result set after aggregation. On large result sets this adds CPU and tempdb I/O. More importantly, it masks potential logic errors — if `DISTINCT` is needed, the `GROUP BY` is likely wrong.
- **Line(s)**: 28

### Issue 6: Correlated Subquery for Top Product per Month
- **Severity**: Medium
- **Category**: Subqueries
- **Problem**: A correlated subquery joins `SalesHistory` with `Products`, groups by product name, and sorts by revenue to find the top product per month. This executes once per output row and includes its own aggregation, making it particularly expensive.
- **Impact**: Adds a full scan + join + aggregation + sort for each output row. This subquery alone can dominate total execution time if the `Products` table is not trivially small.
- **Line(s)**: 66-72

### Issue 7: Implicit Conversion Risk on sale_date Comparisons
- **Severity**: Low
- **Category**: SARGability
- **Problem**: While no explicit `CONVERT` is used, the `YEAR()` and `MONTH()` functions implicitly return integers, and integer comparisons against them are safe. However, the current pattern prevents any future date-range partitioning or parameterized filtering from being SARGable.
- **Impact**: Minor, but locks the query into a scan-only access path for `sale_date`. Refactoring to date-range predicates enables future partition elimination.
- **Line(s)**: 29-30, 38-39, 44-45

---

## Optimized Query

```sql
-- =============================================
-- Optimized Query: Monthly Revenue Report
-- Fixes Applied:
--   1. Replaced YEAR()/MONTH() with date truncation for SARGability
--   2. Replaced all correlated subqueries with CTEs + window functions
--   3. Removed unnecessary DISTINCT
--   4. Fixed previous-month logic (January → December prior year)
--   5. Single scan of SalesHistory for all metrics
-- =============================================

USE ECommerceDemo;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

WITH MonthlySales AS (
    -- Single pass: aggregate SalesHistory by month
    SELECT
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1) AS month_start,
        YEAR(sh.sale_date)                                        AS sale_year,
        MONTH(sh.sale_date)                                       AS sale_month,
        DATENAME(MONTH, sh.sale_date)                             AS month_name,
        SUM(sh.revenue)                                           AS monthly_revenue,
        SUM(sh.cost)                                              AS monthly_cost,
        SUM(sh.revenue) - SUM(sh.cost)                            AS monthly_profit,
        COUNT(*)                                                  AS total_transactions,
        COUNT(DISTINCT sh.customer_id)                            AS unique_customers
    FROM dbo.SalesHistory AS sh
    GROUP BY
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1),
        YEAR(sh.sale_date),
        MONTH(sh.sale_date),
        DATENAME(MONTH, sh.sale_date)
),
MonthlyWithComparisons AS (
    -- Use LAG() to get previous-month and same-month-last-year revenue
    SELECT
        ms.sale_year,
        ms.sale_month,
        ms.month_name,
        ms.monthly_revenue,
        ms.monthly_cost,
        ms.monthly_profit,
        ms.total_transactions,
        ms.unique_customers,
        LAG(ms.monthly_revenue, 1)  OVER (ORDER BY ms.month_start) AS prev_month_revenue,
        LAG(ms.monthly_revenue, 12) OVER (ORDER BY ms.month_start) AS same_month_last_year
    FROM MonthlySales AS ms
),
TopProducts AS (
    -- Rank products per month in a single pass
    SELECT
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1) AS month_start,
        p.name                                                     AS product_name,
        SUM(sh.revenue)                                            AS product_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1)
            ORDER BY SUM(sh.revenue) DESC
        ) AS rn
    FROM dbo.SalesHistory AS sh
    INNER JOIN dbo.Products AS p
        ON sh.product_id = p.id
    GROUP BY
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1),
        p.name
)
SELECT
    mc.sale_year,
    mc.sale_month,
    mc.month_name,
    mc.monthly_revenue,
    mc.monthly_cost,
    mc.monthly_profit,
    mc.total_transactions,
    mc.unique_customers,
    mc.prev_month_revenue,
    mc.same_month_last_year,
    CASE
        WHEN mc.same_month_last_year > 0
        THEN ROUND(
            (mc.monthly_revenue - mc.same_month_last_year)
            / mc.same_month_last_year * 100, 2)
        ELSE NULL
    END AS yoy_growth_pct,
    tp.product_name AS top_product
FROM MonthlyWithComparisons AS mc
LEFT JOIN TopProducts AS tp
    ON tp.month_start = DATEFROMPARTS(mc.sale_year, mc.sale_month, 1)
    AND tp.rn = 1
ORDER BY
    mc.sale_year DESC,
    mc.sale_month DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## Recommended Indexes

```sql
-- Supporting index for the monthly aggregation on SalesHistory
-- Leading column: sale_date (enables range scans and date grouping)
-- INCLUDE: revenue, cost, customer_id, product_id (covers all referenced columns)
CREATE NONCLUSTERED INDEX IX_SalesHistory_SaleDate
ON dbo.SalesHistory (sale_date)
INCLUDE (revenue, cost, customer_id, product_id);

-- Supporting index for the TopProducts CTE (product_id join + revenue aggregation)
CREATE NONCLUSTERED INDEX IX_SalesHistory_ProductId_SaleDate
ON dbo.SalesHistory (product_id, sale_date)
INCLUDE (revenue);

-- If Products.id is not already the clustered PK, ensure a seek path exists
-- (Likely already covered by PK_Products)
-- CREATE NONCLUSTERED INDEX IX_Products_Id_Name
-- ON dbo.Products (id)
-- INCLUDE (name);
```

---

## Performance Verification

```sql
-- Run these commands before and after applying the optimized query
-- to measure the improvement.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- ========== ORIGINAL (BASELINE) ==========
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
GO

-- ========== OPTIMIZED ==========
WITH MonthlySales AS (
    SELECT
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1) AS month_start,
        YEAR(sh.sale_date)                                        AS sale_year,
        MONTH(sh.sale_date)                                       AS sale_month,
        DATENAME(MONTH, sh.sale_date)                             AS month_name,
        SUM(sh.revenue)                                           AS monthly_revenue,
        SUM(sh.cost)                                              AS monthly_cost,
        SUM(sh.revenue) - SUM(sh.cost)                            AS monthly_profit,
        COUNT(*)                                                  AS total_transactions,
        COUNT(DISTINCT sh.customer_id)                            AS unique_customers
    FROM dbo.SalesHistory AS sh
    GROUP BY
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1),
        YEAR(sh.sale_date),
        MONTH(sh.sale_date),
        DATENAME(MONTH, sh.sale_date)
),
MonthlyWithComparisons AS (
    SELECT
        ms.sale_year,
        ms.sale_month,
        ms.month_name,
        ms.monthly_revenue,
        ms.monthly_cost,
        ms.monthly_profit,
        ms.total_transactions,
        ms.unique_customers,
        LAG(ms.monthly_revenue, 1)  OVER (ORDER BY ms.month_start) AS prev_month_revenue,
        LAG(ms.monthly_revenue, 12) OVER (ORDER BY ms.month_start) AS same_month_last_year
    FROM MonthlySales AS ms
),
TopProducts AS (
    SELECT
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1) AS month_start,
        p.name                                                     AS product_name,
        SUM(sh.revenue)                                            AS product_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1)
            ORDER BY SUM(sh.revenue) DESC
        ) AS rn
    FROM dbo.SalesHistory AS sh
    INNER JOIN dbo.Products AS p
        ON sh.product_id = p.id
    GROUP BY
        DATEFROMPARTS(YEAR(sh.sale_date), MONTH(sh.sale_date), 1),
        p.name
)
SELECT
    mc.sale_year,
    mc.sale_month,
    mc.month_name,
    mc.monthly_revenue,
    mc.monthly_cost,
    mc.monthly_profit,
    mc.total_transactions,
    mc.unique_customers,
    mc.prev_month_revenue,
    mc.same_month_last_year,
    CASE
        WHEN mc.same_month_last_year > 0
        THEN ROUND(
            (mc.monthly_revenue - mc.same_month_last_year)
            / mc.same_month_last_year * 100, 2)
        ELSE NULL
    END AS yoy_growth_pct,
    tp.product_name AS top_product
FROM MonthlyWithComparisons AS mc
LEFT JOIN TopProducts AS tp
    ON tp.month_start = DATEFROMPARTS(mc.sale_year, mc.sale_month, 1)
    AND tp.rn = 1
ORDER BY
    mc.sale_year DESC,
    mc.sale_month DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## Next Steps

1. **Deploy Indexes** — Execute the recommended `CREATE INDEX` statements in a non-production environment first. Verify with `sys.dm_db_index_physical_stats` that the indexes are built without excessive fragmentation.
2. **Test Optimized Query** — Run the optimized query and compare `SET STATISTICS IO/TIME` output against the original. Expect a dramatic reduction in logical reads (from ~6×N table scans down to 2 scans of `SalesHistory`).
3. **Review Execution Plan** — Use `SET SHOWPLAN_XML ON` or SSMS "Include Actual Execution Plan" to verify that correlated subquery nested-loop scans are eliminated and replaced with hash/merge aggregations and window spool operators.
4. **Monitor in Production** — After deploying, monitor with `sys.dm_exec_query_stats` and `sys.dm_db_index_usage_stats` to confirm the new indexes are being used and that overall query duration has improved.
