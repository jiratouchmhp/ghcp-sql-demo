-- =============================================
-- Slow Query 02: Customer Segmentation Aggregation
-- Status:  Intentionally suboptimal for demo
--
-- ANTI-PATTERNS PRESENT:
--   1. Multiple table scans via correlated subqueries
--   2. Repeated aggregation of same data
--   3. Non-SARGable date calculations (DATEDIFF on column)
--   4. HAVING with subquery
--   5. Unnecessary sorting of intermediate results
--   6. Lack of window functions where appropriate
-- =============================================

USE ECommerceDemo;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- ============================================
-- Query: Customer RFM (Recency, Frequency, Monetary) segmentation
-- Expected behavior: Multiple full scans of Orders and OrderItems
-- ============================================

SELECT
    c.id AS customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.email,
    c.state,

    -- Anti-pattern: Correlated subquery for recency
    (SELECT DATEDIFF(DAY, MAX(o.order_date), GETUTCDATE())
     FROM Orders o
     WHERE o.customer_id = c.id) AS days_since_last_order,

    -- Anti-pattern: Correlated subquery for frequency
    (SELECT COUNT(*)
     FROM Orders o
     WHERE o.customer_id = c.id
       AND o.status = 'Completed') AS total_orders,

    -- Anti-pattern: Correlated subquery for monetary
    (SELECT ISNULL(SUM(o.total_amount), 0)
     FROM Orders o
     WHERE o.customer_id = c.id
       AND o.status = 'Completed') AS lifetime_value,

    -- Anti-pattern: Correlated subquery for average order value
    (SELECT ISNULL(AVG(o.total_amount), 0)
     FROM Orders o
     WHERE o.customer_id = c.id
       AND o.status = 'Completed') AS avg_order_value,

    -- Anti-pattern: Correlated subquery for distinct products
    (SELECT COUNT(DISTINCT oi.product_id)
     FROM OrderItems oi
     INNER JOIN Orders o ON oi.order_id = o.id
     WHERE o.customer_id = c.id) AS unique_products,

    -- Anti-pattern: Correlated subquery for favourite category
    (SELECT TOP 1 cat.name
     FROM OrderItems oi
     INNER JOIN Orders o ON oi.order_id = o.id
     INNER JOIN Products p ON oi.product_id = p.id
     INNER JOIN Categories cat ON p.category_id = cat.id
     WHERE o.customer_id = c.id
     GROUP BY cat.name
     ORDER BY SUM(oi.line_total) DESC) AS top_category,

    -- Anti-pattern: CASE with repeated correlated subqueries
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

    -- Anti-pattern: Correlated subquery for first order date
    (SELECT MIN(order_date) FROM Orders WHERE customer_id = c.id) AS first_order_date,
    
    -- Anti-pattern: Correlated subquery for last order date
    (SELECT MAX(order_date) FROM Orders WHERE customer_id = c.id) AS last_order_date

FROM Customers c
-- Anti-pattern: HAVING-like filter on outer query requires all subqueries to execute
WHERE (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id) > 0
ORDER BY
    -- Anti-pattern: ORDER BY on computed column from subquery
    (SELECT ISNULL(SUM(o.total_amount), 0)
     FROM Orders o
     WHERE o.customer_id = c.id
       AND o.status = 'Completed') DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
