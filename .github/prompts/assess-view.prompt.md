---
agent: "SQL Assessment"
tools: ["edit/editFiles", "read/problems", "read/readFile"]
description: "Assess a SQL Server view for performance anti-patterns, architectural issues, indexed view candidacy, and code quality. Produces a diagnostic assessment report — does NOT produce optimized code."
---

# Assess View

Perform a comprehensive performance assessment of the following SQL Server view and produce a diagnostic report.

## View to Assess

${selection}

## Output Destination

Save the assessment report as a **Markdown file** in the `samples/views/assessment/` folder.

### File Naming Convention

- Derive the output filename from the source view filename: strip `.sql` and append `-assessment.md`.
- Example: `vw_CustomerOrderSummary.sql` → `samples/views/assessment/vw_CustomerOrderSummary-assessment.md`
- If the source filename cannot be determined, derive it from the view name (e.g., `vw_ViewName-assessment.md`).

## Assessment Areas

Reference the `sql-anti-patterns` skill for the complete anti-pattern catalog with severity definitions and before/after examples. Reference the `sql-indexing-patterns` skill for index design patterns and column ordering rules.

### 1. Performance Anti-Patterns
Check for:
- [ ] `SELECT *` instead of explicit column lists
- [ ] Scalar subqueries in the SELECT list (N+1 pattern)
- [ ] Non-SARGable predicates — functions on indexed columns (`YEAR()`, `MONTH()`, `CONVERT()`, `ISNULL()`)
- [ ] Implicit data type conversions in JOIN or WHERE conditions
- [ ] Unnecessary DISTINCT masking duplicate join results
- [ ] Correlated subqueries that could be replaced with JOINs or CTEs
- [ ] Redundant table scans across multiple subqueries

### 2. View Architecture
Check for:
- [ ] Nested views (view references another view) — complicates optimization
- [ ] Excessive columns (kitchen-sink view) — wasteful for most queries
- [ ] Mixing aggregation levels (detail + summary in one view)
- [ ] UNION with incompatible aggregation levels
- [ ] Redundant or unused joins (joined tables whose columns are never referenced)

### 3. Indexed View Candidacy
Evaluate whether the view is a good candidate for an indexed (materialized) view:
- [ ] Missing `WITH SCHEMABINDING` — required for indexed views
- [ ] Uses `SELECT *` — incompatible with schema binding
- [ ] Contains non-deterministic functions (`GETDATE()`, `NEWID()`) — prevents indexing
- [ ] Contains subqueries — not supported in indexed views
- [ ] Contains `UNION`, `INTERSECT`, `EXCEPT` — not supported in indexed views
- [ ] Contains `DISTINCT`, `HAVING`, `TOP` — not supported in indexed views
- [ ] Has `COUNT_BIG(*)` for aggregation — required for indexed aggregate views

### 4. Code Quality
Check for:
- [ ] View name follows `vw_` PascalCase convention
- [ ] Missing header comment block with description and dependencies
- [ ] Inconsistent keyword casing or indentation
- [ ] Missing table aliases
- [ ] Implicit comma joins instead of explicit `JOIN` syntax

## Output Format

Write the assessment report as a Markdown file. **Save this file to `samples/views/assessment/` using the editFiles tool. Do NOT just display the output inline — the file must be created on disk.**

**Important:** This is an assessment report only. Do NOT include rewritten or optimized view code. Describe the issues and recommend fixes, but leave implementation to the `@sql-performance-tuner` agent.

````markdown
# View Assessment: [View Name]

> **Source File:** `samples/views/before/[source-filename].sql`
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

## Issues Found

### Issue 1: [Title]
- **Severity**: Critical / High / Medium / Low
- **Category**: Performance / View Architecture / Indexed View / Code Quality
- **Location**: Line [number] — `[code snippet]`
- **Problem**: [Description of the anti-pattern]
- **Impact**: [Expected performance or architectural consequence]
- **Recommendation**: [What should be done to fix it — described, not implemented]

*(Repeat for each issue found)*

---

## Indexed View Candidacy

| Criteria | Status | Notes |
|----------|--------|-------|
| WITH SCHEMABINDING | Present / Missing | [details] |
| Deterministic functions only | Yes / No | [details] |
| No subqueries | Yes / No | [details] |
| No UNION/DISTINCT/TOP | Yes / No | [details] |
| Has COUNT_BIG(*) | Yes / No | [required for aggregate indexed views] |
| **Overall Candidacy** | Eligible / Not Eligible | [summary] |

---

## Recommended Indexes

Describe which indexes would benefit this view's query patterns:

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| [Table] | `IX_Table_Columns` | col1, col2 | col3, col4 | [Scan → Seek, etc.] |

---

## Verification Guidance

```sql
-- Run these commands before and after applying fixes to measure improvement
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT * FROM [view_name];

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## Next Steps

1. Run `@sql-performance-tuner` agent to implement the fixes identified in this assessment. The optimized code will be saved to `samples/views/after/`.
2. Deploy recommended indexes in a non-production environment first.
3. Compare `SET STATISTICS IO/TIME` output before and after optimization.
4. Review execution plan with `SET SHOWPLAN_XML ON` to verify index seeks replace scans.
5. If eligible, consider creating an indexed view with `CREATE UNIQUE CLUSTERED INDEX` for frequently queried aggregation patterns.
````

Apply the T-SQL conventions from the project's copilot-instructions.md.