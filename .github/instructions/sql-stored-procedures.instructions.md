---
description: "T-SQL stored procedure development and optimization standards for SQL Server 2019/2022. Covers naming conventions, parameter handling, error management, performance patterns, and anti-pattern avoidance."
applyTo: "**/stored-procedures/**/*.sql"
---

# SQL Stored Procedure Standards

## Naming Conventions

- Prefix all stored procedures with `usp_` followed by PascalCase verb+noun
- Use descriptive names: `usp_GetCustomerOrders`, `usp_UpdateInventoryQuantity`
- Avoid `sp_` prefix (reserved for system procedures — causes extra master DB lookup)
- Parameters: prefix with `@`, use camelCase: `@customerId`, `@startDate`

## Required Structure

Every stored procedure MUST follow this template:

```sql
CREATE OR ALTER PROCEDURE dbo.usp_ProcedureName
    @param1 INT,
    @param2 NVARCHAR(100) = NULL  -- Optional with default
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Validate parameters
        -- Business logic here
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
```

## Performance Rules

### MUST DO
- Include `SET NOCOUNT ON` as the first statement
- List explicit columns in SELECT (never `SELECT *`)
- Use SARGable predicates in WHERE clauses
- Use `EXISTS` instead of `COUNT(*) > 0` for existence checks
- Prefer `JOIN` over correlated subqueries
- Use table aliases consistently (e.g., `o` for Orders, `c` for Customers)

### MUST AVOID
- **Cursors**: Replace with set-based logic (CTE, windowing functions, CROSS APPLY)
- **Scalar UDFs in queries**: Inline the logic or use inline table-valued functions
- **SELECT ***: Always list specific columns
- **Functions on indexed columns in WHERE**: `WHERE YEAR(order_date) = 2024` → `WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'`
- **NOLOCK hints everywhere**: Use appropriate isolation levels instead
- **Dynamic SQL with concatenation**: Use `sp_executesql` with parameters

## Transaction Management

```sql
BEGIN TRY
    BEGIN TRANSACTION;
        -- DML operations here
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    -- Log error details
    DECLARE @errorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @errorSeverity INT = ERROR_SEVERITY();
    DECLARE @errorState INT = ERROR_STATE();

    RAISERROR(@errorMessage, @errorSeverity, @errorState);
END CATCH
```

## Parameter Sniffing Mitigation

When a stored procedure performs very differently based on parameter values:

```sql
-- Option 1: Local variable assignment
DECLARE @localCustomerId INT = @customerId;
-- Use @localCustomerId in queries

-- Option 2: OPTION (RECOMPILE) for infrequently called procedures
SELECT ... FROM ... WHERE customer_id = @customerId
OPTION (RECOMPILE);

-- Option 3: OPTIMIZE FOR for known typical values
SELECT ... FROM ... WHERE status = @status
OPTION (OPTIMIZE FOR (@status = 'Active'));
```
