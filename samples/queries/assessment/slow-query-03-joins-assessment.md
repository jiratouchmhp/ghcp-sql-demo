# Assessment Report: Multi-Table Join Performance Issues

> **Source File:** `samples/queries/before/slow-query-03-joins.sql`
> **Assessed On:** 2026-02-09
> **Database:** ECommerceDemo (SQL Server 2019/2022)

---

## Summary

| Metric               | Value                              |
|----------------------|------------------------------------|
| Total Issues Found   | 19                                 |
| Critical             | 7                                  |
| High                 | 5                                  |
| Medium               | 4                                  |
| Low                  | 3                                  |
| Overall Risk Rating  | Critical                           |

---

## Performance Issues Found

### Query 1: Product Performance with All Related Data

### Issue 1: ISNULL Wrapping Makes `is_active` Predicate Non-SARGable
- **Severity**: Critical
- **Category**: SARGability
- **Problem**: `ISNULL(p.is_active, 0) = 1` wraps the `is_active` column in a function, preventing SQL Server from performing an index seek on this column. The optimizer cannot push the predicate into an index range scan.
- **Impact**: Forces a full table or clustered index scan on `Products` instead of a filtered index seek. Every row in `Products` must be evaluated, even if a nonclustered index on `is_active` exists.
- **Line(s)**: 66

### Issue 2: YEAR() Function on `order_date` Prevents Index Usage
- **Severity**: Critical
- **Category**: SARGability
- **Problem**: `YEAR(o.order_date) >= YEAR(GETUTCDATE()) - 1` applies the `YEAR()` function to the `order_date` column. This prevents SQL Server from using any index on `order_date` because the function must be evaluated for every row before filtering.
- **Impact**: Full scan of `Orders` table instead of a range seek. For a large orders table (millions of rows), this dramatically increases logical reads and query duration. Should be rewritten as a date range predicate: `o.order_date >= DATEADD(YEAR, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, GETUTCDATE()), 0))`.
- **Line(s)**: 70

### Issue 3: Massive Row Expansion from Non-Grouped JOIN to OrderItems
- **Severity**: Critical
- **Category**: Joins
- **Problem**: `Products` is LEFT JOINed to `OrderItems`, `Orders`, and `Customers` without any aggregation. Since one product can appear in thousands of order items, this creates a massive row expansion — each product row is duplicated once per matching order item. The query then selects detail-level columns (`oi.quantity`, `oi.unit_price`, `oi.line_total`, `o.id`, `cust.first_name`, etc.) producing a Cartesian-like explosion of rows.
- **Impact**: A product with 5,000 order line items generates 5,000 rows in the result. With 10,000 products, the result set can exceed 50 million rows. This causes enormous memory grants, TempDB spills, excessive I/O, and likely query timeouts.
- **Line(s)**: 60–62

### Issue 4: LEFT JOINs Where Logic Requires INNER JOINs
- **Severity**: High
- **Category**: Joins
- **Problem**: The query uses LEFT JOINs to `Orders` and `Customers`, but the WHERE clause filters on `o.status` (with a non-NULL branch) and `YEAR(o.order_date)`, effectively converting these LEFT JOINs into INNER JOINs. The mismatch between LEFT JOIN semantics and WHERE filters confuses the optimizer and masks the query's true intent.
- **Impact**: The optimizer may produce suboptimal join order and cardinality estimates because the LEFT JOIN hints at optional relationships while the WHERE clause demands matched rows. This leads to poor plan choices (e.g., hash joins instead of nested loops where appropriate).
- **Line(s)**: 60–62, 68, 70

### Issue 5: OR Condition on `status` Prevents Single Index Seek
- **Severity**: Medium
- **Category**: SARGability
- **Problem**: `o.status = 'Completed' OR o.status = 'Shipped' OR o.status IS NULL` uses OR logic across three conditions. SQL Server may not be able to use a single index seek on `status`; instead it may perform an index scan or multiple seeks merged via concatenation.
- **Impact**: Replacing with `o.status IN ('Completed', 'Shipped')` (and handling the NULL case via the LEFT JOIN or a separate `IS NULL` check) allows the optimizer to generate a more efficient seek plan. For the NULL case in a LEFT JOIN, this is handled inherently when no matching order exists.
- **Line(s)**: 68

### Issue 6: Excessive Columns in SELECT (22 Columns)
- **Severity**: Medium
- **Category**: SELECT Clause
- **Problem**: The query selects 22 columns including wide text columns like `p.description`, `c.description`, `cust.email`, and `cust.address`/`city`/`state`. Many of these columns are unlikely to be needed by the consumer and prevent the use of narrower covering indexes.
- **Impact**: Wider rows increase memory grant requirements, cause TempDB spills during sorting, increase network transfer time, and prevent the optimizer from using covering nonclustered indexes. Selecting only required columns would reduce I/O and memory significantly.
- **Line(s)**: 31–55

### Issue 7: ORDER BY on Computed Expression
- **Severity**: Low
- **Category**: Aggregation
- **Problem**: `ORDER BY p.price * oi.quantity DESC` sorts by a computed expression that cannot be satisfied by any index. SQL Server must compute this value for every result row and then perform a full sort.
- **Impact**: Requires a Sort operator in the execution plan, which for a large result set (see Issue 3) will spill to TempDB. Minor impact in isolation, but combined with the row explosion it becomes significant.
- **Line(s)**: 73

---

### Query 2: Cross-Region Product Comparison

### Issue 8: Implicit Comma Joins (Old-Style Join Syntax)
- **Severity**: Critical
- **Category**: Joins
- **Problem**: The query uses comma-separated FROM clause (`FROM Products p, (...) r1, (...) r2`) instead of explicit `INNER JOIN ... ON` syntax. This old-style syntax is error-prone, harder to read, and makes it easy to accidentally omit join conditions, creating Cartesian products.
- **Impact**: While the WHERE clause does provide join predicates (`p.id = r1.product_id AND p.id = r2.product_id`), the implicit syntax prevents the optimizer from clearly distinguishing join predicates from filter predicates. Should be converted to explicit `INNER JOIN` for clarity, maintainability, and reliable plan generation.
- **Line(s)**: 86–99

### Issue 9: YEAR() Function on `sale_date` Prevents Index Seek (Duplicated)
- **Severity**: Critical
- **Category**: SARGability
- **Problem**: Both derived tables use `WHERE YEAR(sale_date) = YEAR(GETUTCDATE())`, applying the `YEAR()` function to the `sale_date` column. This prevents index seeks on `sale_date` in `SalesHistory`, forcing full table scans — and this scan happens twice because the derived table is duplicated.
- **Impact**: Two full scans of `SalesHistory` (potentially millions of rows each). Should be rewritten as a SARGable date range: `WHERE sale_date >= DATEFROMPARTS(YEAR(GETUTCDATE()), 1, 1) AND sale_date < DATEADD(YEAR, 1, DATEFROMPARTS(YEAR(GETUTCDATE()), 1, 1))`.
- **Line(s)**: 92, 97

### Issue 10: Duplicate Derived Tables Scan the Same Data Twice
- **Severity**: High
- **Category**: Subqueries
- **Problem**: The two derived tables `r1` and `r2` contain identical logic — both aggregate `SalesHistory` by `product_id` and `region` for the current year. SQL Server will execute this subquery twice, doubling the I/O and CPU cost.
- **Impact**: Double the logical reads on `SalesHistory`. Should be refactored to a single CTE (`WITH RegionRevenue AS (...)`) and self-joined, or use a CROSS JOIN on the CTE for region-pair comparison.
- **Line(s)**: 89–98

### Issue 11: N×N Region Pairs Per Product
- **Severity**: Medium
- **Category**: Joins
- **Problem**: The condition `r1.region < r2.region` produces all unique pairs of regions for each product. If there are R regions per product, this generates $\binom{R}{2} = \frac{R(R-1)}{2}$ rows per product. For 10 regions, this is 45 rows per product; for 50 regions, 1,225 rows per product.
- **Impact**: Result set growth is quadratic in the number of regions. Consider whether this cross-comparison is truly needed, or if a PIVOT or conditional aggregation approach would be more appropriate.
- **Line(s)**: 101

### Issue 12: ORDER BY on ABS() Computed Expression
- **Severity**: Low
- **Category**: Aggregation
- **Problem**: `ORDER BY ABS(r1.total_revenue - r2.total_revenue) DESC` requires computing the absolute difference for every row and then sorting. No index can satisfy this sort.
- **Impact**: Forces a Sort operator with potential TempDB spill for large result sets. Minor standalone impact.
- **Line(s)**: 104

---

### Query 3: Order Fulfillment Pipeline

### Issue 13: CONVERT on `order_date` Prevents Index Seek
- **Severity**: Critical
- **Category**: SARGability
- **Problem**: `CONVERT(VARCHAR(10), o.order_date, 120) >= '2024-01-01'` converts the `order_date` column to a string before comparing. This prevents any index on `order_date` from being used for a seek, forcing a full scan of `Orders`.
- **Impact**: Full table scan on `Orders` instead of a range seek. Should be rewritten as `o.order_date >= '2024-01-01'` (direct date comparison is SARGable).
- **Line(s)**: 140

### Issue 14: SalesHistory JOIN Creates Row Duplication and Incorrect Aggregations
- **Severity**: Critical
- **Category**: Joins
- **Problem**: The LEFT JOIN to `SalesHistory` (`sh`) on `o.id = sh.order_id AND oi.product_id = sh.product_id`) can produce multiple matching rows if `SalesHistory` contains multiple entries per order-product combination. This multiplies the rows before the GROUP BY, causing `COUNT(oi.id)` and `SUM(oi.quantity)` to return inflated values. Additionally, `sh.region` and `sh.profit` are included in the GROUP BY, further splitting order-level aggregations across SalesHistory partitions.
- **Impact**: Incorrect query results (double/triple-counted line items and quantities). The query also returns multiple rows per order when SalesHistory has multiple regions. Data integrity is compromised — this is both a performance and correctness bug.
- **Line(s)**: 136–137, 149–151

### Issue 15: Unnecessary Joins to Categories and Inventory
- **Severity**: High
- **Category**: Joins
- **Problem**: `Categories cat` (line 134) and `Inventory inv` (line 135) are joined but no columns from these tables appear in the SELECT list, WHERE clause, or GROUP BY. These joins add cost without contributing to the result.
- **Impact**: The INNER JOIN to `Categories` eliminates products without a category (potentially filtering valid data) and adds join overhead. The LEFT JOIN to `Inventory` adds hash/merge join cost and increases memory grants. Removing both joins reduces logical reads and simplifies the execution plan.
- **Line(s)**: 134–135

### Issue 16: Correlated Subquery for STRING_AGG (N+1 Pattern)
- **Severity**: High
- **Category**: Subqueries
- **Problem**: The `product_list` column uses a correlated subquery with `STRING_AGG` that re-joins `OrderItems` and `Products` for each output row. Since `OrderItems` is already joined in the main query, this duplicates work. The correlated subquery executes once per group (per order), creating the N+1 query pattern.
- **Impact**: For N orders in the result, this executes N additional subqueries, each scanning `OrderItems` and joining `Products`. Should be refactored to a CTE or CROSS APPLY with the main join to `OrderItems`.
- **Line(s)**: 122–125

### Issue 17: IN Subquery Instead of JOIN or EXISTS
- **Severity**: Medium
- **Category**: Subqueries
- **Problem**: `o.customer_id IN (SELECT customer_id FROM Orders GROUP BY customer_id HAVING COUNT(*) > 3)` uses an IN subquery to filter for repeat customers. While modern SQL Server often optimizes this to a semi-join, an explicit `INNER JOIN` to a CTE or `EXISTS` with a correlated subquery provides clearer intent and more predictable plan generation.
- **Impact**: The IN subquery scans and aggregates the entire `Orders` table to find qualifying customer IDs. An `EXISTS` or CTE approach may allow the optimizer to apply the filter earlier in the plan.
- **Line(s)**: 142–146

### Issue 18: GROUP BY Includes SalesHistory Non-Aggregated Columns
- **Severity**: High
- **Category**: Aggregation
- **Problem**: `sh.region` and `sh.profit` from the LEFT JOIN to `SalesHistory` are included in the GROUP BY clause because they appear in the SELECT list without aggregation. This splits each order into multiple groups (one per region and profit value from SalesHistory), producing duplicate order rows with fragmented aggregations.
- **Impact**: Incorrect result cardinality — a single order appears multiple times with partial `line_item_count` and `total_units`. This is a correctness defect. The SalesHistory join should be removed entirely, or its columns should be aggregated separately in a subquery/CTE.
- **Line(s)**: 128–129, 149–151

### Issue 19: String Concatenation for Customer Name
- **Severity**: Low
- **Category**: SELECT Clause
- **Problem**: `cust.first_name + ' ' + cust.last_name AS customer_name` uses string concatenation. If either `first_name` or `last_name` is NULL, the entire expression returns NULL due to SQL Server's NULL concatenation behavior.
- **Impact**: Minor — potential NULL results for customer names. Should use `CONCAT(cust.first_name, ' ', cust.last_name)` which handles NULLs gracefully by treating them as empty strings.
- **Line(s)**: 120

---

## Recommended Indexes

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| Products | `IX_Products_IsActive` | `is_active` | `name`, `price`, `cost`, `sku`, `category_id` | Enables seek on `is_active` once ISNULL is removed; covers key SELECT columns |
| Orders | `IX_Orders_OrderDate_Status` | `order_date`, `status` | `customer_id`, `total_amount` | Enables range seek on `order_date` (once SARGable) and filters on `status`; covers join and SELECT columns |
| Orders | `IX_Orders_CustomerId` | `customer_id` | `order_date`, `status`, `total_amount` | Supports the repeat-customer IN subquery and customer-to-order joins |
| OrderItems | `IX_OrderItems_OrderId` | `order_id` | `product_id`, `quantity`, `unit_price`, `line_total` | Supports join from Orders to OrderItems; covers SELECT columns |
| OrderItems | `IX_OrderItems_ProductId` | `product_id` | `order_id`, `quantity`, `unit_price`, `line_total` | Supports join from Products to OrderItems in Query 1 |
| SalesHistory | `IX_SalesHistory_SaleDate` | `sale_date` | `product_id`, `region`, `revenue` | Enables date range seeks once YEAR() is replaced with SARGable predicate; covers Query 2 aggregation |
| SalesHistory | `IX_SalesHistory_OrderId_ProductId` | `order_id`, `product_id` | `region`, `profit` | Supports the SalesHistory join in Query 3 (if retained) |
| Products | `IX_Products_Active_CategoryId` | `category_id` | `name`, `price`, `cost`, `sku` | Filtered index (`WHERE is_active = 1`) for active products; enables fast lookups |

---

## Performance Verification

```sql
-- Run these commands before and after applying the optimized query
-- to measure the improvement.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- ============================================
-- Query 1 (Original — baseline)
-- ============================================
SELECT
    p.id AS product_id,
    p.name AS product_name,
    p.description,
    p.price,
    p.cost,
    p.sku,
    c.name AS category_name,
    c.description AS category_description,
    pc.name AS parent_category_name,
    i.warehouse_location,
    i.quantity_on_hand,
    i.reorder_level,
    oi.quantity AS item_quantity,
    oi.unit_price AS item_unit_price,
    oi.line_total,
    o.id AS order_id,
    o.order_date,
    o.status AS order_status,
    cust.first_name,
    cust.last_name,
    cust.email,
    cust.city,
    cust.state
FROM Products p
    LEFT JOIN Categories c ON p.category_id = c.id
    LEFT JOIN Categories pc ON c.parent_category_id = pc.id
    LEFT JOIN Inventory i ON p.id = i.product_id
    LEFT JOIN OrderItems oi ON p.id = oi.product_id
    LEFT JOIN Orders o ON oi.order_id = o.id
    LEFT JOIN Customers cust ON o.customer_id = cust.id
WHERE
    ISNULL(p.is_active, 0) = 1
    AND (o.status = 'Completed' OR o.status = 'Shipped' OR o.status IS NULL)
    AND YEAR(o.order_date) >= YEAR(GETUTCDATE()) - 1
ORDER BY
    p.price * oi.quantity DESC;

-- ============================================
-- Query 2 (Original — baseline)
-- ============================================
SELECT
    p.name AS product_name,
    r1.region AS region_a,
    r2.region AS region_b,
    r1.total_revenue AS region_a_revenue,
    r2.total_revenue AS region_b_revenue,
    r1.total_revenue - r2.total_revenue AS revenue_difference
FROM Products p,
    (SELECT product_id, region, SUM(revenue) AS total_revenue
     FROM SalesHistory
     WHERE YEAR(sale_date) = YEAR(GETUTCDATE())
     GROUP BY product_id, region) r1,
    (SELECT product_id, region, SUM(revenue) AS total_revenue
     FROM SalesHistory
     WHERE YEAR(sale_date) = YEAR(GETUTCDATE())
     GROUP BY product_id, region) r2
WHERE p.id = r1.product_id
    AND p.id = r2.product_id
    AND r1.region < r2.region
ORDER BY
    ABS(r1.total_revenue - r2.total_revenue) DESC;

-- ============================================
-- Query 3 (Original — baseline)
-- ============================================
SELECT
    o.id AS order_id,
    o.order_date,
    o.status,
    o.total_amount,
    cust.first_name + ' ' + cust.last_name AS customer_name,
    (SELECT STRING_AGG(p2.name, ', ')
     FROM OrderItems oi2
     INNER JOIN Products p2 ON oi2.product_id = p2.id
     WHERE oi2.order_id = o.id) AS product_list,
    COUNT(oi.id) AS line_item_count,
    SUM(oi.quantity) AS total_units,
    sh.region,
    sh.profit
FROM Orders o
    INNER JOIN Customers cust ON o.customer_id = cust.id
    INNER JOIN OrderItems oi ON o.id = oi.order_id
    INNER JOIN Products p ON oi.product_id = p.id
    INNER JOIN Categories cat ON p.category_id = cat.id
    LEFT JOIN Inventory inv ON p.id = inv.product_id
    LEFT JOIN SalesHistory sh ON o.id = sh.order_id
        AND oi.product_id = sh.product_id
WHERE
    CONVERT(VARCHAR(10), o.order_date, 120) >= '2024-01-01'
    AND o.customer_id IN (
        SELECT customer_id
        FROM Orders
        GROUP BY customer_id
        HAVING COUNT(*) > 3
    )
GROUP BY
    o.id, o.order_date, o.status, o.total_amount,
    cust.first_name, cust.last_name,
    sh.region, sh.profit
HAVING
    SUM(oi.quantity) > 1
ORDER BY
    o.order_date DESC;

-- Optimized queries here for comparison (after running @sql-performance-tuner)

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
