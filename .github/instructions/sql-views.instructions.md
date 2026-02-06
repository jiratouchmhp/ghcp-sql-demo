---
description: "SQL Server view development standards covering naming, performance considerations, indexed view patterns, and anti-pattern avoidance for the ECommerceDemo database."
applyTo: "**/views/**/*.sql"
---

# SQL View Standards

## Naming Conventions

- Prefix all views with `vw_` followed by PascalCase descriptive name
- Name should describe the data perspective: `vw_CustomerOrderSummary`, `vw_ActiveProducts`
- Avoid generic names like `vw_Data` or `vw_Report`

## Performance Rules

### MUST DO
- List explicit columns (never `SELECT *`)
- Use `SCHEMABINDING` for views that will be indexed or frequently queried
- Keep views shallow — avoid nesting views within views (max 1 level deep)
- Push filtering to the querying statement, not into the view (unless creating a security view)
- Document the purpose of each view in a header comment

### MUST AVOID
- **Nested views**: View A referencing View B referencing View C (cascading performance problems)
- **SELECT ***: Always enumerate columns explicitly
- **Unnecessary DISTINCT**: Fix the root cause (bad joins) instead of masking with DISTINCT
- **ORDER BY in views**: ORDER BY is ignored without TOP — remove it or add TOP
- **Complex calculations**: Move expensive scalar computations to stored procedures
- **Too many joins**: If a view joins 6+ tables, consider splitting into multiple focused views

## View Template

```sql
-- =============================================
-- View:    dbo.vw_ViewName
-- Purpose: [Describe what this view provides]
-- Tables:  [List source tables]
-- Notes:   [Any usage notes or performance considerations]
-- =============================================
CREATE OR ALTER VIEW dbo.vw_ViewName
WITH SCHEMABINDING
AS
    SELECT
        t1.column1,
        t1.column2,
        t2.column3
    FROM dbo.Table1 AS t1
    INNER JOIN dbo.Table2 AS t2
        ON t1.id = t2.table1_id
    WHERE t1.is_active = 1;
GO
```

## Indexed Views (Materialized Views)

Consider indexed views for:
- Frequently queried aggregations (SUM, COUNT, AVG)
- Complex joins that are read-heavy and rarely change
- Dashboard or reporting queries

Requirements for indexed views:
```sql
-- 1. View must use SCHEMABINDING
-- 2. Must use two-part names (dbo.TableName)
-- 3. Cannot use SELECT *, DISTINCT, UNION, subqueries, OUTER JOIN
-- 4. Must reference only base tables (not other views)
-- 5. All functions must be deterministic

CREATE UNIQUE CLUSTERED INDEX IX_vw_ViewName
ON dbo.vw_ViewName (key_column);
```

## Anti-Pattern Examples

```sql
-- ❌ BAD: Nested view referencing another view
CREATE VIEW dbo.vw_Level2 AS
    SELECT * FROM dbo.vw_Level1   -- References another view
    WHERE status = 'Active';

-- ❌ BAD: SELECT * in a view
CREATE VIEW dbo.vw_AllOrders AS
    SELECT * FROM dbo.Orders;

-- ❌ BAD: Unnecessary DISTINCT masking duplicate joins
CREATE VIEW dbo.vw_Products AS
    SELECT DISTINCT p.name, c.name
    FROM Products p, Categories c   -- Implicit cross join!
    WHERE p.category_id = c.id;

-- ✅ GOOD: Explicit columns, proper joins, SCHEMABINDING
CREATE VIEW dbo.vw_ActiveProducts
WITH SCHEMABINDING
AS
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        p.price,
        c.name AS category_name
    FROM dbo.Products AS p
    INNER JOIN dbo.Categories AS c
        ON p.category_id = c.id
    WHERE p.is_active = 1;
```
