---
agent: "agent"
tools: ["search/codebase", "edit/editFiles", "read/problems"]
description: "Assess an SSIS package ETL script for performance anti-patterns, row-by-row processing, lookup cache issues, missing error handling, and load strategy problems. Produces a diagnostic assessment report — does NOT produce optimized code."
---

# Assess SSIS Package

Perform a comprehensive performance assessment of the following SSIS package ETL logic and produce a diagnostic report.

## SSIS Script to Assess

${selection}

## Output Destination

Save the assessment report as a **Markdown file** in the `samples/queries/assessment/` folder.

### File Naming Convention

- Derive the output filename from the source SSIS script filename: strip `.dtsx.sql` and append `-assessment.md`.
- Example: `ETL_CustomerDataLoad.dtsx.sql` → `samples/queries/assessment/ETL_CustomerDataLoad-assessment.md`
- If the source filename cannot be determined, use `ssis-assessment-YYYY-MM-DD.md` with the current date.

## Assessment Areas

### 1. Data Flow Efficiency
Check for:
- [ ] Source query selects only needed columns (no `SELECT *`)
- [ ] Filtering done in SQL source query, not SSIS Conditional Split
- [ ] Sorting done in SQL source query, not SSIS Sort transform
- [ ] Aggregation done in SQL source query, not SSIS Aggregate transform
- [ ] Joins done in SQL source query when possible

### 2. Load Strategy
Check for:
- [ ] Row-by-row INSERT instead of bulk insert (OLE DB Fast Load)
- [ ] Missing or inappropriate batch/commit sizes
- [ ] Missing table lock during bulk loads
- [ ] Full truncate-and-reload when incremental load is possible

### 3. Lookup Optimization
Check for:
- [ ] No Cache or Partial Cache used when Full Cache is feasible
- [ ] Lookup query selects unnecessary columns
- [ ] Missing index on lookup reference table join key
- [ ] No Cache mode without justification (volatile real-time data)

### 4. Error Handling
Check for:
- [ ] Missing error output configuration on transforms
- [ ] No error row redirection to staging table
- [ ] Missing OnError event handler with logging
- [ ] Missing row count capture at source and destination

### 5. Package Configuration
Check for:
- [ ] Default buffer sizes not tuned (`DefaultBufferMaxRows`, `DefaultBufferSize`)
- [ ] `MaxConcurrentExecutables` not set
- [ ] Missing connection manager timeout
- [ ] Missing checkpoint for restartability

## Output Format

Write the assessment report as a Markdown file. **Save this file to `samples/queries/assessment/` using the editFiles tool. Do NOT just display the output inline — the file must be created on disk.**

**Important:** This is an assessment report only. Do NOT include rewritten or optimized ETL code. Describe the issues and recommend fixes, but leave implementation to the `@ssis-optimizer` agent.

````markdown
# SSIS Package Assessment: [Package Name]

> **Source File:** `samples/ssis/before/[source-filename].dtsx.sql`
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

## Anti-Pattern Severity Guide

| Anti-Pattern | Severity | Impact |
|-------------|----------|--------|
| Row-by-row processing (RBAR) | **Critical** | 100-1000x slower than set-based |
| Non-cached Lookup | **High** | Network round-trip per row |
| Blocking transforms in Data Flow | **High** | Full dataset buffered before output |
| No error handling | **High** | Silent failures, data loss risk |
| SELECT * in OLE DB Source | **Medium** | Wasted memory, larger buffers |
| Default buffer sizes | **Medium** | Suboptimal throughput |
| Full reload every run | **Medium** | Unnecessary I/O and processing |

---

## Issues Found

### Issue 1: [Title]
- **Severity**: Critical / High / Medium / Low
- **Category**: Data Flow / Load Strategy / Lookup / Error Handling / Configuration
- **Location**: Line [number] — `[code snippet]`
- **Problem**: [Description of the anti-pattern]
- **Impact**: [Expected performance consequence]
- **Recommendation**: [What should be done to fix it — described, not implemented]

*(Repeat for each issue found)*

---

## Package Property Recommendations

| Property | Current | Recommended | Reason |
|----------|---------|-------------|--------|
| DefaultBufferMaxRows | [default] | [value] | [reason] |
| DefaultBufferSize | [default] | [value] | [reason] |
| MaxConcurrentExecutables | [default] | [value] | [reason] |
| EngineThreads | [default] | [value] | [reason] |
| FastLoadMaxInsertCommitSize | [default] | [value] | [reason] |

---

## Verification Guidance

Monitor these metrics before and after optimization:
- Row counts at source and destination
- Execution duration per Data Flow task
- Error row counts and redirection
- Buffer utilization statistics

---

## Next Steps

1. Run `@ssis-optimizer` agent to implement the fixes identified in this assessment.
2. Apply recommended package property settings.
3. Test incremental load patterns in a non-production environment.
4. Verify error handling with intentional bad data rows.
````

Reference the project's SSIS standards from `.github/instructions/ssis-packages.instructions.md`.
