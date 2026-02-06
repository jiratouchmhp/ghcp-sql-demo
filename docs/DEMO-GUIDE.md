# Demo Guide — SQL Performance Tuning with GitHub Copilot

> Complete runbook with step-by-step instructions, anti-pattern details, and talking points for each scenario.

---

## Prerequisites

- **VS Code** with GitHub Copilot extension (Chat + Agent mode enabled)
- **SQL Server 2019/2022** (or Docker: `mcr.microsoft.com/mssql/server:2022-latest`)
- This repository cloned and opened in VS Code
- Copilot customization files loaded (automatic when workspace opens)

### Quick Database Setup

```bash
# Option 1: Docker
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=YourStr0ng!Pass" \
  -p 1433:1433 --name sqlserver -d mcr.microsoft.com/mssql/server:2022-latest

# Then run the setup scripts:
sqlcmd -S localhost -U sa -P "YourStr0ng!Pass" -i samples/database-setup/01-create-database.sql
sqlcmd -S localhost -U sa -P "YourStr0ng!Pass" -i samples/database-setup/02-seed-data.sql
```

> **Note:** A live database is optional. The demo works with Copilot Chat analyzing static SQL files.

---

## Demo Workflow

Each scenario follows a consistent **Assess → Implement** workflow:

1. **Assess** — Run a prompt file (`/assess-*` or `/analyze-*`) to generate a diagnostic report identifying anti-patterns, severity ratings, and recommendations. Assessment reports are saved to the `assessment/` folder. Prompts **do NOT produce optimized code**.
2. **Implement** — Use a custom agent (`@sql-performance-tuner`, `@sql-code-implementation`, or `@ssis-optimizer`) to produce the optimized, production-ready code based on the assessment. Agents save output to the `after/` folder.

---

## Demo Flow Overview

| # | Scenario | Duration | File | Step 1: Assess | Step 2: Implement |
|---|----------|----------|------|---------------|-------------------|
| 1 | Stored Procedure — Cursor Elimination | 10 min | `usp_GetCustomerOrders.sql` | `/assess-stored-procedure` | `@sql-performance-tuner` |
| 2 | Stored Procedure — Security + Performance | 10 min | `usp_GenerateSalesReport.sql` | `/assess-stored-procedure` | `@sql-code-implementation` |
| 3 | View Performance Analysis | 8 min | `vw_CustomerOrderSummary.sql` | `/assess-view` | `@sql-performance-tuner` |
| 4 | Slow Query Deep-Dive | 8 min | `slow-query-02-aggregation.sql` | `/analyze-slow-query` + `/review-execution-plan` | `@sql-performance-tuner` |
| 5 | SSIS/ETL Optimization | 12 min | `ETL_DataWarehouseRefresh.dtsx.sql` | `/assess-ssis-package` | `@ssis-optimizer` |

**Total estimated time: ~50 minutes** (adjust by skipping scenarios)

---

## Scenario 1: Stored Procedure — Cursor Elimination

> **Objective:** Show how Copilot first assesses anti-patterns in a stored procedure, then rewrites it as optimized set-based operations.

**File:** `samples/stored-procedures/before/usp_GetCustomerOrders.sql`

### Anti-Patterns Present

| # | Anti-Pattern | Severity | Line Ref |
|---|-------------|----------|----------|
| 1 | `SELECT *` | High | Line 27 |
| 2 | CURSOR for row iteration | Critical | Lines 32-48 |
| 3 | `CONVERT()` on date column (non-SARGable) | Critical | Line 28 |
| 4 | Leading wildcard `LIKE '%...'` | High | Line 29 |
| 5 | Scalar subqueries in SELECT | High | Lines 53-63 |
| 6 | Missing `SET NOCOUNT ON` | Low | Line 17 |
| 7 | No `TRY/CATCH` error handling | Medium | Throughout |

### Step 1 — Assess (Prompt File)

Open the file in VS Code, then run the assessment prompt:
```
/assess-stored-procedure
```

> **Talking Point:** "The assessment prompt generates a structured diagnostic report — anti-patterns ranked by severity, performance impact estimates, and index recommendations. It does NOT produce optimized code yet."

- Review the generated assessment report in `samples/queries/assessment/`
- Walk through the identified issues with the audience

### Step 2 — Implement (Custom Agent)

Now use the agent to produce the optimized version based on the assessment:
```
@sql-performance-tuner Based on the assessment report, implement the optimized
version of this stored procedure. Fix all identified anti-patterns and save
to the after/ folder.
```

> **Talking Point:** "The agent takes the assessment findings and produces production-ready code — cursor replaced with set-based operations, scalar subqueries replaced with JOINs, proper error handling added."

- Review the optimized output
- Save to `samples/stored-procedures/after/usp_GetCustomerOrders.sql`

### Expected Agent Output
1. Complete rewritten procedure using:
   - `CROSS APPLY` or `LEFT JOIN` replacing scalar subqueries
   - Direct aggregation replacing the cursor loop
   - Date range predicate replacing `CONVERT()`
   - `SET NOCOUNT ON` and `TRY/CATCH` added
2. Index recommendations for `Orders(order_date, customer_id)` and `OrderItems(order_id)`

### Talking Points
- "This is the two-step workflow: assess first, implement second — just like a real code review process"
- "The instruction file for stored procedures automatically guided Copilot to include `SET NOCOUNT ON` and `TRY/CATCH`"
- "The anti-pattern skill reference gave Copilot the severity framework to prioritize fixes"

---

## Scenario 2: Stored Procedure — Security + Performance

> **Objective:** Demonstrate the assess-then-implement workflow for a procedure with both security AND performance issues.

**File:** `samples/stored-procedures/before/usp_GenerateSalesReport.sql`

### Anti-Patterns Present

| # | Anti-Pattern | Category |
|---|-------------|----------|
| 1 | SQL injection in dynamic ORDER BY | Security (Critical) |
| 2 | Load-then-delete instead of WHERE | Performance (High) |
| 3 | WHILE loop for monthly aggregation | Performance (Critical) |
| 4 | `YEAR()`/`MONTH()` on columns (non-SARGable) | Performance (Critical) |
| 5 | `DISTINCT` masking bad joins | Performance (Medium) |
| 6 | Temp tables without cleanup | Code Quality (Low) |

### Step 1 — Assess (Prompt File)

```
/assess-stored-procedure
```

> **Talking Point:** "Notice the assessment catches both security AND performance issues — the SQL injection risk in the dynamic ORDER BY is flagged as Critical alongside the WHILE loop performance problem."

- Review the assessment report — highlight the SQL injection finding
- Point out severity ratings across different categories

### Step 2 — Implement (Custom Agent)

Use the code implementation agent (best for mixed security + performance fixes):
```
@sql-code-implementation Based on the assessment report, implement a
production-ready version of this procedure. Fix all security vulnerabilities
and performance anti-patterns identified.
```

> **Talking Point:** "We use the Code Implementation agent here because it specializes in security fixes alongside performance — it replaces the dynamic SQL injection with `sp_executesql` parameterization."

### Key Fixes to Demonstrate
- WHILE loop for monthly aggregation → Single `GROUP BY` with `DATEPART`
- Delete-filter approach → `WHERE` clause at source
- `SELECT *` into temp tables → Explicit columns
- Dynamic SQL injection → `sp_executesql` with validation

---

## Scenario 3: View Performance Analysis

> **Objective:** Assess view anti-patterns first, then use an agent to produce the optimized view with indexed view recommendations.

**File:** `samples/views/before/vw_CustomerOrderSummary.sql`
(Also consider showing `samples/views/before/vw_SalesDashboard.sql`)

### Anti-Patterns Present

| View | Anti-Patterns |
|------|--------------|
| `vw_CustomerOrderSummary` | 7 scalar subqueries, nested view reference, `DISTINCT`, concatenation in columns |
| `vw_SalesDashboard` | Functions on `GROUP BY` columns, 4 correlated subqueries, no schema binding |

### Step 1 — Assess (Prompt File)

```
/assess-view
```

> **Talking Point:** "The view assessment identifies SEVEN scalar subqueries — for 50K customers, each subquery scans the Orders table once per customer row. That's 350K+ scans just from subqueries."

- Review the assessment report
- Optionally generate index recommendations:
  ```
  /generate-index-recommendations
  ```

### Step 2 — Implement (Custom Agent)

```
@sql-performance-tuner Based on the assessment report, implement the optimized
version of this view. Collapse scalar subqueries into JOINs and recommend
indexed view candidates.
```

> **Talking Point:** "Copilot collapses all seven subqueries into a single LEFT JOIN with GROUP BY — the exact pattern a senior DBA would recommend."

### Key Fixes
- 7+ scalar subqueries → Single `LEFT JOIN` with aggregation
- Nested view dependency → Inline the joins
- `DISTINCT` masking duplicates → Fix the join logic
- Consider indexed view with `SCHEMABINDING`

### Talking Points
- "The assessment identified the problem; the agent produced the fix — clean separation of concerns"
- "For the dashboard view, Copilot recommends materialized/indexed views with `SCHEMABINDING` for the most-queried columns"

---

## Scenario 4: Slow Query Deep-Dive

> **Objective:** Assess a complex query with correlated subqueries, then implement the optimized CTE/window function version.

**File:** `samples/queries/before/slow-query-02-aggregation.sql`

### Anti-Patterns Present
- 13 correlated subqueries against Orders table
- Repeated `DATEDIFF` calculations
- `CASE` with 5 branches, each containing its own correlated subquery
- `ORDER BY` on a correlated subquery result

### Step 1 — Assess (Prompt Files)

Run both assessment prompts:
```
/analyze-slow-query
```
```
/review-execution-plan
```

> **Talking Point:** "This customer segmentation query has 13+ correlated subqueries, each scanning the Orders table. For 50K customers, that's 650K+ scans! The execution plan review confirms massive table scan operators."

- Review both assessment reports
- Highlight the 13× scan multiplier

### Step 2 — Implement (Custom Agent)

```
@sql-performance-tuner Based on the assessment report, rewrite this query
using CTEs and window functions. Target a single scan of the Orders table.
```

### Expected Transformation
```
BEFORE: 13 correlated subqueries  →  13 × N table scans
AFTER:  1-2 CTEs with pre-aggregated data  →  1-2 table scans
```

### Expected Improvement
- Before: ~13 full table scans of Orders per customer
- After: 1-2 scans with hash/merge joins
- Estimated improvement: **50-100x faster**

### Talking Points
- "This is the kind of query that works fine in dev with 100 rows but kills production with 50,000 customers"
- "The assessment identified the problem quantitatively; the agent rewrites it using a CTE that aggregates once — going from quadratic to linear complexity"
- "The window function `LAG()` replaces the 'previous month' correlated subquery elegantly"

---

## Scenario 5: SSIS/ETL Optimization

> **Objective:** Assess an SSIS package for ETL anti-patterns, then use the SSIS agent to produce the optimized set-based version.

**File:** `samples/ssis/before/ETL_DataWarehouseRefresh.dtsx.sql`

### Anti-Patterns Present

| Step | Anti-Pattern | Impact |
|------|-------------|--------|
| DimCustomer | Row-by-row SCD2 via cursor | N queries for N customers |
| DimProduct | Same cursor pattern | N queries for N products |
| FactSales | Cursor over 500K rows | 500K individual INSERTs |
| All Steps | No-cache lookups | DB hit per row |
| Package | Full delete + reload | No incremental capability |
| Package | No error handling | Partial data on failure |

### Step 1 — Assess (Prompt File)

```
/assess-ssis-package
```

> **Talking Point:** "The assessment identifies three nested cursors processing dimension and fact loads row-by-row — the classic 'SSIS but actually worse' anti-pattern. It flags No Cache lookups and missing error handling."

- Review the assessment report
- Highlight the row-by-row vs. set-based comparison

### Step 2 — Implement (Custom Agent)

```
@ssis-optimizer Based on the assessment report, implement the optimized ETL
using set-based operations, MERGE for SCD Type 2, and proper error handling.
```

> **Talking Point:** "The SSIS agent produces the full optimized version with MERGE statements, transaction boundaries, and checkpoint/restart capability — taking this from 3-5 hours down to under 30 minutes."

### Expected Improvement

| Operation | Before | After |
|-----------|--------|-------|
| DimCustomer (50K rows) | ~20 min | ~5 sec |
| DimProduct (100 rows) | ~2 min | < 1 sec |
| FactSales (500K rows) | ~3 hours | ~30 sec |

### Talking Points
- "This is the #1 SSIS anti-pattern I see in the field — using SSIS like a scripting language instead of a set-based engine"
- "The assessment caught it; the agent fixed it with `MERGE` — a single statement that handles inserts, updates, and version tracking in one pass"
- "Copilot's SSIS instruction file taught it about Full Cache vs No Cache lookups, so it correctly recommends Full Cache mode"

---

## Bonus: Copilot Customization Walkthrough

> **Objective:** Show the audience how Copilot customization files shape the AI's behavior.

| File | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Global context — schema, conventions, performance-first mindset |
| `.github/agents/sql-performance-tuner.agent.md` | Specialized persona with 5-step workflow |
| `.github/agents/sql-code-implementation.agent.md` | Code implementation & security review agent |
| `.github/agents/ssis-optimizer.agent.md` | SSIS/ETL optimization agent |
| `.github/instructions/sql-stored-procedures.instructions.md` | Auto-applied rules for SP files |
| `.github/prompts/assess-stored-procedure.prompt.md` | Reusable structured prompt |
| `.github/skills/sql-anti-patterns/SKILL.md` | Anti-pattern detection skill |
| `.github/skills/sql-indexing-patterns/SKILL.md` | Index design skill |
| `.github/skills/ssis-best-practices/SKILL.md` | ETL optimization skill |

### Talking Points
- "Think of `copilot-instructions.md` as the 'team style guide' — it tells Copilot our naming conventions, database schema, and standards"
- "Agents are like hiring a specialist — the SQL Performance Tuner has a different workflow than the Code Implementation agent"
- "Instruction files are the magic — they're auto-applied based on file path, so when you open a stored procedure file, Copilot already knows the rules"
- "Prompt files are reusable commands — like having a senior DBA's review checklist that any team member can run"

---

## Tips for Live Demo

1. **Show the anti-pattern comments first** — Let the audience read the intentional issues before asking Copilot to analyze
2. **Use the custom agents** — Demonstrate `@sql-performance-tuner`, `@ssis-optimizer`, and `@sql-code-implementation` switching between personas
3. **Use prompt files** — Show how `/assess-stored-procedure` gives a consistent, structured output
4. **Save "after" files** — Save optimized versions to the `after/` directories for side-by-side comparison
5. **Discuss the Copilot customization files** — Show how `.github/copilot-instructions.md`, agents, instructions, and prompts shape Copilot's behavior

---

## Cleanup

```bash
# Remove the Docker container
docker stop sqlserver && docker rm sqlserver
```
