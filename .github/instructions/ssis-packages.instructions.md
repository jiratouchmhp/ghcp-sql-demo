---
description: "SSIS (SQL Server Integration Services) package development standards covering ETL design patterns, data flow optimization, lookup strategies, error handling, and performance tuning best practices."
applyTo: "**/ssis/**"
---

# SSIS Package Standards

## ETL Design Principles

### Data Flow Optimization
- **Push operations to SQL**: Move WHERE, JOIN, GROUP BY, ORDER BY to the source query — not SSIS transforms
- **Minimize columns**: SELECT only the columns needed — every column consumes buffer memory
- **Avoid blocking transforms**: Sort and Aggregate in Data Flow block the pipeline. Pre-sort in SQL instead
- **Use buffer tuning**: Adjust `DefaultBufferMaxRows` and `DefaultBufferSize` based on row width

### Lookup Transforms
- **Full Cache** (default, preferred): Pre-loads entire reference table into memory. Best for small-medium reference tables (< 5M rows or < 1 GB)
- **Partial Cache**: Caches recently used values. Use when reference table is very large and query patterns show locality
- **No Cache**: Executes a SQL query for every input row. **Almost never appropriate** — use only for real-time lookups against volatile data

### Destination Components
- **OLE DB Destination with Fast Load**: Preferred for most scenarios
  - `TableLock = True` (minimizes locking overhead)
  - `MaxInsertCommitSize = 500000` (balance between transaction log usage and commit frequency)
  - `FastLoadKeepIdentity = True` (when preserving source identity values)
- **SQL Server Destination**: Faster but only works when SSIS runs on the same machine as SQL Server

## SSIS Anti-Patterns to Avoid

### 1. Row-by-Row Processing (RBAR)
```
❌ BAD: ForEach Loop → Execute SQL Task (one INSERT per row)
✅ GOOD: Data Flow Task → OLE DB Destination (bulk insert)
```

### 2. Non-Cached Lookups
```
❌ BAD: Lookup with No Cache mode on large reference table
✅ GOOD: Lookup with Full Cache mode + indexed reference query
```

### 3. Blocking Transforms in Data Flow
```
❌ BAD: Sort transform in Data Flow (buffers entire dataset)
✅ GOOD: ORDER BY in source SQL query (sorted before entering pipeline)
```

### 4. SELECT * in Source Queries
```
❌ BAD: SELECT * FROM Customers
✅ GOOD: SELECT id, first_name, last_name, email FROM Customers
```

### 5. Missing Error Handling
```
❌ BAD: No error output on transforms, no event handlers
✅ GOOD: Error output → Error staging table + OnError event handler with logging
```

## Package Property Settings

```
MaxConcurrentExecutables: -1          -- Use all available processors
DefaultBufferMaxRows:    100000       -- Tune based on row width
DefaultBufferSize:       104857600    -- 100 MB (max is 100 MB on x86, larger on x64)
EngineThreads:           10           -- Match to available CPU cores
CheckpointUsage:         IfExists     -- Enable restart from last checkpoint
```

## Error Handling Pattern

### Data Flow Error Output
Configure error outputs on all transforms:
- **Redirect Row**: Send failed rows to error staging table
- **Capture**: Error code, error column, source row data
- **Log**: Write error details to package log

### Control Flow Error Handling
Use event handlers at package and task level:
- **OnError**: Log error, send notification, optionally retry
- **OnWarning**: Log warning for monitoring
- **OnPostExecute**: Record execution completion metrics

## Incremental Load Patterns

### Timestamp-Based (Watermark)
```sql
-- Source query with watermark
SELECT id, customer_name, email, updated_at
FROM Customers
WHERE updated_at > ? -- Parameter: last successful load timestamp

-- After successful load, update watermark table:
UPDATE ETL_Watermarks SET last_load_time = GETUTCDATE() WHERE table_name = 'Customers';
```

### Change Data Capture (CDC)
```sql
-- Enable CDC on source table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'Orders',
    @role_name = NULL;

-- Query CDC changes
SELECT * FROM cdc.fn_cdc_get_all_changes_dbo_Orders(@from_lsn, @to_lsn, 'all');
```

## Logging Standards

Every SSIS package should log:
1. **Package start/end** time with duration
2. **Row counts**: Source rows read, rows inserted, rows updated, rows rejected
3. **Error details**: Error message, error code, source row data
4. **Performance**: Data flow execution time, throughput (rows/second)
