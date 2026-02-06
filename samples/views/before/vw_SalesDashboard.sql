-- =============================================
-- View:    vw_SalesDashboard
-- Status:  BEFORE optimization (intentionally suboptimal)
--
-- ANTI-PATTERNS PRESENT:
--   1. Functions on columns (YEAR, MONTH, DATEPART)
--   2. Multiple correlated subqueries
--   3. Redundant joins
--   4. No schema binding
--   5. Mixing aggregation levels (detail + summary)
--   6. Union with incompatible aggregation
--   7. Implicit conversion in joins
-- =============================================

USE ECommerceDemo;
GO

CREATE OR ALTER VIEW vw_SalesDashboard
AS
    SELECT
        -- Anti-pattern: Functions on columns prevent index usage
        YEAR(sh.sale_date) AS sale_year,
        MONTH(sh.sale_date) AS sale_month,
        DATENAME(MONTH, sh.sale_date) AS month_name,
        DATEPART(QUARTER, sh.sale_date) AS sale_quarter,
        sh.region,

        -- Basic metrics
        COUNT(*) AS transaction_count,
        SUM(sh.quantity) AS total_units_sold,
        SUM(sh.revenue) AS total_revenue,
        SUM(sh.cost) AS total_cost,
        SUM(sh.revenue) - SUM(sh.cost) AS gross_profit,
        
        -- Anti-pattern: Complex calculations prevent simple reads
        CASE 
            WHEN SUM(sh.revenue) > 0 
            THEN ROUND((SUM(sh.revenue) - SUM(sh.cost)) / SUM(sh.revenue) * 100, 2)
            ELSE 0 
        END AS profit_margin_pct,

        COUNT(DISTINCT sh.customer_id) AS unique_customers,
        COUNT(DISTINCT sh.product_id) AS unique_products,
        COUNT(DISTINCT sh.order_id) AS unique_orders,

        -- Anti-pattern: Correlated subquery — category needs to be derived per row group
        (SELECT TOP 1 c.name 
         FROM Products p 
         INNER JOIN Categories c ON p.category_id = c.id
         WHERE p.id = (
             SELECT TOP 1 product_id 
             FROM SalesHistory 
             WHERE region = sh.region 
                AND YEAR(sale_date) = YEAR(sh.sale_date) 
                AND MONTH(sale_date) = MONTH(sh.sale_date)
             GROUP BY product_id 
             ORDER BY SUM(revenue) DESC
         )
        ) AS top_category,

        -- Anti-pattern: Another correlated subquery per group
        (SELECT TOP 1 p.name 
         FROM SalesHistory sub
         INNER JOIN Products p ON sub.product_id = p.id
         WHERE sub.region = sh.region 
            AND YEAR(sub.sale_date) = YEAR(sh.sale_date) 
            AND MONTH(sub.sale_date) = MONTH(sh.sale_date)
         GROUP BY p.name
         ORDER BY SUM(sub.revenue) DESC
        ) AS best_selling_product,

        -- Anti-pattern: Correlated subquery for previous month comparison
        ISNULL(
            (SELECT SUM(sub.revenue)
             FROM SalesHistory sub
             WHERE sub.region = sh.region
                AND YEAR(sub.sale_date) = YEAR(sh.sale_date)
                AND MONTH(sub.sale_date) = MONTH(sh.sale_date) - 1
            ), 0
        ) AS previous_month_revenue,

        -- Anti-pattern: Correlated subquery for YoY comparison
        ISNULL(
            (SELECT SUM(sub.revenue)
             FROM SalesHistory sub
             WHERE sub.region = sh.region
                AND YEAR(sub.sale_date) = YEAR(sh.sale_date) - 1
                AND MONTH(sub.sale_date) = MONTH(sh.sale_date)
            ), 0
        ) AS same_month_last_year_revenue

    FROM SalesHistory sh
    GROUP BY
        YEAR(sh.sale_date),
        MONTH(sh.sale_date),
        DATENAME(MONTH, sh.sale_date),
        DATEPART(QUARTER, sh.sale_date),
        sh.region;
GO
