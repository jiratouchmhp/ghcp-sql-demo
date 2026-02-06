-- =============================================
-- SSIS Script: ETL_CustomerDataLoad
-- Status:    BEFORE optimization (intentionally suboptimal)
-- Component: T-SQL representation of SSIS Data Flow Task
--
-- ANTI-PATTERNS PRESENT:
--   1. Row-by-row processing (simulated OLE DB Command per row)
--   2. No-cache Lookup Transform (queries DB per row)
--   3. Individual INSERT statements instead of bulk load
--   4. No error handling or logging
--   5. No batch size configuration
--   6. RBAR (Row-By-Agonizing-Row) pattern
--   7. Synchronous pipeline design
--   8. No data validation before insert
-- =============================================

USE ECommerceDemo;
GO

-- =============================================
-- SSIS Package: ETL_CustomerDataLoad.dtsx
-- Description: Load customer data from staging to production
-- Data Flow:   Staging → Lookup → OLE DB Destination
-- =============================================

-- Simulated staging table (source)
IF OBJECT_ID('staging.CustomerImport', 'U') IS NOT NULL
    DROP TABLE staging.CustomerImport;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO

CREATE TABLE staging.CustomerImport (
    row_id          INT IDENTITY(1,1),
    first_name      NVARCHAR(100),
    last_name       NVARCHAR(100),
    email           NVARCHAR(255),
    phone           NVARCHAR(20),
    address         NVARCHAR(500),
    city            NVARCHAR(100),
    state           NVARCHAR(50),
    zip_code        NVARCHAR(20),
    country         NVARCHAR(100),
    import_status   NVARCHAR(20) DEFAULT 'Pending',
    error_message   NVARCHAR(500) NULL,
    processed_at    DATETIME2 NULL
);
GO

-- =============================================
-- SSIS Data Flow Task (simulated in T-SQL)
-- This represents the TERRIBLE way to do it in SSIS
-- =============================================

CREATE OR ALTER PROCEDURE usp_SSIS_LoadCustomerData
AS
    -- Anti-pattern: Missing SET NOCOUNT ON

    DECLARE @rowId INT
    DECLARE @firstName NVARCHAR(100)
    DECLARE @lastName NVARCHAR(100)
    DECLARE @email NVARCHAR(255)
    DECLARE @phone NVARCHAR(20)
    DECLARE @address NVARCHAR(500)
    DECLARE @city NVARCHAR(100)
    DECLARE @state NVARCHAR(50)
    DECLARE @zipCode NVARCHAR(20)
    DECLARE @country NVARCHAR(100)
    DECLARE @existingId INT
    DECLARE @processedCount INT = 0
    DECLARE @errorCount INT = 0
    DECLARE @startTime DATETIME2 = GETUTCDATE()

    -- =============================================
    -- Anti-pattern: CURSOR to process rows one at a time
    -- SSIS equivalent: OLE DB Source → Row-by-row processing
    -- Should use: Bulk Insert or OLE DB Destination with Fast Load
    -- =============================================
    DECLARE customer_cursor CURSOR FOR
        SELECT row_id, first_name, last_name, email, phone, 
               address, city, state, zip_code, country
        FROM staging.CustomerImport
        WHERE import_status = 'Pending'

    OPEN customer_cursor
    FETCH NEXT FROM customer_cursor INTO 
        @rowId, @firstName, @lastName, @email, @phone,
        @address, @city, @state, @zipCode, @country

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @existingId = NULL

        -- =============================================
        -- Anti-pattern: Lookup with NO CACHE mode
        -- SSIS equivalent: Lookup Transform with "No Cache" setting
        -- This queries the database for EVERY SINGLE ROW
        -- Should use: Full Cache or Partial Cache mode
        -- =============================================
        SELECT @existingId = id
        FROM Customers
        WHERE email = @email

        IF @existingId IS NOT NULL
        BEGIN
            -- =============================================
            -- Anti-pattern: Individual UPDATE per row
            -- SSIS equivalent: OLE DB Command transform (executes per row)
            -- Should use: Batch UPDATE with staging table JOIN
            -- =============================================
            UPDATE Customers
            SET first_name = @firstName,
                last_name = @lastName,
                phone = @phone,
                address = @address,
                city = @city,
                state = @state,
                zip_code = @zipCode,
                country = @country,
                updated_at = GETUTCDATE()
            WHERE id = @existingId

            UPDATE staging.CustomerImport
            SET import_status = 'Updated',
                processed_at = GETUTCDATE()
            WHERE row_id = @rowId
        END
        ELSE
        BEGIN
            -- =============================================
            -- Anti-pattern: Individual INSERT per row
            -- SSIS equivalent: OLE DB Destination WITHOUT Fast Load
            -- Should use: OLE DB Destination with "Table or View - Fast Load"
            -- with batch size = 10000 and "Table Lock" option
            -- =============================================
            INSERT INTO Customers (first_name, last_name, email, phone,
                                   address, city, state, zip_code, country)
            VALUES (@firstName, @lastName, @email, @phone,
                    @address, @city, @state, @zipCode, @country)

            UPDATE staging.CustomerImport
            SET import_status = 'Inserted',
                processed_at = GETUTCDATE()
            WHERE row_id = @rowId
        END

        SET @processedCount = @processedCount + 1

        -- Anti-pattern: PRINT per row (massive overhead in SSIS logging)
        PRINT 'Processed row ' + CAST(@rowId AS VARCHAR) + ': ' + @email

        FETCH NEXT FROM customer_cursor INTO 
            @rowId, @firstName, @lastName, @email, @phone,
            @address, @city, @state, @zipCode, @country
    END

    CLOSE customer_cursor
    DEALLOCATE customer_cursor

    -- Anti-pattern: No error handling — if any row fails, partial data is committed
    -- Anti-pattern: No transaction management
    -- Anti-pattern: No package-level logging

    PRINT 'ETL Complete: ' + CAST(@processedCount AS VARCHAR) + ' rows processed'
    PRINT 'Duration: ' + CAST(DATEDIFF(SECOND, @startTime, GETUTCDATE()) AS VARCHAR) + ' seconds'
GO
