# Architecture Reference — ECommerceDemo Database

## Schema Diagram

```
┌─────────────────┐     ┌─────────────────┐
│   Categories    │◄────│    Products      │
├─────────────────┤     ├─────────────────┤
│ id (PK)         │     │ id (PK)         │
│ name            │     │ name            │
│ description     │     │ category_id (FK)│──► Categories.id
│ parent_cat_id   │──┐  │ price           │
│ created_at      │  │  │ cost            │
│ updated_at      │  │  │ sku (UQ)        │
└─────────┬───────┘  │  │ is_active       │
          │          │  │ created_at      │
          └──────────┘  │ updated_at      │
                        └──────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Inventory     │  │   OrderItems    │  │  SalesHistory   │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ id (PK)         │  │ id (PK)         │  │ id (PK)         │
│ product_id (FK) │  │ order_id (FK)   │  │ product_id (FK) │
│ warehouse_loc   │  │ product_id (FK) │  │ customer_id(FK) │
│ qty_on_hand     │  │ quantity        │  │ order_id (FK)   │
│ reorder_level   │  │ unit_price      │  │ sale_date       │
│ last_restocked  │  │ discount_pct    │  │ quantity        │
│ created_at      │  │ line_total (CC) │  │ revenue         │
│ updated_at      │  │ created_at      │  │ cost            │
└─────────────────┘  │ updated_at      │  │ profit (CC)     │
                     └────────┬────────┘  │ region          │
                              │           │ created_at      │
                              │           └────────┬────────┘
                              │                    │
                              ▼                    │
                     ┌─────────────────┐           │
                     │    Orders       │           │
                     ├─────────────────┤           │
                     │ id (PK)         │◄──────────┘
                     │ customer_id(FK) │──► Customers.id
                     │ order_date      │
                     │ status          │
                     │ total_amount    │
                     │ shipping_*      │
                     │ payment_method  │
                     │ created_at      │
                     │ updated_at      │
                     └────────┬────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │   Customers     │
                     ├─────────────────┤
                     │ id (PK)         │
                     │ first_name      │
                     │ last_name       │
                     │ email           │
                     │ phone           │
                     │ address         │
                     │ city / state    │
                     │ zip_code        │
                     │ country         │
                     │ created_at      │
                     │ updated_at      │
                     └─────────────────┘
```

**Legend:** PK = Primary Key, FK = Foreign Key, UQ = Unique, CC = Computed Column

## Table Volumes (After Seed)

| Table | Approximate Rows | Growth Pattern |
|-------|------------------:|---------------|
| Customers | 50,000 | Steady |
| Categories | 16 | Static |
| Products | 100 | Slow |
| Inventory | 100 | Updates frequently |
| Orders | 200,000 | High volume |
| OrderItems | 500,000 | High volume |
| SalesHistory | 500,000 | Append-only |

## Key Relationships

- **Customers → Orders**: 1-to-many (avg 4 orders per customer)
- **Orders → OrderItems**: 1-to-many (avg 2.5 items per order)
- **Products → OrderItems**: 1-to-many (products appear in many orders)
- **SalesHistory**: Denormalized fact table joining Products, Customers, Orders

## Index Strategy (Baseline)

| Table | Index | Type | Purpose |
|-------|-------|------|---------|
| Customers | IX_Customers_Email | NC | Email lookups |
| Customers | IX_Customers_LastName_FirstName | NC | Name searches |
| Products | IX_Products_CategoryId | NC | Category filtering |
| Products | IX_Products_IsActive | NC + INCLUDE | Active product queries |
| Orders | IX_Orders_CustomerId | NC | Customer order history |
| Orders | IX_Orders_OrderDate | NC | Date range queries |
| Orders | IX_Orders_Status | NC | Status filtering |
| OrderItems | IX_OrderItems_OrderId | NC | Order detail lookups |
| OrderItems | IX_OrderItems_ProductId | NC | Product sales queries |
| SalesHistory | IX_SalesHistory_SaleDate | NC | Date reporting |
| SalesHistory | IX_SalesHistory_ProductId | NC | Product analysis |
| SalesHistory | IX_SalesHistory_CustomerId | NC | Customer analysis |
| SalesHistory | IX_SalesHistory_Region | NC | Regional reporting |

## Data Warehouse Extension (ETL Demo)

The SSIS demo creates an additional star schema in the `dw` schema:

```
┌───────────────┐     ┌───────────────────┐     ┌───────────────┐
│ DimCustomer   │     │   FactSales       │     │ DimProduct    │
├───────────────┤     ├───────────────────┤     ├───────────────┤
│ customer_key  │◄────│ customer_key (FK) │────►│ product_key   │
│ customer_id   │     │ product_key (FK)  │     │ product_id    │
│ full_name     │     │ order_id          │     │ product_name  │
│ email         │     │ order_date        │     │ category_name │
│ city / state  │     │ quantity          │     │ price / cost  │
│ is_current    │     │ unit_price        │     │ sku           │
│ effective_dt  │     │ discount_percent  │     │ is_current    │
│ expiration_dt │     │ line_total        │     │ effective_dt  │
└───────────────┘     │ cost_total        │     │ expiration_dt │
                      │ profit            │     └───────────────┘
                      │ region            │
                      └───────────────────┘
```

## Staging Area (ETL Demo)

| Table | Schema | Purpose |
|-------|--------|---------|
| CustomerImport | staging | Landing table for customer data ETL |
| DailySalesSummary | dbo | Aggregated daily sales from ETL |
