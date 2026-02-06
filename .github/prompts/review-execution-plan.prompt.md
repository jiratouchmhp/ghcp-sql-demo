---
agent: "agent"
tools: ["search/codebase", "edit/editFiles", "read/problems"]
description: "Analyze SQL Server execution plan output (XML or text) to identify expensive operators, missing indexes, and implicit conversions. Produces a diagnostic assessment report — does NOT produce optimized code."
---

# Review Execution Plan

Analyze the following SQL Server execution plan and provide optimization recommendations.

## Execution Plan Data

${selection}

## Output Destination

Save the execution plan analysis as a **Markdown file** in the `samples/queries/assessment/` folder.

### File Naming Convention

- If a source query file can be identified, derive filename: strip `.sql` and append `-execution-plan-assessment.md`.
- Example: `slow-query-01-reporting.sql` → `slow-query-01-reporting-execution-plan-assessment.md`
- If the source cannot be determined, use `execution-plan-assessment-YYYY-MM-DD.md` with the current date.

## Analysis Framework

### 1. Costly Operators
Identify and rank the most expensive operators:
- **Table Scan**: No usable index exists → recommend creating one
- **Clustered Index Scan**: Full index read → check for non-SARGable predicates
- **Key Lookup**: Index doesn't cover all columns → recommend INCLUDE columns
- **Hash Match (Join)**: Missing index on join column → recommend index
- **Sort**: No pre-sorted data available → recommend indexed ORDER BY columns
- **Nested Loop + Scan**: Inner table scan for each outer row → recommend index on inner table
- **Parallelism (Repartition Streams)**: Check if DOP is appropriate

### 2. Warnings & Alerts
Flag any execution plan warnings:
- **Missing Index hint**: SQL Server's own suggestion
- **Implicit Conversion**: Data type mismatch in JOIN or WHERE (performance killer)
- **Residual Predicates**: Predicate evaluated after seek (should be in seek key)
- **Row Estimate Mismatch**: Estimated vs actual row counts differ significantly (stale stats?)
- **Memory Grant Warning**: Sort or Hash spilling to tempdb

### 3. Data Flow Analysis
- Where does most of the cost accumulate?
- Are row counts as expected at each operator?
- Is parallelism being used effectively?
- Are there unnecessary operations (e.g., Sort when data is already ordered)?

## Output Format

Write the execution plan analysis as a Markdown file. **Save this file to `samples/queries/assessment/` using the editFiles tool. Do NOT just display the output inline — the file must be created on disk.**

**Important:** This is an assessment report only. Do NOT include rewritten or optimized query code. Describe the findings and recommend actions, but leave implementation to the `@sql-performance-tuner` agent.

````markdown
# Execution Plan Analysis

> **Source:** `[Source query or procedure name, if known]`
> **Assessed On:** [Current Date]
> **Database:** ECommerceDemo (SQL Server 2019/2022)

---

## Summary

| Metric                    | Value                          |
|--------------------------|--------------------------------|
| Total Cost Centers        | [count]                        |
| Warnings Detected         | [count]                        |
| Indexes Recommended       | [count]                        |
| Overall Risk Rating       | Critical / High / Medium / Low |

---

## Top 3 Cost Centers

1. **[Operator]** — [X]% of total cost — [Recommendation]
2. **[Operator]** — [X]% of total cost — [Recommendation]
3. **[Operator]** — [X]% of total cost — [Recommendation]

---

## Warnings Detected

- **[Warning type]**: [Description and fix]

---

## Recommended Optimizations

1. [Action item with CREATE INDEX or query rewrite]
2. [Action item]
3. [Action item]

---

## Index Recommendations

Describe which indexes would address the cost centers and warnings above:

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| [Table] | `IX_Table_Columns` | col1, col2 | col3, col4 | [Scan → Seek, etc.] |

---

## Next Steps

1. Run `@sql-performance-tuner` agent to implement the recommended optimizations.
2. Apply indexes in a non-production environment first.
3. Re-capture execution plan with "Include Actual Execution Plan" enabled.
4. Compare cost — verify cost centers have shifted from scans to seeks.
5. Monitor with `sys.dm_exec_query_stats` to track improvement in production.
````

Reference the project's SQL indexing standards from `.github/instructions/sql-indexing.instructions.md`.
