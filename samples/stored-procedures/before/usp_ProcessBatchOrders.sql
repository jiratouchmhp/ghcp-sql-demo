-- =============================================
-- Stored Procedure: usp_ProcessBatchOrders
-- Status:  BEFORE optimization (intentionally suboptimal)
--
-- ANTI-PATTERNS PRESENT:
--   1. CURSOR for batch processing
--   2. Row-by-row INSERT/UPDATE inside loop
--   3. No transaction management
--   4. Missing error handling (no TRY/CATCH)
--   5. RBAR (Row-By-Agonizing-Row) pattern
--   6. Excessive PRINT statements (debug noise)
--   7. No SET NOCOUNT ON
--   8. Updating rows one at a time
--   9. Unnecessary temp table copies
--  10. No transaction isolation consideration
-- =============================================

USE ECommerceDemo;
GO

CREATE OR ALTER PROCEDURE usp_ProcessBatchOrders
    @batchDate DATE = NULL,
    @statusFilter NVARCHAR(50) = 'Pending'
AS
    -- Anti-pattern: Missing SET NOCOUNT ON

    IF @batchDate IS NULL
        SET @batchDate = GETDATE()

    -- Anti-pattern: SELECT * into temp table
    SELECT *
    INTO #PendingOrders
    FROM Orders
    WHERE status = @statusFilter
        AND CAST(order_date AS DATE) = @batchDate  -- Anti-pattern: CAST on column

    PRINT 'Found ' + CAST(@@ROWCOUNT AS VARCHAR) + ' pending orders'

    -- Anti-pattern: CURSOR for row-by-row processing
    DECLARE @orderId INT
    DECLARE @customerId INT
    DECLARE @totalAmount DECIMAL(12,2)
    DECLARE @itemCount INT
    DECLARE @processedCount INT = 0
    DECLARE @errorCount INT = 0

    DECLARE order_cursor CURSOR FOR
        SELECT id, customer_id, total_amount
        FROM #PendingOrders

    OPEN order_cursor
    FETCH NEXT FROM order_cursor INTO @orderId, @customerId, @totalAmount

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Anti-pattern: Querying inside the loop
        SELECT @itemCount = COUNT(*)
        FROM OrderItems
        WHERE order_id = @orderId

        -- Anti-pattern: Row-by-row validation
        IF @itemCount > 0
        BEGIN
            -- Anti-pattern: Individual UPDATE per row instead of batch UPDATE
            UPDATE Orders
            SET status = 'Processing',
                updated_at = GETUTCDATE()
            WHERE id = @orderId

            -- Anti-pattern: Recalculate total row-by-row  
            UPDATE Orders
            SET total_amount = (
                SELECT SUM(line_total) 
                FROM OrderItems 
                WHERE order_id = @orderId
            )
            WHERE id = @orderId

            -- Anti-pattern: Row-by-row inventory check
            DECLARE @productId INT
            DECLARE @quantity INT

            -- Anti-pattern: Nested CURSOR inside outer cursor!
            DECLARE item_cursor CURSOR FOR
                SELECT product_id, quantity
                FROM OrderItems
                WHERE order_id = @orderId

            OPEN item_cursor
            FETCH NEXT FROM item_cursor INTO @productId, @quantity

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Anti-pattern: Individual UPDATE per inventory item
                UPDATE Inventory
                SET quantity_on_hand = quantity_on_hand - @quantity,
                    updated_at = GETUTCDATE()
                WHERE product_id = @productId

                -- Anti-pattern: Checking after update instead of before
                IF (SELECT quantity_on_hand FROM Inventory WHERE product_id = @productId) < 0
                BEGIN
                    PRINT 'WARNING: Negative inventory for product ' + CAST(@productId AS VARCHAR)
                    -- Anti-pattern: Rolling back individual item but not the order
                    UPDATE Inventory
                    SET quantity_on_hand = quantity_on_hand + @quantity
                    WHERE product_id = @productId
                    
                    SET @errorCount = @errorCount + 1
                END

                FETCH NEXT FROM item_cursor INTO @productId, @quantity
            END

            CLOSE item_cursor
            DEALLOCATE item_cursor

            -- Anti-pattern: Row-by-row INSERT into SalesHistory
            INSERT INTO SalesHistory (product_id, customer_id, order_id, sale_date, quantity, revenue, cost, region)
            SELECT 
                oi.product_id,
                @customerId,
                @orderId,
                GETUTCDATE(),
                oi.quantity,
                oi.line_total,
                p.cost * oi.quantity,
                'Unknown'  -- Anti-pattern: Hardcoded value instead of deriving from data
            FROM OrderItems oi
            INNER JOIN Products p ON oi.product_id = p.id
            WHERE oi.order_id = @orderId

            -- Mark as completed
            UPDATE Orders
            SET status = 'Completed',
                updated_at = GETUTCDATE()
            WHERE id = @orderId

            SET @processedCount = @processedCount + 1

            -- Anti-pattern: Excessive PRINT statements (debug noise in production)
            PRINT 'Processed order #' + CAST(@orderId AS VARCHAR) 
                + ' for customer #' + CAST(@customerId AS VARCHAR)
                + ' with ' + CAST(@itemCount AS VARCHAR) + ' items'
        END
        ELSE
        BEGIN
            -- Mark orders with no items as cancelled
            UPDATE Orders
            SET status = 'Cancelled',
                updated_at = GETUTCDATE()
            WHERE id = @orderId

            SET @errorCount = @errorCount + 1
            PRINT 'Cancelled order #' + CAST(@orderId AS VARCHAR) + ' (no items)'
        END

        FETCH NEXT FROM order_cursor INTO @orderId, @customerId, @totalAmount
    END

    CLOSE order_cursor
    DEALLOCATE order_cursor

    -- Anti-pattern: No error handling, no transaction rollback capability
    PRINT '========================================='
    PRINT 'Batch processing complete'
    PRINT 'Processed: ' + CAST(@processedCount AS VARCHAR)
    PRINT 'Errors: ' + CAST(@errorCount AS VARCHAR)
    PRINT '========================================='

    -- Return summary
    SELECT 
        @processedCount AS orders_processed,
        @errorCount AS orders_with_errors,
        @processedCount + @errorCount AS total_orders

    DROP TABLE #PendingOrders
GO
