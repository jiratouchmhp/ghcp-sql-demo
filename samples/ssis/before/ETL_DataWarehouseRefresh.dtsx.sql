-- =============================================
-- SSIS Script: ETL_DataWarehouseRefresh
-- Status:    BEFORE optimization (intentionally suboptimal)
-- Component: T-SQL representation of SSIS Control/Data Flow
--
-- ANTI-PATTERNS PRESENT:
--   1. Full table reload instead of incremental
--   2. Sequential processing (no parallel data flows)
--   3. Row-by-row SCD (Slowly Changing Dimension) handling
--   4. No-cache lookups everywhere
--   5. Missing error routing / event handlers
--   6. No package-level logging or auditing
--   7. Hardcoded connection strings / values
--   8. No checkpoint/restart capability
--   9. Blocking synchronous transforms
--  10. No data quality checks
-- =============================================

USE ECommerceDemo;
GO

-- =============================================
-- SSIS Package: ETL_DataWarehouseRefresh.dtsx
-- Description: Full data warehouse refresh from OLTP source
-- Schedule:    Nightly (runs 3-5 hours due to anti-patterns)
-- Should run:  Under 30 minutes with optimizations
-- =============================================

-- DW dimension tables
IF OBJECT_ID('dw.DimCustomer', 'U') IS NOT NULL DROP TABLE dw.DimCustomer;
IF OBJECT_ID('dw.DimProduct', 'U') IS NOT NULL DROP TABLE dw.DimProduct;
IF OBJECT_ID('dw.FactSales', 'U') IS NOT NULL DROP TABLE dw.FactSales;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO

CREATE TABLE dw.DimCustomer (
    customer_key        INT IDENTITY(1,1) PRIMARY KEY,
    customer_id         INT NOT NULL,
    full_name           NVARCHAR(201) NOT NULL,
    email               NVARCHAR(255),
    city                NVARCHAR(100),
    state               NVARCHAR(50),
    country             NVARCHAR(100),
    is_current          BIT DEFAULT 1,
    effective_date      DATE NOT NULL,
    expiration_date     DATE NULL,
    created_at          DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE dw.DimProduct (
    product_key         INT IDENTITY(1,1) PRIMARY KEY,
    product_id          INT NOT NULL,
    product_name        NVARCHAR(300) NOT NULL,
    category_name       NVARCHAR(200),
    price               DECIMAL(10,2),
    cost                DECIMAL(10,2),
    sku                 NVARCHAR(50),
    is_current          BIT DEFAULT 1,
    effective_date      DATE NOT NULL,
    expiration_date     DATE NULL,
    created_at          DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE dw.FactSales (
    fact_id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    customer_key        INT NOT NULL,
    product_key         INT NOT NULL,
    order_id            INT NOT NULL,
    order_date          DATE NOT NULL,
    quantity            INT NOT NULL,
    unit_price          DECIMAL(10,2) NOT NULL,
    discount_percent    DECIMAL(5,2) NOT NULL,
    line_total          DECIMAL(12,2) NOT NULL,
    cost_total          DECIMAL(12,2) NOT NULL,
    profit              DECIMAL(12,2) NOT NULL,
    region              NVARCHAR(50),
    created_at          DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- =============================================
-- Master ETL Procedure (simulates SSIS Control Flow)
-- =============================================

CREATE OR ALTER PROCEDURE usp_SSIS_RefreshDataWarehouse
AS
    -- Anti-pattern: Missing SET NOCOUNT ON
    DECLARE @startTime DATETIME2 = GETUTCDATE()
    DECLARE @stepStart DATETIME2

    PRINT '========================================'
    PRINT 'Starting Data Warehouse Refresh'
    PRINT 'Start Time: ' + CONVERT(VARCHAR(30), @startTime, 120)
    PRINT '========================================'

    -- =============================================
    -- STEP 1: Refresh DimCustomer (SCD Type 2 — done WRONG)
    -- Anti-pattern: Row-by-row SCD processing via cursor
    -- SSIS equivalent: Slowly Changing Dimension transform
    -- (which is already known to be slow in SSIS!)
    -- =============================================
    SET @stepStart = GETUTCDATE()
    PRINT 'Step 1: Refreshing DimCustomer...'

    DECLARE @custId INT
    DECLARE @custName NVARCHAR(201)
    DECLARE @custEmail NVARCHAR(255)
    DECLARE @custCity NVARCHAR(100)
    DECLARE @custState NVARCHAR(50)
    DECLARE @custCountry NVARCHAR(100)
    DECLARE @existingKey INT
    DECLARE @existingName NVARCHAR(201)
    DECLARE @existingCity NVARCHAR(100)

    -- Anti-pattern: Cursor over ALL customers (even unchanged ones)
    DECLARE cust_cursor CURSOR FOR
        SELECT 
            id,
            first_name + ' ' + last_name,
            email, city, state, country
        FROM Customers

    OPEN cust_cursor
    FETCH NEXT FROM cust_cursor INTO @custId, @custName, @custEmail, @custCity, @custState, @custCountry

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Anti-pattern: No-cache lookup per row
        SELECT TOP 1 
            @existingKey = customer_key,
            @existingName = full_name,
            @existingCity = city
        FROM dw.DimCustomer
        WHERE customer_id = @custId AND is_current = 1

        IF @existingKey IS NOT NULL
        BEGIN
            -- Anti-pattern: Check for changes row-by-row
            IF @existingName <> @custName OR @existingCity <> @custCity
            BEGIN
                -- Anti-pattern: Individual UPDATE to expire old record
                UPDATE dw.DimCustomer
                SET is_current = 0,
                    expiration_date = CAST(GETUTCDATE() AS DATE)
                WHERE customer_key = @existingKey

                -- Anti-pattern: Individual INSERT for new version
                INSERT INTO dw.DimCustomer (customer_id, full_name, email, city, state, country,
                                            is_current, effective_date)
                VALUES (@custId, @custName, @custEmail, @custCity, @custState, @custCountry,
                        1, CAST(GETUTCDATE() AS DATE))
            END
            -- else: no change, skip (but we still queried!)
        END
        ELSE
        BEGIN
            -- Anti-pattern: Individual INSERT for new customer
            INSERT INTO dw.DimCustomer (customer_id, full_name, email, city, state, country,
                                        is_current, effective_date)
            VALUES (@custId, @custName, @custEmail, @custCity, @custState, @custCountry,
                    1, CAST(GETUTCDATE() AS DATE))
        END

        FETCH NEXT FROM cust_cursor INTO @custId, @custName, @custEmail, @custCity, @custState, @custCountry
    END

    CLOSE cust_cursor
    DEALLOCATE cust_cursor

    PRINT 'Step 1 complete: ' + CAST(DATEDIFF(SECOND, @stepStart, GETUTCDATE()) AS VARCHAR) + 's'

    -- =============================================
    -- STEP 2: Refresh DimProduct (same RBAR anti-pattern)
    -- =============================================
    SET @stepStart = GETUTCDATE()
    PRINT 'Step 2: Refreshing DimProduct...'

    DECLARE @prodId INT
    DECLARE @prodName NVARCHAR(300)
    DECLARE @catName NVARCHAR(200)
    DECLARE @prodPrice DECIMAL(10,2)
    DECLARE @prodCost DECIMAL(10,2)
    DECLARE @prodSku NVARCHAR(50)
    DECLARE @existProdKey INT

    -- Anti-pattern: Cursor over ALL products
    DECLARE prod_cursor CURSOR FOR
        SELECT p.id, p.name, c.name, p.price, p.cost, p.sku
        FROM Products p
        LEFT JOIN Categories c ON p.category_id = c.id

    OPEN prod_cursor
    FETCH NEXT FROM prod_cursor INTO @prodId, @prodName, @catName, @prodPrice, @prodCost, @prodSku

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @existProdKey = NULL

        -- Anti-pattern: No-cache lookup per row
        SELECT @existProdKey = product_key
        FROM dw.DimProduct
        WHERE product_id = @prodId AND is_current = 1

        IF @existProdKey IS NOT NULL
        BEGIN
            -- Anti-pattern: Individual UPDATE
            UPDATE dw.DimProduct
            SET product_name = @prodName,
                category_name = @catName,
                price = @prodPrice,
                cost = @prodCost,
                sku = @prodSku
            WHERE product_key = @existProdKey
        END
        ELSE
        BEGIN
            -- Anti-pattern: Individual INSERT
            INSERT INTO dw.DimProduct (product_id, product_name, category_name, price, cost, sku,
                                       is_current, effective_date)
            VALUES (@prodId, @prodName, @catName, @prodPrice, @prodCost, @prodSku,
                    1, CAST(GETUTCDATE() AS DATE))
        END

        FETCH NEXT FROM prod_cursor INTO @prodId, @prodName, @catName, @prodPrice, @prodCost, @prodSku
    END

    CLOSE prod_cursor
    DEALLOCATE prod_cursor

    PRINT 'Step 2 complete: ' + CAST(DATEDIFF(SECOND, @stepStart, GETUTCDATE()) AS VARCHAR) + 's'

    -- =============================================
    -- STEP 3: Load FactSales
    -- Anti-pattern: DELETE ALL and reload (no incremental)
    -- Anti-pattern: Row-by-row lookup for surrogate keys
    -- =============================================
    SET @stepStart = GETUTCDATE()
    PRINT 'Step 3: Loading FactSales...'

    -- Anti-pattern: Full truncate and reload
    DELETE FROM dw.FactSales
    PRINT 'Cleared FactSales table'

    DECLARE @orderId INT
    DECLARE @orderDate DATE
    DECLARE @orderCustId INT
    DECLARE @oiProductId INT
    DECLARE @oiQuantity INT
    DECLARE @oiUnitPrice DECIMAL(10,2)
    DECLARE @oiDiscount DECIMAL(5,2)
    DECLARE @oiLineTotal DECIMAL(12,2)
    DECLARE @custKey INT
    DECLARE @prodKey INT
    DECLARE @prodCostVal DECIMAL(10,2)

    -- Anti-pattern: Cursor over millions of rows!
    DECLARE fact_cursor CURSOR FOR
        SELECT 
            o.id, o.order_date, o.customer_id,
            oi.product_id, oi.quantity, oi.unit_price,
            oi.discount_percent, oi.line_total
        FROM Orders o
        INNER JOIN OrderItems oi ON o.id = oi.order_id
        WHERE o.status = 'Completed'

    OPEN fact_cursor
    FETCH NEXT FROM fact_cursor INTO 
        @orderId, @orderDate, @orderCustId,
        @oiProductId, @oiQuantity, @oiUnitPrice,
        @oiDiscount, @oiLineTotal

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Anti-pattern: Lookup customer surrogate key per row
        SELECT @custKey = customer_key
        FROM dw.DimCustomer
        WHERE customer_id = @orderCustId AND is_current = 1

        -- Anti-pattern: Lookup product surrogate key per row
        SELECT @prodKey = product_key, @prodCostVal = cost
        FROM dw.DimProduct
        WHERE product_id = @oiProductId AND is_current = 1

        -- Anti-pattern: Individual INSERT for each fact row
        IF @custKey IS NOT NULL AND @prodKey IS NOT NULL
        BEGIN
            INSERT INTO dw.FactSales (
                customer_key, product_key, order_id, order_date,
                quantity, unit_price, discount_percent, line_total,
                cost_total, profit, region
            )
            VALUES (
                @custKey, @prodKey, @orderId, @orderDate,
                @oiQuantity, @oiUnitPrice, @oiDiscount, @oiLineTotal,
                @prodCostVal * @oiQuantity,
                @oiLineTotal - (@prodCostVal * @oiQuantity),
                'Unknown'  -- Anti-pattern: Hardcoded instead of derived
            )
        END

        FETCH NEXT FROM fact_cursor INTO 
            @orderId, @orderDate, @orderCustId,
            @oiProductId, @oiQuantity, @oiUnitPrice,
            @oiDiscount, @oiLineTotal
    END

    CLOSE fact_cursor
    DEALLOCATE fact_cursor

    PRINT 'Step 3 complete: ' + CAST(DATEDIFF(SECOND, @stepStart, GETUTCDATE()) AS VARCHAR) + 's'

    -- =============================================
    -- Summary
    -- =============================================
    PRINT '========================================'
    PRINT 'Data Warehouse Refresh Complete'
    PRINT 'DimCustomer: ' + CAST((SELECT COUNT(*) FROM dw.DimCustomer) AS VARCHAR) + ' rows'
    PRINT 'DimProduct: ' + CAST((SELECT COUNT(*) FROM dw.DimProduct) AS VARCHAR) + ' rows'
    PRINT 'FactSales: ' + CAST((SELECT COUNT(*) FROM dw.FactSales) AS VARCHAR) + ' rows'
    PRINT 'Total Duration: ' + CAST(DATEDIFF(SECOND, @startTime, GETUTCDATE()) AS VARCHAR) + ' seconds'
    PRINT '========================================'

    -- Anti-pattern: No error handling throughout
    -- Anti-pattern: No checkpoint/restart capability
    -- Anti-pattern: No package-level logging to SSISDB catalog
    -- Anti-pattern: No data validation or reconciliation counts
GO
