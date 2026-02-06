-- =============================================
-- Slow Query 01: Monthly Revenue Report
-- Status:  Intentionally suboptimal for demo
--
-- ANTI-PATTERNS PRESENT:
--   1. Non-SARGable date functions (YEAR, MONTH)
--   2. Correlated subqueries in SELECT
--   3. Redundant table scans
--   4. Missing index hints
--   5. Unnecessary DISTINCT
--   6. Implicit conversion
-- =============================================

USE ECommerceDemo;
GO

-- Enable statistics for demo purposes
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- ============================================
-- Query: Monthly revenue breakdown with YoY comparison
-- Expected behavior: Full table scan on SalesHistory
-- ============================================

-- Anti-pattern: Functions on columns prevent index seek
-- Anti-pattern: Correlated subqueries execute once per output row
SELECT DISTINCT
    YEAR(sh.sale_date) AS sale_year,
    MONTH(sh.sale_date) AS sale_month,
    DATENAME(MONTH, sh.sale_date) AS month_name,
    
    -- Current period metrics
    SUM(sh.revenue) AS monthly_revenue,
    SUM(sh.cost) AS monthly_cost,
    SUM(sh.revenue) - SUM(sh.cost) AS monthly_profit,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT sh.customer_id) AS unique_customers,

    -- Anti-pattern: Correlated subquery for previous month revenue
    (SELECT SUM(s2.revenue)
     FROM SalesHistory s2
     WHERE YEAR(s2.sale_date) = YEAR(sh.sale_date)
       AND MONTH(s2.sale_date) = MONTH(sh.sale_date) - 1
    ) AS prev_month_revenue,

    -- Anti-pattern: Correlated subquery for same month last year
    (SELECT SUM(s3.revenue)
     FROM SalesHistory s3
     WHERE YEAR(s3.sale_date) = YEAR(sh.sale_date) - 1
       AND MONTH(s3.sale_date) = MONTH(sh.sale_date)
    ) AS same_month_last_year,

    -- Anti-pattern: Calculating YoY growth with duplicated correlated subqueries
    CASE 
        WHEN (SELECT SUM(s4.revenue)
              FROM SalesHistory s4
              WHERE YEAR(s4.sale_date) = YEAR(sh.sale_date) - 1
                AND MONTH(s4.sale_date) = MONTH(sh.sale_date)) > 0
        THEN ROUND(
            (SUM(sh.revenue) - 
             (SELECT SUM(s5.revenue)
              FROM SalesHistory s5
              WHERE YEAR(s5.sale_date) = YEAR(sh.sale_date) - 1
                AND MONTH(s5.sale_date) = MONTH(sh.sale_date))
            ) / 
            (SELECT SUM(s6.revenue)
             FROM SalesHistory s6
             WHERE YEAR(s6.sale_date) = YEAR(sh.sale_date) - 1
               AND MONTH(s6.sale_date) = MONTH(sh.sale_date)) * 100
        , 2)
        ELSE NULL
    END AS yoy_growth_pct,

    -- Anti-pattern: Correlated subquery for top product
    (SELECT TOP 1 p.name
     FROM SalesHistory sub
     INNER JOIN Products p ON sub.product_id = p.id
     WHERE YEAR(sub.sale_date) = YEAR(sh.sale_date)
       AND MONTH(sub.sale_date) = MONTH(sh.sale_date)
     GROUP BY p.name
     ORDER BY SUM(sub.revenue) DESC
    ) AS top_product

FROM SalesHistory sh
GROUP BY 
    YEAR(sh.sale_date),
    MONTH(sh.sale_date),
    DATENAME(MONTH, sh.sale_date)
ORDER BY 
    sale_year DESC,
    sale_month DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
