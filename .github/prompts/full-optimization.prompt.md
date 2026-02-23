---
agent: "SQL Full Optimizer"
tools: ["agent", "search/codebase", "read/readFile", "edit/editFiles", "edit/createFile"]
description: "Run the full Assess → Implement optimization pipeline in a single invocation using subagents. Produces both a diagnostic assessment report AND optimized production-ready code. The coordinator delegates assessment to @SQL Assessment and implementation to the appropriate specialist agent."
---

# Full SQL Optimization Pipeline

Optimize the following SQL artifact using the full Assess → Implement pipeline.

## Input

${selection}

## Instructions

Execute the complete optimization pipeline for this SQL artifact:

1. **Classify** the artifact type (stored procedure, view, query, or SSIS package) from the code content and file path.

2. **Assess** — Run the `@SQL Assessment` agent as a subagent to produce a diagnostic report identifying all anti-patterns, SARGability issues, missing indexes, and security vulnerabilities. The assessment report must be saved to the appropriate `assessment/` folder.

3. **Implement** — Based on the assessment findings, run the appropriate implementation agent as a subagent:
   - Stored procedures with security issues → `@SQL Code Implementation`
   - Stored procedures (performance focus), views, queries → `@SQL Performance Tuner`
   - SSIS/ETL packages → `@SSIS Optimizer`
   
   The optimized code must be saved to the appropriate `after/` folder.

4. **Summarize** — After both subagents complete, provide a consolidated summary with:
   - Issue count and severity breakdown from the assessment
   - List of optimizations applied by the implementation agent
   - File paths for both the assessment report and optimized code
   - Verification steps using `SET STATISTICS IO/TIME`

## Output

Two files are produced:
- **Assessment report** → `samples/<type>/assessment/<filename>-assessment.md`
- **Optimized code** → `samples/<type>/after/<filename>.sql`
