---
agent: "agent"
tools: ["search/codebase", "edit/editFiles", "read/problems"]
description: "Analyze query patterns and table schemas to assess index needs, identifying missing indexes, redundant indexes, and covering index opportunities. Produces a diagnostic assessment report — does NOT create index scripts directly."
---

# Generate Index Recommendations

Analyze the following SQL code and table schema to assess index needs and produce a diagnostic report.

## SQL Code / Schema to Analyze

${selection}

## Output Destination

Save the index assessment as a **Markdown file** in the `samples/queries/assessment/` folder.

### File Naming Convention

- Derive the output filename from the source file: strip `.sql` and append `-index-assessment.md`.
- Example: `usp_GetCustomerOrders.sql` → `samples/queries/assessment/usp_GetCustomerOrders-index-assessment.md`
- Example: `slow-query-01-reporting.sql` → `samples/queries/assessment/slow-query-01-reporting-index-assessment.md`
- If the source filename cannot be determined, use `index-assessment-YYYY-MM-DD.md` with the current date.

## Analysis Process

### Step 1: Extract Query Patterns
From the provided SQL code, identify:
- **Equality predicates**: `WHERE column = value` → candidate for index key
- **Range predicates**: `WHERE column > value` → candidate for index key (after equality columns)
- **JOIN conditions**: `ON t1.col = t2.col` → candidate for index key
- **ORDER BY columns**: → candidate for index key (matching sort order)
- **GROUP BY columns**: → candidate for index key
- **SELECT columns**: → candidate for INCLUDE (covering)

### Step 2: Design Index Strategy

For each query or stored procedure, recommend indexes following these rules:

1. **Leading column** = Most selective equality predicate column
2. **Subsequent key columns** = Other equality predicates, then range predicates
3. **INCLUDE columns** = Remaining SELECT columns (for covering)
4. **Filter** = If query always filters on a specific value (e.g., `WHERE is_active = 1`)

### Step 3: Check for Redundancy
- Don't create indexes that overlap with existing ones
- A composite index on (A, B, C) covers queries on (A), (A, B), and (A, B, C)
- Avoid over-indexing (each index costs write performance on INSERT/UPDATE/DELETE)

## Output Format

Write the index assessment as a Markdown file. **Save this file to `samples/queries/assessment/` using the editFiles tool. Do NOT just display the output inline — the file must be created on disk.**

**Important:** This is an assessment report only. Do NOT produce executable index creation scripts. Describe the recommendations and rationale, but leave implementation to the `@sql-performance-tuner` agent.

````markdown
# Index Assessment: [Query/Procedure/View Name]

> **Source File:** `[source file path]`
> **Assessed On:** [Current Date]
> **Database:** ECommerceDemo (SQL Server 2019/2022)

---

## Summary

| Metric                | Value  |
|-----------------------|--------|
| Indexes Recommended   | [count] |
| Redundancy Warnings   | [count] |
| Covering Index Gaps   | [count] |
| Overall Index Health  | Good / Needs Attention / Poor |

---

## Recommended Indexes

### Index 1: [Purpose description]
- **Table**: `dbo.[TableName]`
- **Type**: Non-Clustered / Filtered / Columnstore
- **Key Columns**: `col1, col2`
- **Include Columns**: `col3, col4`
- **Filter** (if applicable): `WHERE is_active = 1`
- **Supports**: [Which query pattern this serves]
- **Converts**: [Table Scan → Index Seek] | [Key Lookup → Covered Query]
- **Estimated Read Improvement**: [X logical reads → Y logical reads]

*(Repeat for each recommended index)*

---

## Index Impact Summary

| Index | Table | Type | Supports | Read Benefit | Write Cost |
|-------|-------|------|----------|-------------|------------|
| `IX_...` | Table | Non-Clustered | Query 1 | High | Low |
| `IX_...` | Table | Filtered | Query 2 | Medium | Minimal |

---

## Redundancy Analysis

- [List any overlapping or redundant indexes detected]
- [Note which existing indexes already partially cover the recommended patterns]

---

## Maintenance Notes

- [Fragmentation monitoring recommendations]
- [Statistics update recommendations]

---

## Next Steps

1. Run `@sql-performance-tuner` agent to implement the recommended indexes.
2. Test in a non-production environment first.
3. Monitor `sys.dm_db_index_usage_stats` after deployment.
4. Review write-heavy tables for over-indexing risk.
````

Follow the project's indexing standards from `.github/instructions/sql-indexing.instructions.md`.
