-- =============================================
-- Slow Query 03: Multi-Table Join Performance Issues
-- Status:  Intentionally suboptimal for demo
--
-- ANTI-PATTERNS PRESENT:
--   1. Unnecessary joins (tables joined but not used)
--   2. Implicit cross joins via comma syntax
--   3. OR conditions preventing index seeks
--   4. Functions on join columns
--   5. Non-SARGable WHERE predicates
--   6. Missing join conditions (partial Cartesian product)
--   7. Excessive columns selected
--   8. LEFT JOIN where INNER JOIN is appropriate
-- =============================================

USE ECommerceDemo;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- ============================================
-- Query 1: Product performance with all related data
-- Expected behavior: Nested loop joins with table scans
-- ============================================

-- Anti-pattern: Selecting far too many columns
-- Anti-pattern: LEFT JOINs where INNER JOINs are more appropriate
-- Anti-pattern: Joining tables whose columns are never used
SELECT
    p.id AS product_id,
    p.name AS product_name,
    p.description,
    p.price,
    p.cost,
    p.sku,
    c.name AS category_name,
    c.description AS category_description,
    -- Anti-pattern: Selecting parent category via self-join instead of CTE or subquery
    pc.name AS parent_category_name,
    i.warehouse_location,
    i.quantity_on_hand,
    i.reorder_level,
    -- Anti-pattern: Aggregating from a non-grouped join (will cause duplicates)
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
    -- Anti-pattern: This creates massive row expansion
    LEFT JOIN OrderItems oi ON p.id = oi.product_id
    LEFT JOIN Orders o ON oi.order_id = o.id
    LEFT JOIN Customers cust ON o.customer_id = cust.id
WHERE
    -- Anti-pattern: ISNULL makes predicate non-SARGable
    ISNULL(p.is_active, 0) = 1
    -- Anti-pattern: OR condition prevents single index seek
    AND (o.status = 'Completed' OR o.status = 'Shipped' OR o.status IS NULL)
    -- Anti-pattern: Function on column prevents index usage
    AND YEAR(o.order_date) >= YEAR(GETUTCDATE()) - 1
ORDER BY
    -- Anti-pattern: Sorting by computed expression
    p.price * oi.quantity DESC;

-- ============================================
-- Query 2: Cross-region product comparison
-- Expected behavior: Cartesian product from comma-separated joins
-- ============================================

-- Anti-pattern: Implicit join syntax (comma-separated FROM)
-- Anti-pattern: Missing join condition creates Cartesian product
SELECT
    p.name AS product_name,
    r1.region AS region_a,
    r2.region AS region_b,
    r1.total_revenue AS region_a_revenue,
    r2.total_revenue AS region_b_revenue,
    r1.total_revenue - r2.total_revenue AS revenue_difference
FROM Products p,
    -- Anti-pattern: Derived table with functions on columns
    (SELECT product_id, region, SUM(revenue) AS total_revenue
     FROM SalesHistory
     WHERE YEAR(sale_date) = YEAR(GETUTCDATE())
     GROUP BY product_id, region) r1,
    -- Anti-pattern: Same derived table scanned again
    (SELECT product_id, region, SUM(revenue) AS total_revenue
     FROM SalesHistory
     WHERE YEAR(sale_date) = YEAR(GETUTCDATE())
     GROUP BY product_id, region) r2
WHERE p.id = r1.product_id
    AND p.id = r2.product_id
    -- Anti-pattern: This still creates N×N per product (all region pairs)
    AND r1.region < r2.region
ORDER BY
    ABS(r1.total_revenue - r2.total_revenue) DESC;

-- ============================================
-- Query 3: Order fulfillment pipeline
-- Expected behavior: Multiple unnecessary joins and filters
-- ============================================

-- Anti-pattern: Joining to SalesHistory (denormalized table) PLUS original tables
-- This double-counts and duplicates data
SELECT
    o.id AS order_id,
    o.order_date,
    o.status,
    o.total_amount,
    cust.first_name + ' ' + cust.last_name AS customer_name,
    -- Anti-pattern: String aggregation via subquery
    (SELECT STRING_AGG(p2.name, ', ')
     FROM OrderItems oi2
     INNER JOIN Products p2 ON oi2.product_id = p2.id
     WHERE oi2.order_id = o.id) AS product_list,
    COUNT(oi.id) AS line_item_count,
    SUM(oi.quantity) AS total_units,
    -- Anti-pattern: Unnecessary join to SalesHistory creates duplicates
    sh.region,
    sh.profit
FROM Orders o
    INNER JOIN Customers cust ON o.customer_id = cust.id
    INNER JOIN OrderItems oi ON o.id = oi.order_id
    INNER JOIN Products p ON oi.product_id = p.id
    INNER JOIN Categories cat ON p.category_id = cat.id  -- Anti-pattern: Joined but never used
    LEFT JOIN Inventory inv ON p.id = inv.product_id     -- Anti-pattern: Joined but never used
    LEFT JOIN SalesHistory sh ON o.id = sh.order_id      -- Anti-pattern: Creates duplicates
        AND oi.product_id = sh.product_id
WHERE
    -- Anti-pattern: CONVERT on column prevents index seek
    CONVERT(VARCHAR(10), o.order_date, 120) >= '2024-01-01'
    -- Anti-pattern: IN with subquery instead of JOIN
    AND o.customer_id IN (
        SELECT customer_id 
        FROM Orders 
        GROUP BY customer_id 
        HAVING COUNT(*) > 3
    )
GROUP BY
    o.id, o.order_date, o.status, o.total_amount,
    cust.first_name, cust.last_name,
    sh.region, sh.profit  -- Anti-pattern: GROUP BY includes non-aggregated SalesHistory columns
HAVING
    SUM(oi.quantity) > 1
ORDER BY
    o.order_date DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
