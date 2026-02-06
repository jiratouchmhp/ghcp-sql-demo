---
description: "SQL Server indexing strategy guidelines covering index types, design patterns, naming conventions, and maintenance recommendations for optimal query performance."
applyTo: "**/*.sql"
---

# SQL Indexing Standards

## Naming Convention

- **Clustered**: `PK_TableName` (typically the primary key)
- **Non-Clustered**: `IX_TableName_Column1_Column2`
- **Unique**: `UQ_TableName_Column`
- **Filtered**: `IX_TableName_Column_FilterDescription`
- **Columnstore**: `CCI_TableName` or `NCCI_TableName_Columns`

## Index Design Principles

### Key Selection
1. **Leading column** = most selective column used in equality predicates (`WHERE col = value`)
2. **Second columns** = columns used in range predicates or additional equality filters
3. **INCLUDE columns** = columns needed in SELECT but not in WHERE (avoids Key Lookups)

### Index Width
- Keep index keys narrow (fewer key columns = more rows per page = better I/O)
- Use INCLUDE for wide columns needed only for covering

### SARGable Predicates (Index-Friendly)

```sql
-- ✅ SARGable — index CAN be used
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
WHERE customer_id = @customerId
WHERE email LIKE 'john%'            -- Leading wildcard is NOT SARGable

-- ❌ Non-SARGable — forces table/index SCAN
WHERE YEAR(order_date) = 2024       -- Function on column
WHERE ISNULL(status, 'Unknown') = 'Active'  -- ISNULL wrapping
WHERE CONVERT(VARCHAR, created_at, 112) = '20240101'
WHERE price + tax > 100             -- Arithmetic on column
WHERE email LIKE '%gmail.com'       -- Leading wildcard
```

## Common Index Patterns

### Pattern 1: Covering Index (Eliminates Key Lookups)
```sql
-- Query: SELECT first_name, last_name, email FROM Customers WHERE city = 'Seattle'
CREATE NONCLUSTERED INDEX IX_Customers_City
ON dbo.Customers (city)
INCLUDE (first_name, last_name, email);
```

### Pattern 2: Composite Index (Multi-Column Filtering)
```sql
-- Query: SELECT ... FROM Orders WHERE customer_id = @id AND status = 'Completed'
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId_Status
ON dbo.Orders (customer_id, status)
INCLUDE (order_date, total_amount);
```

### Pattern 3: Filtered Index (Subset of Rows)
```sql
-- Active products only — smaller index, faster seeks
CREATE NONCLUSTERED INDEX IX_Products_Active_CategoryId
ON dbo.Products (category_id)
INCLUDE (name, price)
WHERE is_active = 1;
```

### Pattern 4: Columnstore Index (Analytical Queries)
```sql
-- For reporting/aggregation workloads on SalesHistory
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_SalesHistory_Reporting
ON dbo.SalesHistory (sale_date, product_id, customer_id, quantity, revenue, profit, region);
```

## Index Maintenance

```sql
-- Check index fragmentation
SELECT
    OBJECT_NAME(ips.object_id) AS table_name,
    i.name AS index_name,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
INNER JOIN sys.indexes AS i
    ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
    AND ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- Rebuild (> 30% fragmentation)
ALTER INDEX IX_IndexName ON dbo.TableName REBUILD;

-- Reorganize (10-30% fragmentation)
ALTER INDEX IX_IndexName ON dbo.TableName REORGANIZE;
```

## Missing Index DMV Query

```sql
-- Find SQL Server's missing index suggestions
SELECT
    ROUND(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans), 0) AS improvement_measure,
    mid.statement AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.user_seeks,
    migs.user_scans
FROM sys.dm_db_missing_index_groups AS mig
INNER JOIN sys.dm_db_missing_index_group_stats AS migs
    ON mig.index_group_handle = migs.group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;
```
