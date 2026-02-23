# 🚀 GitHub Copilot — SQL Performance Tuning & SSIS Optimization Demo

> **A professional demo repository showcasing GitHub Copilot's capabilities for SQL Server performance tuning, stored procedure optimization, view analysis, and SSIS package optimization.**

[![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-Enabled-blue?logo=github)](https://github.com/features/copilot)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019%2F2022-red?logo=microsoftsqlserver)](https://www.microsoft.com/sql-server)
[![SSIS](https://img.shields.io/badge/SSIS-ETL%20Optimization-orange)](https://learn.microsoft.com/sql/integration-services/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📋 Overview

This repository provides a **hands-on demo environment** for demonstrating how GitHub Copilot can assist database professionals with:

| Area | What's Demonstrated |
|------|---------------------|
| **Stored Procedures** | Identifying anti-patterns, rewriting for performance, adding error handling |
| **Views** | Detecting nested views, removing `SELECT *`, recommending indexed views |
| **Query Optimization** | Execution plan analysis, index recommendations, SARGability fixes |
| **SSIS Packages** | ETL data flow tuning, lookup cache strategy, bulk load patterns |
| **Code Review** | Security audit (SQL injection), naming conventions, maintainability |
| **Subagent Orchestration** | Coordinator-worker pattern, parallel multi-perspective review, automated Assess → Implement pipeline |

## 🎯 Demo Scenarios

| # | Scenario | Assess (Prompt) | Implement (Agent) | Duration |
|---|----------|----------------|-------------------|----------|
| 1 | Stored Procedure — Cursor Elimination | `/assess-stored-procedure` | `@sql-performance-tuner` | ~10 min |
| 2 | Stored Procedure — Security + Performance | `/assess-stored-procedure` | `@sql-code-implementation` | ~10 min |
| 3 | View Performance Analysis | `/assess-view` + `/generate-index-recommendations` | `@sql-performance-tuner` | ~8 min |
| 4 | Slow Query Deep-Dive | `/assess-slow-query` + `/review-execution-plan` | `@sql-performance-tuner` | ~10 min |
| 5 | SSIS/ETL Optimization | `/assess-ssis-package` | `@ssis-optimizer` | ~12 min |
| 6 | Subagent Full Optimization Pipeline | `/full-optimization` | `@sql-full-optimizer` (coordinator) | ~10 min |

> 📖 See [docs/DEMO-GUIDE.md](docs/DEMO-GUIDE.md) for the full step-by-step runbook.

### Subagent Bonus Demos

| Prompt | Pattern | What It Shows |
|--------|---------|---------------|
| `/full-optimization` | Coordinator-Worker (sequential) | Single invocation runs `@SQL Assessment` → `@SQL Performance Tuner` as chained subagents |
| `/multi-perspective-review` | Parallel Subagents | Performance + Security reviews run simultaneously, then merge into a prioritized report |

## 📁 Project Structure

```
ghcp-sql-demo/
├── .github/
│   ├── copilot-instructions.md              # Global Copilot project instructions
│   ├── agents/
│   │   ├── sql-assessment.agent.md           # SQL assessment report agent
│   │   ├── sql-performance-tuner.agent.md   # SQL Server perf tuning agent
│   │   ├── ssis-optimizer.agent.md          # SSIS package optimization agent
│   │   ├── sql-code-implementation.agent.md # SQL code implementation agent
│   │   └── sql-full-optimizer.agent.md      # Coordinator agent (subagent orchestration)
│   ├── instructions/
│   │   ├── sql-stored-procedures.instructions.md
│   │   ├── sql-views.instructions.md
│   │   ├── sql-indexing.instructions.md
│   │   └── ssis-packages.instructions.md
│   ├── prompts/
│   │   ├── assess-slow-query.prompt.md
│   │   ├── assess-stored-procedure.prompt.md
│   │   ├── assess-view.prompt.md
│   │   ├── assess-ssis-package.prompt.md
│   │   ├── review-execution-plan.prompt.md
│   │   ├── generate-index-recommendations.prompt.md
│   │   ├── full-optimization.prompt.md          # Subagent: full Assess → Implement pipeline
│   │   └── multi-perspective-review.prompt.md   # Subagent: parallel multi-perspective review
│   └── skills/
│       ├── sql-anti-patterns/
│       │   └── SKILL.md                     # Anti-pattern detection skill (includes full catalog)
│       ├── sql-indexing-patterns/
│       │   └── SKILL.md                     # Index design skill (includes full patterns)
│       └── ssis-best-practices/
│           └── SKILL.md                     # SSIS/ETL optimization skill (includes full reference)
├── samples/
│   ├── database-setup/
│   │   ├── 01-create-database.sql           # Schema creation
│   │   └── 02-seed-data.sql                 # Sample data
│   ├── stored-procedures/
│   │   ├── before/                          # ❌ Suboptimal (demo input)
│   │   │   ├── usp_GenerateSalesReport.sql
│   │   │   ├── usp_GetCustomerOrders.sql
│   │   │   ├── usp_ProcessBatchOrders.sql
│   │   │   └── usp_SearchProducts.sql
│   │   ├── after/                           # ✅ Optimized (demo output)
│   │   └── assessment/                      # 📊 Assessment reports
│   ├── views/
│   │   ├── before/                          # ❌ Suboptimal (demo input)
│   │   │   ├── vw_CustomerOrderSummary.sql
│   │   │   ├── vw_InventoryStatus.sql
│   │   │   └── vw_SalesDashboard.sql
│   │   ├── after/                           # ✅ Optimized (demo output)
│   │   └── assessment/                      # 📊 Assessment reports
│   ├── queries/
│   │   ├── before/                          # ❌ Suboptimal (demo input)
│   │   │   ├── slow-query-01-reporting.sql
│   │   │   ├── slow-query-02-aggregation.sql
│   │   │   └── slow-query-03-joins.sql
│   │   ├── after/                           # ✅ Optimized (demo output)
│   │   └── assessment/                      # 📊 Assessment reports
│   └── ssis/
│       ├── before/                          # ❌ Suboptimal (demo input)
│       │   ├── ETL_CustomerDataLoad.dtsx.sql
│       │   ├── ETL_DataWarehouseRefresh.dtsx.sql
│       │   └── ETL_SalesAggregation.dtsx.sql
│       ├── after/                           # ✅ Optimized (demo output)
│       └── assessment/                      # 📊 Assessment reports
├── docs/
│   ├── DEMO-GUIDE.md                        # Complete demo runbook with scenario details
│   └── ARCHITECTURE.md                      # Database design reference
└── README.md                                # This file
```

## ⚙️ Prerequisites

| Requirement | Details |
|-------------|---------|
| **VS Code** | Version 1.96+ with GitHub Copilot extension |
| **GitHub Copilot** | Active subscription (Individual, Business, or Enterprise) |
| **SQL Server** | 2019 or 2022 (local, Docker, or Azure SQL) — *optional for live demo* |
| **VS Code Extensions** | `ms-mssql.mssql` (SQL Server) — *optional for live connectivity* |

> **Note**: The demo can run entirely with Copilot Chat analyzing static SQL files. A live database connection enhances the demo but is not required.

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/jiratouchmhp/ghcp-sql-demo.git
cd ghcp-sql-demo

# 2. Open in VS Code
code .

# 3. Follow the demo guide
# Open docs/DEMO-GUIDE.md and follow the step-by-step instructions
```

## 🤖 Copilot Customization Files

This project uses the [awesome-copilot](https://github.com/github/awesome-copilot) conventions:

| Type | Location | Purpose |
|------|----------|---------|
| **Global Instructions** | `.github/copilot-instructions.md` | Project-wide context and conventions |
| **Custom Agents** | `.github/agents/*.agent.md` | Specialized AI personas for SQL/SSIS tasks |
| **Instructions** | `.github/instructions/*.instructions.md` | File-pattern-specific coding standards |
| **Prompts** | `.github/prompts/*.prompt.md` | Reusable task-specific prompts (`/command`) |
| **Skills** | `.github/skills/*/SKILL.md` | Bundled reference docs for specialized tasks |

### Agent Skills

This project includes **3 specialized skills** that Copilot loads on-demand based on your prompt:

| Skill | Loads When You Ask About | Location |
|-------|--------------------------|----------|
| **sql-anti-patterns** | Cursors, SELECT *, non-SARGable predicates, scalar subqueries, code smells | `.github/skills/sql-anti-patterns/` |
| **sql-indexing-patterns** | Index recommendations, covering indexes, composite keys, missing index DMVs | `.github/skills/sql-indexing-patterns/` |
| **ssis-best-practices** | ETL optimization, Lookup cache modes, bulk load, incremental load, Data Flow tuning | `.github/skills/ssis-best-practices/` |

Skills use **progressive disclosure** — Copilot always knows which skills exist (via `name` + `description`), but only loads the full content when your prompt matches. Each `SKILL.md` is self-contained with severity definitions, before/after code examples, and detection rules — no secondary files to load. If your query touches multiple topics, Copilot loads multiple skills simultaneously.

### Subagent Orchestration

This project demonstrates the **coordinator-worker subagent pattern** — a coordinator agent delegates phases of the optimization pipeline to specialist agents running as isolated subagents:

| Component | Role | Subagent Pattern |
|-----------|------|------------------|
| `@sql-full-optimizer` | **Coordinator** — orchestrates the pipeline, delegates to workers | Spawns sequential subagents |
| `@sql-assessment` | **Worker** — produces diagnostic assessment reports | Runs as Subagent 1 |
| `@sql-performance-tuner` | **Worker** — produces optimized SQL code | Runs as Subagent 2 |
| `@sql-code-implementation` | **Worker** — fixes security + quality issues | Runs as Subagent 2 (alt) |
| `@ssis-optimizer` | **Worker** — optimizes ETL packages | Runs as Subagent 2 (alt) |

**Key benefits:**
- **One prompt, full lifecycle** — `/full-optimization` runs assessment AND implementation automatically
- **Context isolation** — each subagent gets a clean context window, preventing bloat
- **Parallel review** — `/multi-perspective-review` runs performance and security reviews simultaneously
- **No agent changes needed** — existing specialist agents work both standalone and as subagents

> 📖 See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#subagent-orchestration) for the full orchestration diagrams.

## 📚 Additional Resources

- [VS Code Copilot Customization](https://code.visualstudio.com/docs/copilot/copilot-customization)
- [GitHub Copilot Documentation](https://docs.github.com/copilot)
- [Awesome GitHub Copilot](https://github.com/github/awesome-copilot)
- [SQL Server Performance Tuning](https://learn.microsoft.com/sql/relational-databases/performance/)
- [SSIS Best Practices](https://learn.microsoft.com/sql/integration-services/performance/)

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

> **Built for demonstrating GitHub Copilot's SQL performance tuning capabilities.**
> Inspired by [github/awesome-copilot](https://github.com/github/awesome-copilot).
