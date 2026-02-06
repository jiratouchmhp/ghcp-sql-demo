-- =============================================
-- Script:  01-create-database.sql
-- Purpose: Create the ECommerceDemo database schema
-- Target:  SQL Server 2019 / 2022
-- =============================================

USE master;
GO

-- Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'ECommerceDemo')
BEGIN
    CREATE DATABASE ECommerceDemo;
END
GO

USE ECommerceDemo;
GO

-- =============================================
-- Drop existing tables (for clean re-creation)
-- =============================================
IF OBJECT_ID('dbo.SalesHistory', 'U') IS NOT NULL DROP TABLE dbo.SalesHistory;
IF OBJECT_ID('dbo.OrderItems', 'U') IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Inventory', 'U') IS NOT NULL DROP TABLE dbo.Inventory;
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Categories', 'U') IS NOT NULL DROP TABLE dbo.Categories;
IF OBJECT_ID('dbo.Customers', 'U') IS NOT NULL DROP TABLE dbo.Customers;
GO

-- =============================================
-- Table: Customers
-- =============================================
CREATE TABLE dbo.Customers (
    id                  INT IDENTITY(1,1) NOT NULL,
    first_name          NVARCHAR(100) NOT NULL,
    last_name           NVARCHAR(100) NOT NULL,
    email               NVARCHAR(255) NOT NULL,
    phone               NVARCHAR(20) NULL,
    address             NVARCHAR(500) NULL,
    city                NVARCHAR(100) NULL,
    state               NVARCHAR(50) NULL,
    zip_code            NVARCHAR(20) NULL,
    country             NVARCHAR(100) NULL DEFAULT 'US',
    created_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (id)
);

CREATE NONCLUSTERED INDEX IX_Customers_Email ON dbo.Customers (email);
CREATE NONCLUSTERED INDEX IX_Customers_LastName_FirstName ON dbo.Customers (last_name, first_name);
GO

-- =============================================
-- Table: Categories
-- =============================================
CREATE TABLE dbo.Categories (
    id                  INT IDENTITY(1,1) NOT NULL,
    name                NVARCHAR(200) NOT NULL,
    description         NVARCHAR(1000) NULL,
    parent_category_id  INT NULL,
    created_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Categories PRIMARY KEY CLUSTERED (id),
    CONSTRAINT FK_Categories_ParentCategory FOREIGN KEY (parent_category_id)
        REFERENCES dbo.Categories (id)
);
GO

-- =============================================
-- Table: Products
-- =============================================
CREATE TABLE dbo.Products (
    id                  INT IDENTITY(1,1) NOT NULL,
    name                NVARCHAR(300) NOT NULL,
    description         NVARCHAR(2000) NULL,
    category_id         INT NOT NULL,
    price               DECIMAL(10,2) NOT NULL,
    cost                DECIMAL(10,2) NOT NULL,
    sku                 NVARCHAR(50) NOT NULL,
    is_active           BIT NOT NULL DEFAULT 1,
    created_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Products PRIMARY KEY CLUSTERED (id),
    CONSTRAINT FK_Products_Categories FOREIGN KEY (category_id)
        REFERENCES dbo.Categories (id),
    CONSTRAINT UQ_Products_SKU UNIQUE (sku)
);

CREATE NONCLUSTERED INDEX IX_Products_CategoryId ON dbo.Products (category_id);
CREATE NONCLUSTERED INDEX IX_Products_IsActive ON dbo.Products (is_active) INCLUDE (name, price);
GO

-- =============================================
-- Table: Inventory
-- =============================================
CREATE TABLE dbo.Inventory (
    id                  INT IDENTITY(1,1) NOT NULL,
    product_id          INT NOT NULL,
    warehouse_location  NVARCHAR(100) NOT NULL,
    quantity_on_hand    INT NOT NULL DEFAULT 0,
    reorder_level       INT NOT NULL DEFAULT 10,
    last_restocked_at   DATETIME2 NULL,
    created_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Inventory PRIMARY KEY CLUSTERED (id),
    CONSTRAINT FK_Inventory_Products FOREIGN KEY (product_id)
        REFERENCES dbo.Products (id)
);

CREATE NONCLUSTERED INDEX IX_Inventory_ProductId ON dbo.Inventory (product_id);
GO

-- =============================================
-- Table: Orders
-- =============================================
CREATE TABLE dbo.Orders (
    id                  INT IDENTITY(1,1) NOT NULL,
    customer_id         INT NOT NULL,
    order_date          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    status              NVARCHAR(50) NOT NULL DEFAULT 'Pending',
    total_amount        DECIMAL(12,2) NOT NULL DEFAULT 0,
    shipping_address    NVARCHAR(500) NULL,
    shipping_city       NVARCHAR(100) NULL,
    shipping_state      NVARCHAR(50) NULL,
    shipping_zip        NVARCHAR(20) NULL,
    payment_method      NVARCHAR(50) NULL,
    created_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (id),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (customer_id)
        REFERENCES dbo.Customers (id)
);

CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders (customer_id);
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON dbo.Orders (order_date);
CREATE NONCLUSTERED INDEX IX_Orders_Status ON dbo.Orders (status);
GO

-- =============================================
-- Table: OrderItems
-- =============================================
CREATE TABLE dbo.OrderItems (
    id                  INT IDENTITY(1,1) NOT NULL,
    order_id            INT NOT NULL,
    product_id          INT NOT NULL,
    quantity            INT NOT NULL,
    unit_price          DECIMAL(10,2) NOT NULL,
    discount_percent    DECIMAL(5,2) NOT NULL DEFAULT 0,
    line_total          AS (quantity * unit_price * (1 - discount_percent / 100)) PERSISTED,
    created_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_OrderItems PRIMARY KEY CLUSTERED (id),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (order_id)
        REFERENCES dbo.Orders (id) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (product_id)
        REFERENCES dbo.Products (id)
);

CREATE NONCLUSTERED INDEX IX_OrderItems_OrderId ON dbo.OrderItems (order_id);
CREATE NONCLUSTERED INDEX IX_OrderItems_ProductId ON dbo.OrderItems (product_id);
GO

-- =============================================
-- Table: SalesHistory
-- (Denormalized fact table for reporting)
-- =============================================
CREATE TABLE dbo.SalesHistory (
    id                  BIGINT IDENTITY(1,1) NOT NULL,
    product_id          INT NOT NULL,
    customer_id         INT NOT NULL,
    order_id            INT NOT NULL,
    sale_date           DATETIME2 NOT NULL,
    quantity            INT NOT NULL,
    revenue             DECIMAL(12,2) NOT NULL,
    cost                DECIMAL(12,2) NOT NULL,
    profit              AS (revenue - cost) PERSISTED,
    region              NVARCHAR(50) NOT NULL,
    created_at          DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_SalesHistory PRIMARY KEY CLUSTERED (id),
    CONSTRAINT FK_SalesHistory_Products FOREIGN KEY (product_id)
        REFERENCES dbo.Products (id),
    CONSTRAINT FK_SalesHistory_Customers FOREIGN KEY (customer_id)
        REFERENCES dbo.Customers (id),
    CONSTRAINT FK_SalesHistory_Orders FOREIGN KEY (order_id)
        REFERENCES dbo.Orders (id)
);

CREATE NONCLUSTERED INDEX IX_SalesHistory_SaleDate ON dbo.SalesHistory (sale_date);
CREATE NONCLUSTERED INDEX IX_SalesHistory_ProductId ON dbo.SalesHistory (product_id);
CREATE NONCLUSTERED INDEX IX_SalesHistory_CustomerId ON dbo.SalesHistory (customer_id);
CREATE NONCLUSTERED INDEX IX_SalesHistory_Region ON dbo.SalesHistory (region);
GO

PRINT 'ECommerceDemo database schema created successfully.';
GO
