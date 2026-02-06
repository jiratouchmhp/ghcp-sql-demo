# SQL Anti-Patterns Catalog

## Severity Levels

| Level | Impact | Action |
|-------|--------|--------|
| **Critical** | >10x performance degradation | Fix immediately |
| **High** | 5-10x performance degradation | Fix before production |
| **Medium** | 2-5x performance degradation | Fix in next sprint |
| **Low** | <2x but measurable | Address when convenient |

---

## 1. Non-SARGable Predicates (Critical)

Functions on indexed columns prevent index seeks, forcing full table scans.

**Bad:**
```sql
WHERE YEAR(order_date) = 2024
WHERE CONVERT(VARCHAR, created_at, 120) = '2024-01-01'
WHERE ISNULL(status, '') = 'Active'
WHERE LOWER(email) = 'user@example.com'
```

**Good:**
```sql
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
WHERE created_at >= '2024-01-01' AND created_at < '2024-01-02'
WHERE status = 'Active'  -- Handle NULLs in application logic or with IS NOT NULL
WHERE email = 'user@example.com'  -- Use case-insensitive collation
```

## 2. SELECT \* (High)

Retrieves unnecessary columns, prevents covering index usage, increases I/O.

**Bad:**
```sql
SELECT * FROM Orders WHERE customer_id = @customerId
```

**Good:**
```sql
SELECT id, order_date, status, total_amount
FROM Orders
WHERE customer_id = @customerId;
```

## 3. Cursors / RBAR Processing (Critical)

Row-By-Agonizing-Row processing instead of set-based operations.

**Bad:**
```sql
DECLARE order_cursor CURSOR FOR SELECT id FROM Orders WHERE status = 'Pending'
OPEN order_cursor
FETCH NEXT FROM order_cursor INTO @orderId
WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE Orders SET status = 'Processing' WHERE id = @orderId
    FETCH NEXT FROM order_cursor INTO @orderId
END
```

**Good:**
```sql
UPDATE Orders
SET status = 'Processing',
    updated_at = GETUTCDATE()
WHERE status = 'Pending';
```

## 4. Scalar Subqueries in SELECT (High)

Execute once per row in the outer query.

**Bad:**
```sql
SELECT
    c.id,
    c.first_name,
    (SELECT COUNT(*) FROM Orders WHERE customer_id = c.id) AS order_count,
    (SELECT SUM(total_amount) FROM Orders WHERE customer_id = c.id) AS lifetime_value
FROM Customers c;
```

**Good:**
```sql
SELECT
    c.id,
    c.first_name,
    ISNULL(o.order_count, 0) AS order_count,
    ISNULL(o.lifetime_value, 0) AS lifetime_value
FROM Customers c
LEFT JOIN (
    SELECT customer_id, COUNT(*) AS order_count, SUM(total_amount) AS lifetime_value
    FROM Orders
    GROUP BY customer_id
) o ON c.id = o.customer_id;
```

## 5. Implicit Type Conversion (Medium)

Mismatched types in comparisons force implicit conversion, preventing index usage.

**Bad:**
```sql
-- @zipCode is VARCHAR but column is INT
WHERE zip_code = @zipCode  -- implicit conversion on every row!

-- Comparing NVARCHAR parameter to VARCHAR column
WHERE sku = @searchSku  -- may force column conversion
```

**Good:**
```sql
-- Match parameter type to column type exactly
DECLARE @zipCode NVARCHAR(20) = '90210';
WHERE zip_code = @zipCode;
```

## 6. LIKE with Leading Wildcard (High)

`LIKE '%pattern'` cannot use a B-tree index.

**Bad:**
```sql
WHERE last_name LIKE '%smith%'
```

**Good (alternatives):**
```sql
-- Full-text search
WHERE CONTAINS(last_name, 'smith')
-- Or suffix index (reversed column)
-- Or application-level search (Elasticsearch, etc.)
```

## 7. Missing Error Handling (Medium)

No TRY/CATCH leaves procedures vulnerable to partial execution.

**Bad:**
```sql
CREATE PROCEDURE usp_ProcessOrder @orderId INT
AS
    UPDATE Orders SET status = 'Processing' WHERE id = @orderId
    INSERT INTO AuditLog (action) VALUES ('Processing order ' + CAST(@orderId AS VARCHAR))
```

**Good:**
```sql
CREATE PROCEDURE usp_ProcessOrder @orderId INT
AS
SET NOCOUNT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    
    UPDATE Orders SET status = 'Processing' WHERE id = @orderId;
    INSERT INTO AuditLog (action) VALUES ('Processing order ' + CAST(@orderId AS VARCHAR));
    
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

## 8. Unnecessary DISTINCT (Medium)

Masks duplicate rows from improper joins instead of fixing the root cause.

**Bad:**
```sql
SELECT DISTINCT c.id, c.first_name, c.last_name
FROM Customers c
LEFT JOIN Orders o ON c.id = o.customer_id
LEFT JOIN OrderItems oi ON o.id = oi.order_id;
-- DISTINCT hides the 1-to-many multiplication
```

**Good:**
```sql
SELECT c.id, c.first_name, c.last_name
FROM Customers c
WHERE EXISTS (SELECT 1 FROM Orders WHERE customer_id = c.id);
```

## 9. Missing SET NOCOUNT ON (Low)

Without it, SQL Server sends row-count messages for every DML statement, causing extra network traffic.

**Fix:** Add `SET NOCOUNT ON;` as the first line in every stored procedure.

## 10. Parameter Sniffing Issues (Medium)

First execution plan may be suboptimal for subsequent parameter values.

**Mitigations:**
```sql
-- Option 1: OPTION (RECOMPILE) for variable workloads
SELECT ... FROM Orders WHERE status = @status OPTION (RECOMPILE);

-- Option 2: OPTIMIZE FOR for known skew
SELECT ... FROM Orders WHERE status = @status OPTION (OPTIMIZE FOR (@status = 'Completed'));

-- Option 3: Local variable (loses cardinality estimate)
DECLARE @localStatus NVARCHAR(50) = @status;
SELECT ... FROM Orders WHERE status = @localStatus;
```
