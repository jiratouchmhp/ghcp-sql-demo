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

## 🎯 Demo Scenarios

| # | Scenario | Assess (Prompt) | Implement (Agent) | Duration |
|---|----------|----------------|-------------------|----------|
| 1 | Stored Procedure — Cursor Elimination | `/assess-stored-procedure` | `@sql-performance-tuner` | ~10 min |
| 2 | Stored Procedure — Security + Performance | `/assess-stored-procedure` | `@sql-code-implementation` | ~10 min |
| 3 | View Performance Analysis | `/assess-view` + `/generate-index-recommendations` | `@sql-performance-tuner` | ~8 min |
| 4 | Slow Query Deep-Dive | `/analyze-slow-query` + `/review-execution-plan` | `@sql-performance-tuner` | ~10 min |
| 5 | SSIS/ETL Optimization | `/assess-ssis-package` | `@ssis-optimizer` | ~12 min |

> 📖 See [docs/DEMO-GUIDE.md](docs/DEMO-GUIDE.md) for the full step-by-step runbook.

## 📁 Project Structure

```
ghcp-demo-sql-tuning/
├── .github/
│   ├── copilot-instructions.md              # Global Copilot project instructions
│   ├── agents/
│   │   ├── sql-performance-tuner.agent.md   # SQL Server perf tuning agent
│   │   ├── ssis-optimizer.agent.md          # SSIS package optimization agent
│   │   └── sql-code-implementation.agent.md # SQL code implementation agent
│   ├── instructions/
│   │   ├── sql-stored-procedures.instructions.md
│   │   ├── sql-views.instructions.md
│   │   ├── sql-indexing.instructions.md
│   │   └── ssis-packages.instructions.md
│   ├── prompts/
│   │   ├── analyze-slow-query.prompt.md
│   │   ├── assess-stored-procedure.prompt.md
│   │   ├── assess-view.prompt.md
│   │   ├── assess-ssis-package.prompt.md
│   │   ├── review-execution-plan.prompt.md
│   │   └── generate-index-recommendations.prompt.md
│   └── skills/
│       ├── sql-anti-patterns/
│       │   ├── SKILL.md                     # Anti-pattern detection skill
│       │   └── anti-patterns.md             # Full anti-pattern catalog
│       ├── sql-indexing-patterns/
│       │   ├── SKILL.md                     # Index design skill
│       │   └── indexing-patterns.md         # Index patterns reference
│       └── ssis-best-practices/
│           ├── SKILL.md                     # SSIS/ETL optimization skill
│           └── ssis-best-practices.md       # ETL best practices reference
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
│   │   └── after/                           # ✅ Optimized (demo output)
│   ├── views/
│   │   ├── before/                          # ❌ Suboptimal (demo input)
│   │   │   ├── vw_CustomerOrderSummary.sql
│   │   │   ├── vw_InventoryStatus.sql
│   │   │   └── vw_SalesDashboard.sql
│   │   └── after/                           # ✅ Optimized (demo output)
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
│       └── after/                           # ✅ Optimized (demo output)
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
git clone https://github.com/your-org/ghcp-demo-sql-tuning.git
cd ghcp-demo-sql-tuning

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

Skills use **progressive disclosure** — Copilot always knows which skills exist (via `name` + `description`), but only loads the full content when your prompt matches. If your query touches multiple topics, Copilot loads multiple skills simultaneously.

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
