---
agent: "agent"
tools: ["search/codebase", "edit/editFiles", "read/problems"]
description: "Assess a SQL Server view for performance anti-patterns, nested view dependencies, indexed view candidacy, and code quality issues. Produces a diagnostic assessment report — does NOT produce optimized code."
---

# Assess View

Perform a comprehensive performance assessment of the following SQL Server view and produce a diagnostic report.

## View to Assess

${selection}

## Output Destination

Save the assessment report as a **Markdown file** in the `samples/queries/assessment/` folder.

### File Naming Convention

- Derive the output filename from the source view filename: strip `.sql` and append `-assessment.md`.
- Example: `vw_CustomerOrderSummary.sql` → `samples/queries/assessment/vw_CustomerOrderSummary-assessment.md`
- If the source filename cannot be determined, derive it from the view name (e.g., `vw_ViewName-assessment.md`).

## Assessment Areas

### 1. Performance Anti-Patterns
Check for:
- [ ] `SELECT *` instead of explicit column lists
- [ ] Scalar subqueries in the SELECT list (N+1 pattern)
- [ ] Correlated subqueries that could be JOINs with aggregation
- [ ] Non-SARGable predicates (functions on indexed columns)
- [ ] Unnecessary DISTINCT masking duplicate join results
- [ ] String concatenation on indexed columns preventing index usage
- [ ] Implicit data type conversions

### 2. View Architecture
Evaluate:
- [ ] Nested view references (view depending on another view — "view explosion")
- [ ] Could nested views be inlined for better optimizer access?
- [ ] Is the view overly complex and should be broken into simpler composable views?

### 3. Indexed View Candidacy
Evaluate whether the view is a good candidate for an indexed (materialized) view:
- [ ] Uses `WITH SCHEMABINDING`?
- [ ] Contains non-deterministic functions (`GETDATE()`, `NEWID()`)?
- [ ] Contains subqueries, UNION, EXCEPT, INTERSECT?
- [ ] Contains outer joins (only INNER JOIN allowed)?
- [ ] GROUP BY present → includes `COUNT_BIG(*)`?
- [ ] All referenced tables owned by `dbo`?
- Provide a clear **Yes / No** verdict with reasoning.

### 4. Code Quality
Check for:
- [ ] View name follows `vw_` PascalCase convention
- [ ] Inconsistent keyword casing or indentation
- [ ] Missing table aliases
- [ ] Implicit comma joins
- [ ] Non-descriptive column aliases

## Output Format

Write the assessment report as a Markdown file. **Save this file to `samples/queries/assessment/` using the editFiles tool. Do NOT just display the output inline — the file must be created on disk.**

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
| Indexed View Candidate | Yes / No                         |

---

## Issues Found

### Issue 1: [Title]
- **Severity**: Critical / High / Medium / Low
- **Category**: Performance / View Architecture / Code Quality
- **Location**: Line [number] — `[code snippet]`
- **Problem**: [Description of the anti-pattern]
- **Impact**: [Expected performance consequence]
- **Recommendation**: [What should be done to fix it — described, not implemented]

*(Repeat for each issue found)*

---

## Indexed View Candidacy

**Verdict:** [Yes / No]

| Requirement                          | Met? | Notes |
|--------------------------------------|------|-------|
| WITH SCHEMABINDING                   | ✅/❌ | [note] |
| No non-deterministic functions       | ✅/❌ | [note] |
| No subqueries/UNION/EXCEPT           | ✅/❌ | [note] |
| INNER JOIN only (no outer joins)     | ✅/❌ | [note] |
| COUNT_BIG(*) with GROUP BY           | ✅/❌ | [note] |
| All tables owned by dbo              | ✅/❌ | [note] |

---

## Index Recommendations

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| [Table] | `IX_Table_Columns` | col1, col2 | col3, col4 | [Scan → Seek, etc.] |

---

## Verification Guidance

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT TOP 100 * FROM [view_name];

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## Next Steps

1. Run `@sql-performance-tuner` agent to implement the fixes identified in this assessment.
2. Deploy recommended indexes in a non-production environment first.
3. If indexed view candidate: implement WITH SCHEMABINDING and create unique clustered index.
4. Compare `SET STATISTICS IO/TIME` output before and after optimization.
````

Apply the T-SQL conventions from the project's copilot-instructions.md.
Follow the view development standards from `.github/instructions/sql-views.instructions.md`.
