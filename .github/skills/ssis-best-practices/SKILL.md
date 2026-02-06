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

## Reference Material

Detailed configuration, anti-patterns, and logging standards:

- [Full SSIS Best Practices Reference](ssis-best-practices.md)
