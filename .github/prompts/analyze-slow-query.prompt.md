---
agent: "agent"
tools: ["search/codebase", "edit/editFiles", "read/problems"]
description: "Analyze a slow SQL query to identify performance bottlenecks, non-SARGable predicates, and missing indexes. Produces a diagnostic assessment report — does NOT produce optimized code. Saves the report to the assessment folder."
---

# Analyze Slow Query

Analyze the following SQL query for performance issues and provide a comprehensive optimization report.

## Query to Analyze

${selection}

## Output Destination

Save the assessment report as a **Markdown file** in the `samples/queries/assessment/` folder.

### File Naming Convention

- Derive the output filename from the source query filename.
- Strip the `.sql` extension and append `-assessment.md`.
- Example: `slow-query-01-reporting.sql` → `slow-query-01-reporting-assessment.md`
- If the source filename cannot be determined, use `query-assessment-YYYY-MM-DD.md` with the current date.

### File Path

`samples/queries/assessment/<derived-filename>-assessment.md`

## Analysis Checklist

Evaluate the query against each of these categories:

### 1. SARGability Analysis
- Are all WHERE clause predicates SARGable (index-friendly)?
- Are there functions wrapping indexed columns? (`YEAR()`, `CONVERT()`, `ISNULL()`, `UPPER()`)
- Are there arithmetic operations on columns? (`price + tax > 100`)
- Are there leading-wildcard LIKE patterns? (`LIKE '%search%'`)

### 2. Join Analysis
- Are all joins explicit (`INNER JOIN`, `LEFT JOIN`) vs implicit comma joins?
- Are join conditions on indexed columns?
- Is the join order optimal (smallest result set first)?
- Are there any Cartesian products (missing join conditions)?

### 3. SELECT Clause Analysis
- Is `SELECT *` used instead of explicit columns?
- Are unnecessary columns being fetched?
- Are there scalar UDF calls in the SELECT list?

### 4. Subquery Analysis
- Are there correlated subqueries that could be JOINs?
- Are there subqueries in the SELECT list (N+1 pattern)?
- Could derived tables or CTEs improve readability and performance?

### 5. Aggregation & Sorting
- Are GROUP BY and ORDER BY on indexed columns?
- Is DISTINCT being used to mask duplicate join results?
- Can window functions replace self-joins?

## Output Format

Write the assessment report as a Markdown file using the structure below. **Save this file to `samples/queries/assessment/` using the editFiles tool. Do NOT just display the output inline — the file must be created on disk.**

**Important:** This is an assessment report only. Do NOT include rewritten or optimized query code. Describe the issues and recommend fixes, but leave implementation to the `@sql-performance-tuner` agent.

````markdown
# Assessment Report: [Query Title]

> **Source File:** `samples/queries/before/<source-filename>.sql`
> **Assessed On:** [Current Date]
> **Database:** ECommerceDemo (SQL Server 2019/2022)

---

## Summary

| Metric               | Value                              |
|----------------------|------------------------------------|
| Total Issues Found   | [count]                            |
| Critical             | [count]                            |
| High                 | [count]                            |
| Medium               | [count]                            |
| Low                  | [count]                            |
| Overall Risk Rating  | Critical / High / Medium / Low     |

---

## Performance Issues Found

### Issue 1: [Title]
- **Severity**: Critical / High / Medium / Low
- **Category**: SARGability / Joins / SELECT Clause / Subqueries / Aggregation
- **Problem**: [Description of the anti-pattern]
- **Impact**: [Expected performance effect — e.g., table scan vs index seek]
- **Line(s)**: [Line number(s) in original query]

*(Repeat for each issue found)*

---

## Recommended Indexes

Describe which indexes would benefit this query's patterns:

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| [Table] | `IX_Table_Columns` | col1, col2 | col3, col4 | [Scan → Seek, etc.] |

---

## Performance Verification

```sql
-- Run these commands before and after applying the optimized query
-- to measure the improvement.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- [Original query here for baseline]

-- [Optimized query here for comparison]

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## Next Steps

1. Run `@sql-performance-tuner` agent to implement the fixes and optimized query based on this assessment.
2. Deploy recommended indexes in a non-production environment first.
3. Compare `SET STATISTICS IO/TIME` output before and after optimization.
4. Review execution plan with `SET SHOWPLAN_XML ON` to verify index seeks replace scans.
5. Monitor in production with `sys.dm_exec_query_stats` and `sys.dm_db_index_usage_stats`.
````

Apply the T-SQL conventions from the project's copilot-instructions.md.
