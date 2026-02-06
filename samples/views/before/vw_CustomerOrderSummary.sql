-- =============================================
-- View:    vw_CustomerOrderSummary
-- Status:  BEFORE optimization (intentionally suboptimal)
--
-- ANTI-PATTERNS PRESENT:
--   1. SELECT * usage
--   2. Nested views (view calls another view)
--   3. Unnecessary DISTINCT
--   4. Scalar subqueries in SELECT list
--   5. Non-SARGable computed columns  
--   6. No schema binding (can't be indexed)
--   7. Excessive columns (kitchen-sink view)
-- =============================================

USE ECommerceDemo;
GO

-- Anti-pattern: Helper view used as building block — creates nested view dependency
CREATE OR ALTER VIEW vw_OrderDetails
AS
    -- Anti-pattern: SELECT * pulls all columns from both tables
    SELECT *
    FROM Orders o
    INNER JOIN OrderItems oi ON o.id = oi.order_id;
GO

CREATE OR ALTER VIEW vw_CustomerOrderSummary
AS
    -- Anti-pattern: DISTINCT to mask duplicates from improper join
    SELECT DISTINCT
        c.id AS customer_id,
        -- Anti-pattern: Concatenation prevents indexing on name
        c.first_name + ' ' + c.last_name AS full_name,
        c.email,
        c.phone,
        c.address,
        c.city,
        c.state,
        c.zip_code,
        c.country,
        c.created_at AS customer_since,

        -- Anti-pattern: Scalar subquery (executes per row)
        (SELECT COUNT(*) 
         FROM Orders 
         WHERE customer_id = c.id) AS total_orders,

        -- Anti-pattern: Another scalar subquery per row
        (SELECT ISNULL(SUM(total_amount), 0) 
         FROM Orders 
         WHERE customer_id = c.id) AS lifetime_value,

        -- Anti-pattern: Yet another scalar subquery per row
        (SELECT TOP 1 order_date 
         FROM Orders 
         WHERE customer_id = c.id 
         ORDER BY order_date DESC) AS last_order_date,

        -- Anti-pattern: Another scalar subquery per row
        (SELECT COUNT(DISTINCT oi.product_id)
         FROM OrderItems oi
         INNER JOIN Orders o ON oi.order_id = o.id
         WHERE o.customer_id = c.id) AS unique_products_purchased,

        -- Anti-pattern: Scalar subquery with aggregation per row
        (SELECT ISNULL(AVG(total_amount), 0)
         FROM Orders
         WHERE customer_id = c.id) AS avg_order_value,

        -- Anti-pattern: Non-SARGable computed column using DATEDIFF
        DATEDIFF(DAY,
            (SELECT TOP 1 order_date FROM Orders WHERE customer_id = c.id ORDER BY order_date DESC),
            GETUTCDATE()
        ) AS days_since_last_order,

        -- Anti-pattern: CASE with subquery
        CASE 
            WHEN (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id) > 20 THEN 'Platinum'
            WHEN (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id) > 10 THEN 'Gold'
            WHEN (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id) > 5 THEN 'Silver'
            ELSE 'Bronze'
        END AS loyalty_tier

    FROM Customers c
    -- Anti-pattern: LEFT JOIN to nested view (vw_OrderDetails) that already does a JOIN
    LEFT JOIN vw_OrderDetails od ON c.id = od.customer_id;
GO
