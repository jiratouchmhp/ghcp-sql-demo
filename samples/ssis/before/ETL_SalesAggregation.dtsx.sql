-- =============================================
-- SSIS Script: ETL_SalesAggregation
-- Status:    BEFORE optimization (intentionally suboptimal)
-- Component: T-SQL representation of SSIS Data Flow Task
--
-- ANTI-PATTERNS PRESENT:
--   1. Row-by-row aggregation instead of set-based
--   2. No-cache Lookup for dimension data
--   3. WHILE loop for date iteration
--   4. Temp tables without indexes
--   5. No error handling or event handlers
--   6. Synchronous transformations for heavy operations
--   7. No incremental load strategy (full reload each time)
--   8. Missing package configuration/parameterization
-- =============================================

USE ECommerceDemo;
GO

-- =============================================
-- SSIS Package: ETL_SalesAggregation.dtsx
-- Description: Aggregate daily sales into summary tables
-- Schedule:    Nightly batch ETL
-- =============================================

-- Destination table for aggregated sales
IF OBJECT_ID('dbo.DailySalesSummary', 'U') IS NOT NULL
    DROP TABLE dbo.DailySalesSummary;
GO

CREATE TABLE dbo.DailySalesSummary (
    summary_id      INT IDENTITY(1,1) PRIMARY KEY,
    sale_date       DATE NOT NULL,
    product_id      INT NOT NULL,
    category_id     INT NULL,
    category_name   NVARCHAR(200) NULL,
    region          NVARCHAR(50) NOT NULL,
    total_quantity  INT NOT NULL,
    total_revenue   DECIMAL(18,2) NOT NULL,
    total_cost      DECIMAL(18,2) NOT NULL,
    total_profit    DECIMAL(18,2) NOT NULL,
    order_count     INT NOT NULL,
    customer_count  INT NOT NULL,
    avg_unit_price  DECIMAL(10,2) NULL,
    created_at      DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- =============================================
-- SSIS Data Flow Task (simulated — the BAD way)
-- =============================================

CREATE OR ALTER PROCEDURE usp_SSIS_AggregateSales
    @startDate DATE = NULL,
    @endDate DATE = NULL
AS
    -- Anti-pattern: Missing SET NOCOUNT ON
    
    DECLARE @currentDate DATE
    DECLARE @startTime DATETIME2 = GETUTCDATE()
    
    IF @startDate IS NULL
        SET @startDate = DATEADD(YEAR, -2, GETDATE())
    IF @endDate IS NULL
        SET @endDate = GETDATE()

    -- =============================================
    -- Anti-pattern: DELETE ALL and reload (full refresh)
    -- SSIS equivalent: Truncate destination before load
    -- Should use: Incremental load with watermark/CDC
    -- =============================================
    DELETE FROM DailySalesSummary
    PRINT 'Cleared DailySalesSummary table'

    -- =============================================
    -- Anti-pattern: WHILE loop iterating day by day
    -- SSIS equivalent: For Loop Container with daily iteration
    -- Should use: Single set-based INSERT with GROUP BY
    -- =============================================
    SET @currentDate = @startDate

    WHILE @currentDate <= @endDate
    BEGIN
        PRINT 'Processing date: ' + CONVERT(VARCHAR(10), @currentDate, 120)

        -- Anti-pattern: Cursor within the WHILE loop to process each product
        DECLARE @productId INT
        DECLARE @region NVARCHAR(50)

        -- =============================================
        -- Anti-pattern: Nested cursor for product × region combinations
        -- SSIS equivalent: Merge Join with unsorted inputs
        -- =============================================
        DECLARE product_cursor CURSOR FOR
            SELECT DISTINCT product_id, region
            FROM SalesHistory
            WHERE CAST(sale_date AS DATE) = @currentDate  -- Anti-pattern: CAST on column

        OPEN product_cursor
        FETCH NEXT FROM product_cursor INTO @productId, @region

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @totalQty INT
            DECLARE @totalRev DECIMAL(18,2)
            DECLARE @totalCost DECIMAL(18,2)
            DECLARE @orderCount INT
            DECLARE @custCount INT
            DECLARE @categoryId INT
            DECLARE @categoryName NVARCHAR(200)
            DECLARE @avgPrice DECIMAL(10,2)

            -- =============================================
            -- Anti-pattern: Individual aggregation query per product/region/date
            -- This is the equivalent of a No-Cache Lookup per row
            -- =============================================
            SELECT 
                @totalQty = SUM(quantity),
                @totalRev = SUM(revenue),
                @totalCost = SUM(cost),
                @orderCount = COUNT(DISTINCT order_id),
                @custCount = COUNT(DISTINCT customer_id)
            FROM SalesHistory
            WHERE product_id = @productId
                AND region = @region
                AND CAST(sale_date AS DATE) = @currentDate

            -- Anti-pattern: Separate lookup for category (No Cache)
            SELECT @categoryId = category_id
            FROM Products
            WHERE id = @productId

            SELECT @categoryName = name
            FROM Categories
            WHERE id = @categoryId

            -- Anti-pattern: Separate calculation
            SET @avgPrice = CASE WHEN @totalQty > 0 THEN @totalRev / @totalQty ELSE 0 END

            -- =============================================
            -- Anti-pattern: Individual INSERT per aggregation row
            -- SSIS equivalent: OLE DB Destination without Fast Load
            -- =============================================
            INSERT INTO DailySalesSummary (
                sale_date, product_id, category_id, category_name, region,
                total_quantity, total_revenue, total_cost, total_profit,
                order_count, customer_count, avg_unit_price
            )
            VALUES (
                @currentDate, @productId, @categoryId, @categoryName, @region,
                @totalQty, @totalRev, @totalCost, @totalRev - @totalCost,
                @orderCount, @custCount, @avgPrice
            )

            FETCH NEXT FROM product_cursor INTO @productId, @region
        END

        CLOSE product_cursor
        DEALLOCATE product_cursor

        -- Move to next day
        SET @currentDate = DATEADD(DAY, 1, @currentDate)
    END

    -- Anti-pattern: No error handling
    -- Anti-pattern: No checkpoint/restart capability
    -- Anti-pattern: No logging to SSISDB or custom log table

    PRINT 'ETL Complete'
    PRINT 'Total rows: ' + CAST((SELECT COUNT(*) FROM DailySalesSummary) AS VARCHAR)
    PRINT 'Duration: ' + CAST(DATEDIFF(SECOND, @startTime, GETUTCDATE()) AS VARCHAR) + ' seconds'
GO
