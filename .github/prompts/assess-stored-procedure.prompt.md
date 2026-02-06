---
agent: "agent"
tools: ["search/codebase", "edit/editFiles", "read/problems"]
description: "Assess a SQL Server stored procedure for performance anti-patterns, missing error handling, naming convention violations, and security issues. Produces a diagnostic assessment report — does NOT produce optimized code."
---

# Assess Stored Procedure

Perform a comprehensive performance assessment of the following stored procedure and produce a diagnostic report.

## Stored Procedure to Assess

${selection}

## Output Destination

Save the assessment report as a **Markdown file** in the `samples/queries/assessment/` folder.

### File Naming Convention

- Derive the output filename from the source procedure filename: strip `.sql` and append `-assessment.md`.
- Example: `usp_GetCustomerOrders.sql` → `samples/queries/assessment/usp_GetCustomerOrders-assessment.md`
- If the source filename cannot be determined, derive it from the procedure name (e.g., `usp_ProcedureName-assessment.md`).

## Assessment Areas

### 1. Performance Anti-Patterns
Check for:
- [ ] Missing `SET NOCOUNT ON`
- [ ] `SELECT *` instead of explicit column lists
- [ ] Cursor-based or WHILE loop row-by-row processing
- [ ] Scalar UDF calls in SELECT or WHERE clauses
- [ ] Non-SARGable WHERE predicates (functions on indexed columns)
- [ ] Implicit data type conversions in JOIN or WHERE conditions
- [ ] Unnecessary DISTINCT or ORDER BY in subqueries
- [ ] Parameter sniffing vulnerability (variable parameter distributions)

### 2. Error Handling
Check for:
- [ ] Missing `TRY...CATCH` block
- [ ] Missing `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` for DML operations
- [ ] Missing `SET XACT_ABORT ON` for consistent transaction behavior
- [ ] Missing meaningful error messages via `THROW` or `RAISERROR`

### 3. Code Quality
Check for:
- [ ] Procedure name follows `usp_` PascalCase convention
- [ ] Parameters use `@camelCase` naming
- [ ] Missing header comment block with description, parameters, return values
- [ ] Inconsistent keyword casing or indentation
- [ ] Missing table aliases
- [ ] Implicit comma joins

### 4. Security
Check for:
- [ ] Dynamic SQL built with string concatenation (SQL injection risk)
- [ ] Hardcoded credentials or connection strings
- [ ] Missing parameter validation

## Output Format

Write the assessment report as a Markdown file. **Save this file to `samples/queries/assessment/` using the editFiles tool. Do NOT just display the output inline — the file must be created on disk.**

**Important:** This is an assessment report only. Do NOT include rewritten or optimized code. Describe the issues and recommend fixes, but leave implementation to the `@sql-performance-tuner` agent.

````markdown
# Stored Procedure Assessment: [Procedure Name]

> **Source File:** `samples/stored-procedures/before/[source-filename].sql`
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
- **Category**: Performance / Error Handling / Code Quality / Security
- **Location**: Line [number] — `[code snippet]`
- **Problem**: [Description of the anti-pattern]
- **Impact**: [Expected performance or security consequence]
- **Recommendation**: [What should be done to fix it — described, not implemented]

*(Repeat for each issue found)*

---

## Index Recommendations

Describe which indexes would benefit this procedure's query patterns:

| Table | Recommended Index | Key Columns | Include Columns | Benefit |
|-------|------------------|-------------|-----------------|---------|
| [Table] | `IX_Table_Columns` | col1, col2 | col3, col4 | [Scan → Seek, etc.] |

---

## Verification Guidance

```sql
-- Run these commands before and after applying fixes to measure improvement
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

EXEC [procedure_name] @param1 = value1;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## Next Steps

1. Run `@sql-performance-tuner` agent to implement the fixes identified in this assessment.
2. Deploy recommended indexes in a non-production environment first.
3. Compare `SET STATISTICS IO/TIME` output before and after optimization.
4. Review execution plan with `SET SHOWPLAN_XML ON` to verify index seeks replace scans.
````

Apply the T-SQL conventions from the project's copilot-instructions.md.
