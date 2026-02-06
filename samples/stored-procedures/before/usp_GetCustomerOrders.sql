-- =============================================
-- Stored Procedure: usp_GetCustomerOrders
-- Status:  BEFORE optimization (intentionally suboptimal)
-- 
-- ANTI-PATTERNS PRESENT:
--   1. Uses SELECT * instead of explicit columns
--   2. CURSOR-based row-by-row processing
--   3. Non-SARGable WHERE clause (CONVERT on column)
--   4. Missing SET NOCOUNT ON
--   5. No error handling (TRY/CATCH)
--   6. Scalar function call in SELECT
--   7. String concatenation in a loop
-- =============================================

USE ECommerceDemo;
GO

CREATE OR ALTER PROCEDURE usp_GetCustomerOrders
    @startDate VARCHAR(20),
    @endDate VARCHAR(20),
    @customerName VARCHAR(100) = NULL
AS
    -- Anti-pattern: Missing SET NOCOUNT ON (causes extra network traffic)

    -- Anti-pattern: Using SELECT * instead of explicit columns
    -- Anti-pattern: Non-SARGable predicate (CONVERT on column prevents index usage)
    -- Anti-pattern: LIKE with leading wildcard prevents index seek
    SELECT *
    INTO #TempOrders
    FROM Orders o
    INNER JOIN Customers c ON o.customer_id = c.id
    WHERE CONVERT(VARCHAR(10), o.order_date, 120) BETWEEN @startDate AND @endDate
        AND (@customerName IS NULL OR c.last_name LIKE '%' + @customerName + '%')

    -- Anti-pattern: CURSOR for row-by-row processing instead of set-based operation
    DECLARE @orderId INT
    DECLARE @totalItems INT
    DECLARE @orderSummary NVARCHAR(MAX) = ''

    DECLARE order_cursor CURSOR FOR
        SELECT id FROM #TempOrders

    OPEN order_cursor
    FETCH NEXT FROM order_cursor INTO @orderId

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Anti-pattern: Querying inside a loop
        SELECT @totalItems = COUNT(*)
        FROM OrderItems
        WHERE order_id = @orderId

        -- Anti-pattern: String concatenation in a loop (memory pressure)
        SET @orderSummary = @orderSummary + 'Order ' + CAST(@orderId AS VARCHAR) 
            + ': ' + CAST(@totalItems AS VARCHAR) + ' items; '

        FETCH NEXT FROM order_cursor INTO @orderId
    END

    CLOSE order_cursor
    DEALLOCATE order_cursor

    -- Return results with additional anti-patterns
    SELECT 
        t.*,
        -- Anti-pattern: Scalar subquery in SELECT (executes per row)
        (SELECT COUNT(*) FROM OrderItems WHERE order_id = t.id) AS item_count,
        -- Anti-pattern: Scalar subquery for aggregation
        (SELECT SUM(line_total) FROM OrderItems WHERE order_id = t.id) AS calculated_total,
        -- Anti-pattern: Nested subquery
        (SELECT TOP 1 p.name 
         FROM OrderItems oi 
         INNER JOIN Products p ON oi.product_id = p.id 
         WHERE oi.order_id = t.id 
         ORDER BY oi.line_total DESC) AS top_product
    FROM #TempOrders t
    ORDER BY t.order_date DESC

    DROP TABLE #TempOrders
GO
