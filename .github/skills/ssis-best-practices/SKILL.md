---
name: ssis-best-practices
description: Optimize SSIS (SQL Server Integration Services) and ETL packages including Data Flow buffer tuning, Lookup Transform cache strategies (Full Cache vs Partial vs No Cache), OLE DB Destination Fast Load configuration, incremental load patterns (watermark, CDC), error handling with event handlers, and package logging standards.
---

# SSIS / ETL Best Practices

This skill helps optimize SSIS packages and ETL processes for SQL Server environments.

## When to Use

- Reviewing SSIS package designs for performance
- Optimizing Data Flow throughput
- Choosing Lookup Transform cache modes
- Implementing incremental load strategies
- Setting up error handling and logging
- Converting row-by-row ETL to set-based operations

## Key Decision Points

### Lookup Cache Strategy

| Mode | When to Use | Performance |
|------|-------------|-------------|
| **Full Cache** | Reference table fits in memory (< 25%) | Best — preloaded at start |
| **Partial Cache** | Repeated lookups, large reference table | Good — LRU cache |
| **No Cache** | Avoid when possible | Worst — DB query per row |

### Load Strategy

| Pattern | When to Use |
|---------|-------------|
| **Watermark** | Source has reliable `modified_date` column |
| **CDC** | SQL Server Change Data Capture enabled |
| **Hash comparison** | No reliable timestamp, need change detection |
| **Full reload** | Small tables, or when incremental is impractical |

### Destination Configuration

| Setting | Recommended Value |
|---------|-------------------|
| Table Lock | ON |
| Check Constraints | OFF (validate before load) |
| Rows per Batch | 10,000–100,000 |
| Max Insert Commit Size | 0 (all at once) or batch size |

## Detailed Patterns

### 1. Data Flow Optimization

**Buffer Sizing:**
- **DefaultBufferMaxRows**: Start with 10,000, tune based on row width
- **DefaultBufferSize**: Increase to 10 MB (10485760) for wide rows
- **BLOBTempStoragePath**: Point to fast SSD for LOB data spill

**Pipeline Design:**
- Minimize transformations between source and destination
- Remove unused columns early in the pipeline (reduces buffer memory)
- Avoid synchronous blocking transforms (Sort, Aggregate) on large datasets
- Use async transforms where possible (Union All, Merge)

**Parallelism:**
- **MaxConcurrentExecutables**: Set to server CPU count for CPU-bound workloads
- **EngineThreads**: Match to MaxConcurrentExecutables
- Use Balanced Data Distributor for multi-threaded destinations

### 2. Lookup Transform Strategies

| Mode | When to Use | Memory | Performance |
|------|-------------|--------|-------------|
| **Full Cache** | Reference table < 25% available memory | High | Best (preloaded) |
| **Partial Cache** | Repeated lookups, large reference table | Medium | Good (LRU cache) |
| **No Cache** | Large reference table, few lookups | None | Worst (query per row) |

**Full Cache (Recommended Default):**
- Cache entire reference table at pipeline start
- Best for: dimension tables, code lookups, reference data
- Memory: Holds entire dataset in memory
- Tip: Use SQL query (not table) to limit columns loaded

**Partial Cache:**
- Cache recently used values (LRU eviction)
- Best for: Large reference tables with skewed access patterns
- Configure: CacheType = Partial, MaxMemoryUsage = 25-50%
- Monitor: Cache hit ratio should be > 80%

**No Cache (Avoid When Possible):**
- Queries database for EVERY single row
- Only justified for: very large dim tables with random access
- Impact: N queries for N rows (essentially a nested loop join)
- Better alternative: Stage + SQL JOIN

### 3. Destination Configuration

**OLE DB Destination — Fast Load Options:**
- Table Lock: ON (minimizes lock overhead)
- Check Constraints: OFF (validate data before loading)
- Rows per Batch: 10,000–100,000
- Maximum Insert Commit Size: 0 (commit all at once) or batch size
- Keep Identity: As needed
- Keep Nulls: As needed

**SQL Server Destination (Same-Server Only):**
- Uses shared memory (fastest option when available)
- Only works on same server as SSIS runtime
- Enable: Use Bulk Insert, Table Lock, Fire Triggers OFF

**Batch Size Guidelines:**

| Row Width | Recommended Batch Size |
|-----------|----------------------|
| Narrow (< 100 bytes) | 50,000 - 100,000 |
| Medium (100-500 bytes) | 10,000 - 50,000 |
| Wide (> 500 bytes) | 5,000 - 10,000 |
| LOB columns | 1,000 - 5,000 |

### 4. Incremental Load Patterns

**Pattern A: Watermark Column**
```sql
-- Use a high-watermark date column
-- Source query:
SELECT * FROM SourceTable
WHERE modified_date > @LastLoadDate;

-- After successful load, update watermark:
UPDATE ETL_Config SET last_load_date = GETUTCDATE()
WHERE table_name = 'SourceTable';
```

**Pattern B: Change Data Capture (CDC)**
```sql
-- Enable CDC on source table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'Orders',
    @role_name = NULL;

-- Query changes since last LSN
SELECT * FROM cdc.fn_cdc_get_all_changes_dbo_Orders(@from_lsn, @to_lsn, 'all');
```

**Pattern C: Hash Comparison**
```sql
-- Compute hash of source row, compare to existing hash
SELECT *,
    HASHBYTES('SHA2_256', 
        CONCAT(col1, '|', col2, '|', col3)
    ) AS row_hash
FROM SourceTable;
```

### 5. Error Handling

**Row-Level Error Routing:**
- Configure each component's Error Output
- Route error rows to error table (not fail package)
- Capture: ErrorCode, ErrorColumn, source data
- Threshold: Fail package if error rows > N%

**Package-Level Event Handlers:**
- OnError: Log full error details, send alert
- OnWarning: Log warnings for review
- OnPostExecute: Log execution statistics per component
- OnTaskFailed: Custom retry logic or escalation

**Transaction Scope:**
- Use TransactionOption = Required for atomic packages
- Supported on Control Flow (not Data Flow internals)
- Use checkpoint files for restartability

### 6. Logging Standards

**Required Log Events:**

| Event | Information Captured |
|-------|---------------------|
| OnPreExecute | Component name, start time |
| OnPostExecute | Component name, end time, rows processed |
| OnError | Error code, description, source component |
| OnWarning | Warning details |
| Package start/end | Duration, status, initiation method |

**Performance Counters to Monitor:**
- Rows read / written per second
- Buffer spools to disk
- BLOB bytes read/written
- Seconds spent in transforms vs destinations
