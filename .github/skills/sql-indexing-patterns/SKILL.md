---
name: sql-indexing-patterns
description: Design and recommend SQL Server indexes including covering indexes, composite key strategies, filtered indexes, columnstore indexes, and index maintenance. Analyze missing index DMVs, fragmentation, and SARGability. Provides index naming conventions, column ordering rules, and redundancy detection.
---

# SQL Server Indexing Patterns

This skill helps design optimal indexing strategies and analyze index usage for SQL Server workloads.

## When to Use

- Recommending indexes for slow queries
- Reviewing existing index strategies
- Analyzing missing index DMV output
- Designing indexes for new tables or features
- Checking index fragmentation and maintenance needs

## Index Types

| Type | Best For | Example |
|------|----------|---------|
| **Covering** | Queries selecting specific columns beyond the key | `IX_Orders_Status INCLUDE (total_amount)` |
| **Composite** | Multi-column WHERE/JOIN predicates | `IX_Sales_Region_Date (region, sale_date)` |
| **Filtered** | Queries always filtering on a fixed predicate | `WHERE is_active = 1` |
| **Columnstore** | Analytics, aggregation, data warehouse queries | `CCI_SalesHistory` |

## Column Ordering Rules

1. Equality predicates first (`=`)
2. Range predicates second (`>`, `<`, `BETWEEN`)
3. ORDER BY columns third
4. SELECT-only columns in INCLUDE

## Reference Material

Detailed patterns, maintenance scripts, and missing index DMV queries:

- [Full Indexing Patterns Reference](indexing-patterns.md)
