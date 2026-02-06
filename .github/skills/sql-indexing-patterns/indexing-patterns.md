# SQL Server Indexing Patterns

## 1. Covering Indexes

A covering index includes all columns needed by a query, eliminating key lookups.

```sql
-- Query pattern:
SELECT customer_id, order_date, total_amount
FROM Orders
WHERE status = 'Completed' AND order_date >= '2024-01-01';

-- Covering index:
CREATE NONCLUSTERED INDEX IX_Orders_Status_OrderDate
ON dbo.Orders (status, order_date)
INCLUDE (customer_id, total_amount);
```

**When to use:** Queries with a narrow WHERE clause that SELECT additional columns.

## 2. Composite Key Indexes

Column order matters. Place the most selective / equality-predicate column first.

```sql
-- Good: Equality column first, then range column
CREATE NONCLUSTERED INDEX IX_SalesHistory_Region_SaleDate
ON dbo.SalesHistory (region, sale_date)
INCLUDE (revenue, cost);

-- Bad: Range column first (less selective seek)
CREATE NONCLUSTERED INDEX IX_SalesHistory_SaleDate_Region
ON dbo.SalesHistory (sale_date, region);
```

**Column order rules:**
1. Equality predicates first
2. Range predicates second
3. ORDER BY columns third (if not in INCLUDE)
4. INCLUDE for SELECT-only columns

## 3. Filtered Indexes

Indexes on a subset of rows — smaller, faster, and more efficient.

```sql
-- Only index active products (majority of queries filter on is_active = 1)
CREATE NONCLUSTERED INDEX IX_Products_Active_Name
ON dbo.Products (name)
INCLUDE (price, category_id)
WHERE is_active = 1;

-- Only index completed orders
CREATE NONCLUSTERED INDEX IX_Orders_Completed_Date
ON dbo.Orders (order_date, customer_id)
INCLUDE (total_amount)
WHERE status = 'Completed';
```

**When to use:** Tables where queries consistently filter on a fixed predicate.

## 4. Columnstore Indexes

Best for analytics/reporting queries that scan large portions of a table.

```sql
-- Clustered columnstore for fact tables
CREATE CLUSTERED COLUMNSTORE INDEX CCI_SalesHistory
ON dbo.SalesHistory;

-- Nonclustered columnstore for mixed workloads (HTAP)
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Orders_Analytics
ON dbo.Orders (order_date, status, total_amount, customer_id);
```

**When to use:** Aggregation-heavy queries, data warehouse fact tables, reporting.

## 5. Index Maintenance

```sql
-- Check fragmentation
SELECT 
    OBJECT_NAME(ips.object_id) AS table_name,
    i.name AS index_name,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
    AND ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- Maintenance strategy:
-- < 10% fragmentation: No action
-- 10-30% fragmentation: REORGANIZE
-- > 30% fragmentation: REBUILD
```

## 6. Missing Index DMV Query

```sql
SELECT TOP 20
    ROUND(gs.avg_total_user_cost * gs.avg_user_impact * (gs.user_seeks + gs.user_scans), 0) AS improvement_measure,
    OBJECT_NAME(d.object_id) AS table_name,
    'CREATE NONCLUSTERED INDEX IX_' 
        + OBJECT_NAME(d.object_id) + '_' 
        + REPLACE(REPLACE(ISNULL(d.equality_columns, ''), '[', ''), ']', '')
        + ' ON ' + d.statement 
        + ' (' + ISNULL(d.equality_columns, '') 
        + CASE WHEN d.equality_columns IS NOT NULL AND d.inequality_columns IS NOT NULL THEN ', ' ELSE '' END
        + ISNULL(d.inequality_columns, '') + ')'
        + ISNULL(' INCLUDE (' + d.included_columns + ')', '') AS create_index_statement,
    gs.user_seeks,
    gs.user_scans,
    gs.avg_total_user_cost,
    gs.avg_user_impact
FROM sys.dm_db_missing_index_group_stats gs
INNER JOIN sys.dm_db_missing_index_groups g ON gs.group_handle = g.index_group_handle
INNER JOIN sys.dm_db_missing_index_details d ON g.index_handle = d.index_handle
WHERE d.database_id = DB_ID()
ORDER BY improvement_measure DESC;
```
