-- =============================================
-- Stored Procedure: usp_GenerateSalesReport
-- Status:  BEFORE optimization (intentionally suboptimal)
--
-- ANTI-PATTERNS PRESENT:
--   1. Massive cross-join due to missing join predicate
--   2. WHILE loop for aggregation instead of set-based
--   3. Multiple temp tables with no indexes
--   4. Repeated table scans
--   5. DISTINCT used to mask duplicate data from bad joins
--   6. Dynamic SQL built unsafely (SQL injection risk)
--   7. No error handling
--   8. Missing SET NOCOUNT ON
-- =============================================

USE ECommerceDemo;
GO

CREATE OR ALTER PROCEDURE usp_GenerateSalesReport
    @reportYear INT,
    @reportMonth INT = NULL,
    @region VARCHAR(50) = NULL,
    @sortColumn VARCHAR(50) = 'revenue'
AS
    -- Anti-pattern: Missing SET NOCOUNT ON

    -- Anti-pattern: Loading ALL data into temp table (no filtering at source)
    SELECT *
    INTO #AllSales
    FROM SalesHistory

    SELECT *
    INTO #AllProducts
    FROM Products

    SELECT *
    INTO #AllCustomers
    FROM Customers

    -- Anti-pattern: Non-SARGable filter using YEAR() and MONTH() functions on column
    DELETE FROM #AllSales
    WHERE YEAR(sale_date) <> @reportYear

    IF @reportMonth IS NOT NULL
        DELETE FROM #AllSales WHERE MONTH(sale_date) <> @reportMonth

    IF @region IS NOT NULL
        DELETE FROM #AllSales WHERE region <> @region

    -- Anti-pattern: WHILE loop to calculate running totals month-by-month
    DECLARE @currentMonth INT = 1
    CREATE TABLE #MonthlyTotals (
        month_number INT,
        total_revenue DECIMAL(18,2),
        total_cost DECIMAL(18,2),
        total_orders INT
    )

    WHILE @currentMonth <= 12
    BEGIN
        INSERT INTO #MonthlyTotals (month_number, total_revenue, total_cost, total_orders)
        SELECT 
            @currentMonth,
            ISNULL(SUM(revenue), 0),
            ISNULL(SUM(cost), 0),
            COUNT(DISTINCT order_id)
        FROM #AllSales
        WHERE MONTH(sale_date) = @currentMonth

        SET @currentMonth = @currentMonth + 1
    END

    -- Anti-pattern: DISTINCT to hide duplicates from improper join
    -- Anti-pattern: Joining without proper predicates can cause Cartesian product issues
    SELECT DISTINCT
        p.name AS product_name,
        p.category_id,
        c.name AS category_name,
        COUNT(*) AS times_sold,
        SUM(s.quantity) AS total_quantity,
        SUM(s.revenue) AS total_revenue,
        SUM(s.cost) AS total_cost,
        SUM(s.revenue) - SUM(s.cost) AS total_profit,
        -- Anti-pattern: Correlated subquery per row
        (SELECT COUNT(DISTINCT customer_id) FROM #AllSales WHERE product_id = s.product_id) AS unique_customers
    INTO #ProductSummary
    FROM #AllSales s
    LEFT JOIN #AllProducts p ON s.product_id = p.id
    LEFT JOIN Categories c ON p.category_id = c.id
    GROUP BY p.name, p.category_id, c.name, s.product_id

    -- Anti-pattern: Dynamic SQL with string concatenation (SQL injection risk)
    -- Anti-pattern: No parameterization of user input
    DECLARE @sql NVARCHAR(MAX)
    SET @sql = 'SELECT * FROM #ProductSummary ORDER BY ' + @sortColumn + ' DESC'
    EXEC(@sql)

    -- Return monthly totals
    SELECT * FROM #MonthlyTotals ORDER BY month_number

    -- Anti-pattern: Not cleaning up temp tables explicitly
    -- (they'll be cleaned up when session ends, but best practice is to drop them)
GO
