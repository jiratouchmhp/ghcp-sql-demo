-- =============================================
-- Stored Procedure: usp_SearchProducts
-- Status:  BEFORE optimization (intentionally suboptimal)
--
-- ANTI-PATTERNS PRESENT:
--   1. Non-SARGable predicates (functions on columns)
--   2. Implicit type conversion
--   3. OR conditions preventing index usage
--   4. SELECT * usage
--   5. LIKE with leading wildcards
--   6. Missing error handling
--   7. No parameter validation
--   8. Excessive use of scalar subqueries
-- =============================================

USE ECommerceDemo;
GO

CREATE OR ALTER PROCEDURE usp_SearchProducts
    @searchTerm NVARCHAR(200) = NULL,
    @minPrice VARCHAR(20) = NULL,        -- Anti-pattern: Wrong data type (should be DECIMAL)
    @maxPrice VARCHAR(20) = NULL,        -- Anti-pattern: Wrong data type
    @categoryId VARCHAR(10) = NULL,      -- Anti-pattern: Wrong data type (should be INT)
    @inStockOnly VARCHAR(5) = 'false',   -- Anti-pattern: Using string instead of BIT
    @sortBy VARCHAR(50) = 'name',
    @pageNumber INT = 1,
    @pageSize INT = 50
AS
    -- Anti-pattern: Missing SET NOCOUNT ON

    -- Anti-pattern: No parameter validation or sanitization
    
    -- Anti-pattern: SELECT * from multiple tables
    -- Anti-pattern: Non-SARGable LOWER() on column
    -- Anti-pattern: Leading wildcard in LIKE
    -- Anti-pattern: Implicit type conversion (comparing VARCHAR to INT/DECIMAL)
    SELECT *
    FROM Products p
    LEFT JOIN Categories c ON p.category_id = c.id
    LEFT JOIN Inventory i ON p.id = i.product_id
    WHERE 
        -- Anti-pattern: LOWER() function on column prevents index usage
        (@searchTerm IS NULL 
            OR LOWER(p.name) LIKE '%' + LOWER(@searchTerm) + '%'
            OR LOWER(p.description) LIKE '%' + LOWER(@searchTerm) + '%'
            OR LOWER(c.name) LIKE '%' + LOWER(@searchTerm) + '%')
        -- Anti-pattern: Implicit conversion VARCHAR to DECIMAL
        AND (@minPrice IS NULL OR p.price >= @minPrice)
        AND (@maxPrice IS NULL OR p.price <= @maxPrice)
        -- Anti-pattern: Implicit conversion VARCHAR to INT
        AND (@categoryId IS NULL OR p.category_id = @categoryId)
        -- Anti-pattern: String comparison instead of BIT logic
        AND (@inStockOnly = 'false' OR (@inStockOnly = 'true' AND i.quantity_on_hand > 0))
        -- Anti-pattern: Function on column
        AND ISNULL(p.is_active, 0) = 1
    ORDER BY
        -- Anti-pattern: CASE in ORDER BY can prevent index usage
        CASE @sortBy
            WHEN 'name' THEN p.name
            WHEN 'price_asc' THEN CAST(p.price AS NVARCHAR(20))
            WHEN 'price_desc' THEN CAST(p.price AS NVARCHAR(20))
            WHEN 'newest' THEN CONVERT(NVARCHAR(30), p.created_at, 120)
            ELSE p.name
        END

    -- NOTE: No pagination implemented despite parameters being accepted!
    -- Anti-pattern: Pagination parameters are declared but never used

    -- Anti-pattern: Separate query for total count (should be combined with windowed function)
    SELECT COUNT(*) AS total_results
    FROM Products p
    LEFT JOIN Categories c ON p.category_id = c.id
    LEFT JOIN Inventory i ON p.id = i.product_id
    WHERE 
        (@searchTerm IS NULL 
            OR LOWER(p.name) LIKE '%' + LOWER(@searchTerm) + '%'
            OR LOWER(p.description) LIKE '%' + LOWER(@searchTerm) + '%'
            OR LOWER(c.name) LIKE '%' + LOWER(@searchTerm) + '%')
        AND (@minPrice IS NULL OR p.price >= @minPrice)
        AND (@maxPrice IS NULL OR p.price <= @maxPrice)
        AND (@categoryId IS NULL OR p.category_id = @categoryId)
        AND (@inStockOnly = 'false' OR (@inStockOnly = 'true' AND i.quantity_on_hand > 0))
        AND ISNULL(p.is_active, 0) = 1
GO
