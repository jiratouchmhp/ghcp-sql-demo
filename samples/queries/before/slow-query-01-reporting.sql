USE ECommerceDemo;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT DISTINCT
    YEAR(sh.sale_date) AS sale_year,
    MONTH(sh.sale_date) AS sale_month,
    DATENAME(MONTH, sh.sale_date) AS month_name,
    
    SUM(sh.revenue) AS monthly_revenue,
    SUM(sh.cost) AS monthly_cost,
    SUM(sh.revenue) - SUM(sh.cost) AS monthly_profit,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT sh.customer_id) AS unique_customers,

    (SELECT SUM(s2.revenue)
     FROM SalesHistory s2
     WHERE YEAR(s2.sale_date) = YEAR(sh.sale_date)
       AND MONTH(s2.sale_date) = MONTH(sh.sale_date) - 1
    ) AS prev_month_revenue,

    (SELECT SUM(s3.revenue)
     FROM SalesHistory s3
     WHERE YEAR(s3.sale_date) = YEAR(sh.sale_date) - 1
       AND MONTH(s3.sale_date) = MONTH(sh.sale_date)
    ) AS same_month_last_year,

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
