---
name: sql-anti-patterns
description: Identify and fix SQL Server anti-patterns including cursors, SELECT *, non-SARGable predicates, scalar subqueries, implicit type conversions, missing error handling, parameter sniffing issues, and RBAR (Row-By-Agonizing-Row) processing. Provides severity ratings, before/after examples, and performance impact estimates.
---

# SQL Anti-Patterns Detection & Remediation

This skill helps identify common SQL Server performance anti-patterns and provides proven fixes.

## When to Use

- Reviewing stored procedures, views, or queries for performance issues
- Analyzing slow-running SQL code
- Performing SQL code reviews
- Rewriting suboptimal T-SQL patterns

## Severity Levels

| Level | Impact | Action |
|-------|--------|--------|
| **Critical** | >10x performance degradation | Fix immediately |
| **High** | 5-10x performance degradation | Fix before production |
| **Medium** | 2-5x performance degradation | Fix in next sprint |
| **Low** | <2x but measurable | Address when convenient |

## Anti-Pattern Catalog

Detailed catalog with before/after examples for each anti-pattern:

- [Full Anti-Pattern Reference](anti-patterns.md)

## Quick Reference

### Critical Anti-Patterns
1. **Non-SARGable predicates** — Functions on indexed columns force full table scans
2. **Cursor / RBAR processing** — Row-by-row instead of set-based operations
3. **Cartesian products** — Missing or incorrect JOIN predicates

### High Anti-Patterns
4. **SELECT \*** — Unnecessary columns, prevents covering index usage
5. **Scalar subqueries in SELECT** — Execute once per outer row
6. **LIKE with leading wildcard** — Cannot use B-tree index
7. **Implicit type conversion** — Mismatched types force column conversion

### Medium Anti-Patterns
8. **Missing error handling** — No TRY/CATCH, partial execution risk
9. **Unnecessary DISTINCT** — Masks duplicates from bad joins
10. **Parameter sniffing** — First plan may be suboptimal for later values

### Low Anti-Patterns
11. **Missing SET NOCOUNT ON** — Extra network roundtrips
12. **Temp table without cleanup** — Resource leak in long sessions
