---
tools: ["agent", "search/codebase", "read/readFile"]
description: "Run parallel subagents to review a SQL artifact from multiple perspectives — performance, security, and code quality — simultaneously. Synthesizes independent findings into a single prioritized report. Assessment-only: does NOT produce optimized code."
---

# Multi-Perspective SQL Review

Analyze the following SQL artifact through multiple independent review perspectives using parallel subagents.

## Input

${selection}

## Instructions

Run the following review perspectives as **parallel subagents**. Each subagent should approach the code independently without being influenced by other perspectives:

### Perspective 1: Performance Review (Subagent)

> Review this SQL code exclusively for **performance issues**:
> - Non-SARGable predicates and index-unfriendly patterns
> - Cursor/RBAR (Row-By-Agonizing-Row) processing
> - Scalar subqueries and correlated subquery multiplication
> - Missing or suboptimal indexes
> - Table scan risks and join strategy issues
> - Aggregation and sorting inefficiencies
>
> Rate each finding as Critical / High / Medium / Low severity.
> Return a structured list of performance issues with line references.

### Perspective 2: Security & Code Quality Review (Subagent)

> Review this SQL code exclusively for **security vulnerabilities and code quality**:
> - SQL injection risks (dynamic SQL, string concatenation)
> - Permission scope and EXECUTE AS issues
> - Data exposure (SELECT *, sensitive data in results)
> - Hardcoded credentials or connection strings
> - Missing error handling (TRY/CATCH, transaction management)
> - Naming convention violations (usp_, vw_, fn_ prefixes)
> - Missing SET NOCOUNT ON, SET XACT_ABORT ON
> - Code formatting and readability issues
>
> Rate each finding as Critical / High / Medium / Low severity.
> Return a structured list of security and quality issues with line references.

## Synthesis

After all subagents complete, **synthesize** the findings into a single prioritized report:

1. **Merge and deduplicate** — If both perspectives flag the same issue, consolidate it with the higher severity rating.
2. **Prioritize** — Order all findings by severity (Critical → High → Medium → Low).
3. **Cross-cutting insights** — Note any issues that span multiple perspectives (e.g., dynamic SQL is both a security AND performance concern).
4. **Acknowledge strengths** — Call out what the code does well.

## Output Format

Display the synthesized report inline (do NOT save to disk). Use this structure:

```markdown
# Multi-Perspective Review: [Artifact Name]

## Summary

| Perspective | Issues Found | Critical | High | Medium | Low |
|------------|-------------|----------|------|--------|-----|
| Performance | [count] | [n] | [n] | [n] | [n] |
| Security & Code Quality | [count] | [n] | [n] | [n] | [n] |
| **Combined (deduplicated)** | **[count]** | **[n]** | **[n]** | **[n]** | **[n]** |

## Critical & High Priority Findings

### [Issue Title]
- **Severity**: Critical / High
- **Perspectives**: Performance / Security / Both
- **Problem**: [Description]
- **Impact**: [Expected effect]
- **Line(s)**: [Line references]

## Medium & Low Priority Findings

[Similar format, condensed]

## Strengths

- [What the code does well]

## Next Steps

1. Run `/full-optimization` to automatically assess and implement all fixes using the subagent pipeline.
2. Or run `@sql-performance-tuner` / `@sql-code-implementation` manually for targeted fixes.
```

**Important:** This is a review-only prompt. Do NOT produce optimized or rewritten code.
