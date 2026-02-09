# Assessment Report: Customer Segmentation Aggregation (RFM Analysis)

> **Source File:** `samples/queries/before/slow-query-02-aggregation.sql`
> **Assessed On:** 2026-02-09
> **Database:** ECommerceDemo (SQL Server 2019/2022)

---

## Summary

| Metric               | Value                              |
|----------------------|------------------------------------|
| Total Issues Found   | 8                                  |
| Critical             | 3                                  |
| High                 | 3                                  |
| Medium               | 1                                  |
| Low                  | 1                                  |
| Overall Risk Rating  | Critical                           |

---

## Performance Issues Found

### Issue 1: Excessive Correlated Subqueries (N+1 Pattern)
- **Severity**: Critical
- **Category**: Subqueries
- **Problem**: The query contains **12+ correlated subqueries** in the SELECT list and WHERE/ORDER BY clauses. Each subquery executes once per customer row, causing repeated full scans of the `Orders` and `OrderItems` tables. For N customers, this results in approximately 12×N separate queries against those tables.
- **Impact**: Exponential I/O growth. With 10,000 customers, the query executes ~120,000 subquery evaluations, each potentially performing a table or index scan on `Orders`. This is the single largest performance bottleneck.
- **Line(s)**: 28–31 (recency), 34–37 (frequency), 40–43 (monetary), 46–49 (avg order value), 52–55 (unique products), 58–64 (top category), 68–86 (segment CASE), 89 (first order), 92 (last order), 95 (WHERE filter), 98–101 (ORDER BY)

---

### Issue 2: Repeated Identical Subqueries in CASE Expression
- **Severity**: Critical
- **Category**: Subqueries
- **Problem**: The `customer_segment` CASE expression (lines 68–86) re-executes the same `DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())` subquery **5 times** and the `COUNT(*)` subquery **2 times** — values already computed in earlier SELECT columns. SQL Server may not collapse these into a single evaluation.
- **Impact**: Multiplies the already-expensive correlated subquery cost. The recency subquery alone runs 5 additional times per customer, and the frequency subquery runs 2 additional times — adding ~7×N redundant scans of `Orders`.
- **Line(s)**: 69–70, 73–74, 77–78, 80–81, 83–84 (recency duplicates); 71, 75 (frequency duplicates)

---

### Issue 3: Non-SARGable Date Predicate — `DATEDIFF()` on Column
- **Severity**: Critical
- **Category**: SARGability
- **Problem**: `DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())` applies a function to the result of `MAX(order_date)`. While `MAX()` itself can use an index, the subsequent `DATEDIFF` wrapping prevents the optimizer from pushing date-range predicates down. The CASE thresholds (30, 60, 90, 180 days) could instead be expressed as direct date comparisons (`MAX(o.order_date) >= DATEADD(DAY, -30, GETUTCDATE())`), which are SARGable.
- **Impact**: Prevents potential seek-based optimizations on `order_date` and forces row-by-row evaluation of the date arithmetic for each customer.
- **Line(s)**: 29, 69, 73, 77, 80, 83

---

### Issue 4: Correlated Subquery in WHERE Clause
- **Severity**: High
- **Category**: Subqueries
- **Problem**: The filter `WHERE (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id) > 0` executes a full aggregation subquery per customer to check existence. This should be replaced with `EXISTS (SELECT 1 FROM Orders WHERE customer_id = c.id)`, which short-circuits on the first matching row.
- **Impact**: `COUNT(*)` must scan/count all matching rows, while `EXISTS` stops at the first match. For customers with hundreds of orders, this is significantly more expensive than necessary.
- **Line(s)**: 95

---

### Issue 5: Correlated Subquery in ORDER BY Clause
- **Severity**: High
- **Category**: Subqueries / Aggregation
- **Problem**: The `ORDER BY` clause contains a correlated subquery that recalculates `SUM(o.total_amount)` — the same value already computed as `lifetime_value` in the SELECT list. This forces yet another scan of `Orders` per customer for sorting.
- **Impact**: Adds an additional full scan of `Orders` per customer row, duplicating work already done in line 40–43.
- **Line(s)**: 98–101

---

### Issue 6: Expensive Correlated Subquery for Top Category
- **Severity**: High
- **Category**: Subqueries
- **Problem**: The `top_category` subquery (lines 58–64) performs a 4-table join (`OrderItems` → `Orders` → `Products` → `Categories`), groups by `cat.name`, aggregates `SUM(oi.line_total)`, and sorts — all executed once per customer. This is the most expensive individual subquery.
- **Impact**: For each customer, the optimizer must join 4 tables, aggregate, and sort. With N customers, this means N separate multi-table join + aggregation + sort operations.
- **Line(s)**: 58–64

---

### Issue 7: Missing Window Function Opportunity
- **Severity**: Medium
- **Category**: Aggregation
- **Problem**: All the per-customer aggregations (recency, frequency, monetary, avg order value, first/last order date) can be computed in a single pass using `JOIN` with `GROUP BY` or window functions like `ROW_NUMBER()`, `SUM() OVER()`, etc. The current approach uses individual correlated subqueries, missing the opportunity for set-based computation.
- **Impact**: A single scan of `Orders` with `GROUP BY customer_id` would replace at least 8 separate correlated subqueries, reducing I/O by an estimated 80–90%.
- **Line(s)**: 28–92

---

### Issue 8: `ISNULL()` Usage in Aggregation Subqueries
- **Severity**: Low
- **Category**: SARGability
- **Problem**: `ISNULL(SUM(...), 0)` and `ISNULL(AVG(...), 0)` are used in SELECT-list subqueries (lines 41, 47). While not directly preventing index usage here (since they wrap the aggregate result, not a column in a WHERE clause), they add minor overhead. In the optimized version using JOINs, `COALESCE` is preferred for ANSI compliance.
- **Impact**: Minimal direct performance impact, but indicates a pattern that could become problematic if moved into a WHERE clause.
- **Line(s)**: 41, 47

---

## Recommended Indexes

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| Orders | `IX_Orders_CustomerId_Status` | `customer_id`, `status` | `order_date`, `total_amount` | Covers frequency, monetary, and recency lookups; eliminates key lookups for the most common subqueries |
| Orders | `IX_Orders_CustomerId_OrderDate` | `customer_id`, `order_date` | `status`, `total_amount` | Supports MIN/MAX on `order_date` per customer; enables range-based segment evaluation |
| OrderItems | `IX_OrderItems_OrderId_ProductId` | `order_id`, `product_id` | `line_total` | Covers unique product count and top category subqueries; avoids key lookups on `line_total` |
| Products | `IX_Products_Id_CategoryId` | `id` | `category_id` | Covers the join from `OrderItems` to `Categories` via `Products` |
| Customers | `PK_Customers` (clustered on `id`) | `id` | — | Should already exist; ensures efficient customer iteration |

---

## Performance Verification

```sql
-- Run these commands before and after applying the optimized query
-- to measure the improvement.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Original query (baseline) — from slow-query-02-aggregation.sql
SELECT
    c.id AS customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.email,
    c.state,
    (SELECT DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())
     FROM Orders o WHERE o.customer_id = c.id) AS days_since_last_order,
    (SELECT COUNT(*) FROM Orders o
     WHERE o.customer_id = c.id AND o.status = 'Completed') AS total_orders,
    (SELECT ISNULL(SUM(o.total_amount), 0) FROM Orders o
     WHERE o.customer_id = c.id AND o.status = 'Completed') AS lifetime_value,
    (SELECT ISNULL(AVG(o.total_amount), 0) FROM Orders o
     WHERE o.customer_id = c.id AND o.status = 'Completed') AS avg_order_value,
    (SELECT COUNT(DISTINCT oi.product_id) FROM OrderItems oi
     INNER JOIN Orders o ON oi.order_id = o.id
     WHERE o.customer_id = c.id) AS unique_products,
    (SELECT TOP 1 cat.name FROM OrderItems oi
     INNER JOIN Orders o ON oi.order_id = o.id
     INNER JOIN Products p ON oi.product_id = p.id
     INNER JOIN Categories cat ON p.category_id = cat.id
     WHERE o.customer_id = c.id
     GROUP BY cat.name
     ORDER BY SUM(oi.line_total) DESC) AS top_category,
    CASE
        WHEN (SELECT DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())
              FROM Orders o WHERE o.customer_id = c.id) <= 30
             AND (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id AND status = 'Completed') >= 10
        THEN 'Champion'
        WHEN (SELECT DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())
              FROM Orders o WHERE o.customer_id = c.id) <= 60
             AND (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id AND status = 'Completed') >= 5
        THEN 'Loyal'
        WHEN (SELECT DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())
              FROM Orders o WHERE o.customer_id = c.id) <= 90
        THEN 'Potential'
        WHEN (SELECT DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())
              FROM Orders o WHERE o.customer_id = c.id) <= 180
        THEN 'At Risk'
        WHEN (SELECT DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())
              FROM Orders o WHERE o.customer_id = c.id) > 180
        THEN 'Lost'
        ELSE 'New'
    END AS customer_segment,
    (SELECT MIN(order_date) FROM Orders WHERE customer_id = c.id) AS first_order_date,
    (SELECT MAX(order_date) FROM Orders WHERE customer_id = c.id) AS last_order_date
FROM Customers c
WHERE (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id) > 0
ORDER BY
    (SELECT ISNULL(SUM(o.total_amount), 0) FROM Orders o
     WHERE o.customer_id = c.id AND o.status = 'Completed') DESC;

-- Optimized query for comparison (to be generated by @sql-performance-tuner)

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
