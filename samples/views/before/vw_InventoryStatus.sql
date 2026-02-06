-- =============================================
-- View:    vw_InventoryStatus
-- Status:  BEFORE optimization (intentionally suboptimal)
--
-- ANTI-PATTERNS PRESENT:
--   1. Multiple scalar subqueries
--   2. Non-SARGable predicates in subqueries
--   3. Unnecessary DISTINCT
--   4. Mixing detail and aggregate data
--   5. Redundant joins 
--   6. No schema binding
--   7. Complex CASE with repeated subqueries
-- =============================================

USE ECommerceDemo;
GO

CREATE OR ALTER VIEW vw_InventoryStatus
AS
    SELECT DISTINCT
        i.id AS inventory_id,
        p.id AS product_id,
        p.name AS product_name,
        p.sku,
        p.price,
        p.cost,
        -- Anti-pattern: Subquery for category name (should be a JOIN)
        (SELECT name FROM Categories WHERE id = p.category_id) AS category_name,
        i.warehouse_location,
        i.quantity_on_hand,
        i.reorder_level,
        i.last_restocked_at,

        -- Anti-pattern: Scalar subquery for total sold (executes per row)
        (SELECT ISNULL(SUM(oi.quantity), 0)
         FROM OrderItems oi
         INNER JOIN Orders o ON oi.order_id = o.id
         WHERE oi.product_id = p.id
            AND o.status = 'Completed') AS total_units_sold,

        -- Anti-pattern: Scalar subquery for last 30 days sales
        (SELECT ISNULL(SUM(oi.quantity), 0)
         FROM OrderItems oi
         INNER JOIN Orders o ON oi.order_id = o.id
         WHERE oi.product_id = p.id
            AND o.status = 'Completed'
            -- Anti-pattern: DATEDIFF on column
            AND DATEDIFF(DAY, o.order_date, GETUTCDATE()) <= 30) AS units_sold_last_30_days,

        -- Anti-pattern: Scalar subquery for last 90 days sales (near-duplicate of above)
        (SELECT ISNULL(SUM(oi.quantity), 0)
         FROM OrderItems oi
         INNER JOIN Orders o ON oi.order_id = o.id
         WHERE oi.product_id = p.id
            AND o.status = 'Completed'
            AND DATEDIFF(DAY, o.order_date, GETUTCDATE()) <= 90) AS units_sold_last_90_days,

        -- Anti-pattern: Scalar subquery for pending orders
        (SELECT ISNULL(SUM(oi.quantity), 0)
         FROM OrderItems oi
         INNER JOIN Orders o ON oi.order_id = o.id
         WHERE oi.product_id = p.id
            AND o.status IN ('Pending', 'Processing')) AS units_in_pending_orders,

        -- Anti-pattern: Repeated calculation with subqueries in CASE
        CASE
            WHEN i.quantity_on_hand <= 0 THEN 'Out of Stock'
            WHEN i.quantity_on_hand <= i.reorder_level THEN 'Low Stock'
            WHEN i.quantity_on_hand <= i.reorder_level * 2 THEN 'Medium Stock'
            ELSE 'In Stock'
        END AS stock_status,

        -- Anti-pattern: Complex calculation relying on multiple scalar subqueries
        CASE
            WHEN (SELECT ISNULL(SUM(oi.quantity), 0)
                  FROM OrderItems oi
                  INNER JOIN Orders o ON oi.order_id = o.id
                  WHERE oi.product_id = p.id
                     AND o.status = 'Completed'
                     AND DATEDIFF(DAY, o.order_date, GETUTCDATE()) <= 30) > 0
            THEN CAST(i.quantity_on_hand AS DECIMAL(10,2)) / 
                 (SELECT ISNULL(SUM(oi.quantity), 0)
                  FROM OrderItems oi
                  INNER JOIN Orders o ON oi.order_id = o.id
                  WHERE oi.product_id = p.id
                     AND o.status = 'Completed'
                     AND DATEDIFF(DAY, o.order_date, GETUTCDATE()) <= 30) * 30
            ELSE 999  -- Anti-pattern: Magic number
        END AS estimated_days_of_stock,

        -- Anti-pattern: Scalar subquery for revenue
        (SELECT ISNULL(SUM(sh.revenue), 0)
         FROM SalesHistory sh
         WHERE sh.product_id = p.id) AS total_revenue,

        -- Anti-pattern: Subquery to check if item should be reordered
        CASE
            WHEN i.quantity_on_hand <= i.reorder_level
                AND (SELECT ISNULL(SUM(oi.quantity), 0)
                     FROM OrderItems oi
                     INNER JOIN Orders o ON oi.order_id = o.id
                     WHERE oi.product_id = p.id
                        AND o.status IN ('Pending', 'Processing')) > 0
            THEN 'URGENT REORDER'
            WHEN i.quantity_on_hand <= i.reorder_level
            THEN 'REORDER'
            ELSE 'OK'
        END AS reorder_status,

        p.is_active

    FROM Inventory i
    -- Anti-pattern: Multiple joins when data could be fetched more efficiently
    INNER JOIN Products p ON i.product_id = p.id
    LEFT JOIN Categories c ON p.category_id = c.id     -- Anti-pattern: Joined but c.name used via subquery above
    LEFT JOIN OrderItems oi ON p.id = oi.product_id    -- Anti-pattern: Causes row multiplication
    LEFT JOIN Orders o ON oi.order_id = o.id           -- Anti-pattern: Causes further row multiplication
GO
