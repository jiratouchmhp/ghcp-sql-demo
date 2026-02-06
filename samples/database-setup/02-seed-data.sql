-- =============================================
-- Script:  02-seed-data.sql
-- Purpose: Populate ECommerceDemo with realistic sample data
-- Target:  SQL Server 2019 / 2022
-- Notes:   Generates ~50K customers, ~200K orders, ~500K order items,
--          ~500K sales history records for realistic performance testing
-- =============================================

USE ECommerceDemo;
GO

SET NOCOUNT ON;

-- =============================================
-- Seed: Categories
-- =============================================
INSERT INTO dbo.Categories (name, description, parent_category_id) VALUES
('Electronics', 'Electronic devices and accessories', NULL),
('Clothing', 'Apparel and fashion items', NULL),
('Home & Garden', 'Home improvement and garden supplies', NULL),
('Sports & Outdoors', 'Sporting goods and outdoor equipment', NULL),
('Books & Media', 'Books, music, and digital media', NULL);

INSERT INTO dbo.Categories (name, description, parent_category_id) VALUES
('Smartphones', 'Mobile phones and accessories', 1),
('Laptops', 'Notebook computers', 1),
('Audio', 'Headphones, speakers, and audio equipment', 1),
('Men''s Clothing', 'Men''s apparel', 2),
('Women''s Clothing', 'Women''s apparel', 2),
('Kitchen', 'Kitchen appliances and tools', 3),
('Furniture', 'Home furniture', 3),
('Exercise Equipment', 'Gym and fitness equipment', 4),
('Outdoor Gear', 'Camping, hiking, and outdoor equipment', 4),
('Fiction', 'Fiction books', 5),
('Non-Fiction', 'Non-fiction books', 5);
GO

-- =============================================
-- Seed: Products (100 products)
-- =============================================
;WITH ProductData AS (
    SELECT * FROM (VALUES
        ('iPhone 15 Pro', 'Latest Apple smartphone', 6, 999.99, 700.00, 'ELEC-IP15P'),
        ('Samsung Galaxy S24', 'Samsung flagship phone', 6, 899.99, 620.00, 'ELEC-SGS24'),
        ('Google Pixel 8', 'Google smartphone', 6, 699.99, 480.00, 'ELEC-GP8'),
        ('MacBook Pro 16"', 'Apple laptop', 7, 2499.99, 1800.00, 'ELEC-MBP16'),
        ('Dell XPS 15', 'Dell premium laptop', 7, 1799.99, 1200.00, 'ELEC-DXP15'),
        ('ThinkPad X1 Carbon', 'Lenovo business laptop', 7, 1649.99, 1100.00, 'ELEC-TX1C'),
        ('Sony WH-1000XM5', 'Noise-canceling headphones', 8, 349.99, 200.00, 'ELEC-SWH5'),
        ('AirPods Pro 2', 'Apple wireless earbuds', 8, 249.99, 150.00, 'ELEC-APP2'),
        ('JBL Charge 5', 'Portable Bluetooth speaker', 8, 179.99, 95.00, 'ELEC-JBC5'),
        ('Classic Oxford Shirt', 'Men''s dress shirt', 9, 79.99, 25.00, 'CLO-MOXS'),
        ('Slim Fit Chinos', 'Men''s casual pants', 9, 59.99, 18.00, 'CLO-MSFC'),
        ('Wool Blazer', 'Men''s sport coat', 9, 249.99, 85.00, 'CLO-MWBL'),
        ('Silk Blouse', 'Women''s silk top', 10, 129.99, 40.00, 'CLO-WSLB'),
        ('Midi Dress', 'Women''s casual dress', 10, 89.99, 28.00, 'CLO-WMDR'),
        ('Cashmere Sweater', 'Women''s sweater', 10, 199.99, 65.00, 'CLO-WCSW'),
        ('KitchenAid Mixer', 'Stand mixer', 11, 399.99, 220.00, 'HOM-KAM'),
        ('Instant Pot Duo', 'Multi-use pressure cooker', 11, 89.99, 45.00, 'HOM-IPD'),
        ('Chef''s Knife Set', '8-piece knife set', 11, 149.99, 55.00, 'HOM-CKS'),
        ('Standing Desk', 'Adjustable standing desk', 12, 599.99, 280.00, 'HOM-STD'),
        ('Ergonomic Chair', 'Office chair', 12, 449.99, 200.00, 'HOM-ERC'),
        ('Bookshelf', '5-tier bookshelf', 12, 129.99, 45.00, 'HOM-BSH'),
        ('Peloton Bike+', 'Indoor exercise bike', 13, 2495.00, 1500.00, 'SPO-PLB'),
        ('Adjustable Dumbbells', 'Bowflex dumbbells', 13, 349.99, 180.00, 'SPO-ADB'),
        ('Yoga Mat Premium', 'Non-slip yoga mat', 13, 69.99, 15.00, 'SPO-YMP'),
        ('Hiking Backpack 65L', 'Osprey hiking pack', 14, 269.99, 130.00, 'SPO-HBP'),
        ('Camping Tent 4P', '4-person tent', 14, 349.99, 150.00, 'SPO-CT4'),
        ('Trail Running Shoes', 'All-terrain shoes', 14, 139.99, 55.00, 'SPO-TRS'),
        ('Project Hail Mary', 'Sci-fi novel by Andy Weir', 15, 16.99, 5.00, 'BOK-PHM'),
        ('Dune', 'Sci-fi classic by Frank Herbert', 15, 14.99, 4.00, 'BOK-DUN'),
        ('The Hobbit', 'Fantasy novel by J.R.R. Tolkien', 15, 12.99, 3.50, 'BOK-HOB'),
        ('Atomic Habits', 'Self-help by James Clear', 16, 18.99, 6.00, 'BOK-ATH'),
        ('Sapiens', 'History by Yuval Noah Harari', 16, 19.99, 7.00, 'BOK-SAP'),
        ('Thinking Fast and Slow', 'Psychology by Daniel Kahneman', 16, 17.99, 6.00, 'BOK-TFS')
    ) AS p(name, description, category_id, price, cost, sku)
)
INSERT INTO dbo.Products (name, description, category_id, price, cost, sku)
SELECT name, description, category_id, price, cost, sku FROM ProductData;
GO

-- Add more products to reach ~100 total
INSERT INTO dbo.Products (name, description, category_id, price, cost, sku)
SELECT
    'Product ' + CAST(v.number AS NVARCHAR(10)),
    'Auto-generated product for testing',
    (v.number % 16) + 1,
    ROUND(RAND(CHECKSUM(NEWID())) * 500 + 10, 2),
    ROUND(RAND(CHECKSUM(NEWID())) * 200 + 5, 2),
    'AUTO-' + RIGHT('000' + CAST(v.number AS NVARCHAR(10)), 4)
FROM master.dbo.spt_values AS v
WHERE v.type = 'P' AND v.number BETWEEN 1 AND 67;
GO

-- =============================================
-- Seed: Customers (~50,000)
-- =============================================
DECLARE @i INT = 1;
DECLARE @batchSize INT = 5000;
DECLARE @totalCustomers INT = 50000;

WHILE @i <= @totalCustomers
BEGIN
    INSERT INTO dbo.Customers (first_name, last_name, email, phone, address, city, state, zip_code, country)
    SELECT TOP (@batchSize)
        CHOOSE((ABS(CHECKSUM(NEWID())) % 20) + 1,
            'James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda',
            'William','Elizabeth','David','Barbara','Richard','Susan','Joseph',
            'Jessica','Thomas','Sarah','Christopher','Karen'),
        CHOOSE((ABS(CHECKSUM(NEWID())) % 20) + 1,
            'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
            'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson',
            'Anderson','Thomas','Taylor','Moore','Jackson','Martin'),
        LOWER(
            CHOOSE((ABS(CHECKSUM(NEWID())) % 5) + 1, 'user','cust','buyer','member','acct')
            + CAST(@i + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(10))
            + '@'
            + CHOOSE((ABS(CHECKSUM(NEWID())) % 4) + 1, 'gmail.com','yahoo.com','outlook.com','hotmail.com')
        ),
        '(' + RIGHT('000' + CAST(ABS(CHECKSUM(NEWID())) % 999 AS NVARCHAR(3)), 3) + ') '
            + RIGHT('000' + CAST(ABS(CHECKSUM(NEWID())) % 999 AS NVARCHAR(3)), 3) + '-'
            + RIGHT('0000' + CAST(ABS(CHECKSUM(NEWID())) % 9999 AS NVARCHAR(4)), 4),
        CAST(ABS(CHECKSUM(NEWID())) % 9999 AS NVARCHAR(10)) + ' Main St',
        CHOOSE((ABS(CHECKSUM(NEWID())) % 10) + 1,
            'New York','Los Angeles','Chicago','Houston','Phoenix',
            'Philadelphia','San Antonio','San Diego','Dallas','Seattle'),
        CHOOSE((ABS(CHECKSUM(NEWID())) % 10) + 1,
            'NY','CA','IL','TX','AZ','PA','TX','CA','TX','WA'),
        RIGHT('00000' + CAST(ABS(CHECKSUM(NEWID())) % 99999 AS NVARCHAR(5)), 5),
        'US'
    FROM master.dbo.spt_values AS v1
    CROSS JOIN master.dbo.spt_values AS v2
    WHERE v1.type = 'P' AND v2.type = 'P'
        AND v1.number BETWEEN 1 AND 100
        AND v2.number BETWEEN 1 AND 50;

    SET @i = @i + @batchSize;
END
GO

-- =============================================
-- Seed: Orders (~200,000)
-- =============================================
DECLARE @orderBatch INT = 1;
DECLARE @maxCustomerId INT = (SELECT MAX(id) FROM dbo.Customers);

WHILE @orderBatch <= 40  -- 40 batches x 5000 = 200,000
BEGIN
    INSERT INTO dbo.Orders (customer_id, order_date, status, total_amount, shipping_address,
                            shipping_city, shipping_state, shipping_zip, payment_method)
    SELECT TOP (5000)
        (ABS(CHECKSUM(NEWID())) % @maxCustomerId) + 1,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 730), GETUTCDATE()),  -- Random date within 2 years
        CHOOSE((ABS(CHECKSUM(NEWID())) % 5) + 1,
            'Completed','Completed','Completed','Shipped','Pending'),
        0,  -- Will be updated after OrderItems
        CAST(ABS(CHECKSUM(NEWID())) % 9999 AS NVARCHAR(10)) + ' Shipping Ave',
        CHOOSE((ABS(CHECKSUM(NEWID())) % 8) + 1,
            'New York','Los Angeles','Chicago','Houston','Phoenix','Dallas','Seattle','Denver'),
        CHOOSE((ABS(CHECKSUM(NEWID())) % 8) + 1,
            'NY','CA','IL','TX','AZ','TX','WA','CO'),
        RIGHT('00000' + CAST(ABS(CHECKSUM(NEWID())) % 99999 AS NVARCHAR(5)), 5),
        CHOOSE((ABS(CHECKSUM(NEWID())) % 4) + 1,
            'Credit Card','PayPal','Debit Card','Bank Transfer')
    FROM master.dbo.spt_values AS v1
    CROSS JOIN master.dbo.spt_values AS v2
    WHERE v1.type = 'P' AND v2.type = 'P'
        AND v1.number BETWEEN 1 AND 100
        AND v2.number BETWEEN 1 AND 50;

    SET @orderBatch = @orderBatch + 1;
END
GO

-- =============================================
-- Seed: OrderItems (~500,000)
-- =============================================
DECLARE @maxOrderId INT = (SELECT MAX(id) FROM dbo.Orders);
DECLARE @maxProductId INT = (SELECT MAX(id) FROM dbo.Products);
DECLARE @itemBatch INT = 1;

WHILE @itemBatch <= 100  -- 100 batches x 5000 = 500,000
BEGIN
    INSERT INTO dbo.OrderItems (order_id, product_id, quantity, unit_price, discount_percent)
    SELECT TOP (5000)
        (ABS(CHECKSUM(NEWID())) % @maxOrderId) + 1,
        (ABS(CHECKSUM(NEWID())) % @maxProductId) + 1,
        (ABS(CHECKSUM(NEWID())) % 5) + 1,
        p.price,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 < 3 THEN (ABS(CHECKSUM(NEWID())) % 25) ELSE 0 END
    FROM master.dbo.spt_values AS v1
    CROSS JOIN master.dbo.spt_values AS v2
    CROSS JOIN (SELECT TOP 1 price FROM dbo.Products ORDER BY NEWID()) AS p
    WHERE v1.type = 'P' AND v2.type = 'P'
        AND v1.number BETWEEN 1 AND 100
        AND v2.number BETWEEN 1 AND 50;

    SET @itemBatch = @itemBatch + 1;
END
GO

-- Update order totals
UPDATE o
SET total_amount = sub.order_total
FROM dbo.Orders AS o
INNER JOIN (
    SELECT order_id, SUM(line_total) AS order_total
    FROM dbo.OrderItems
    GROUP BY order_id
) AS sub ON o.id = sub.order_id;
GO

-- =============================================
-- Seed: Inventory
-- =============================================
INSERT INTO dbo.Inventory (product_id, warehouse_location, quantity_on_hand, reorder_level, last_restocked_at)
SELECT
    id,
    CHOOSE((ABS(CHECKSUM(NEWID())) % 4) + 1, 'Warehouse-A', 'Warehouse-B', 'Warehouse-C', 'Warehouse-D'),
    ABS(CHECKSUM(NEWID())) % 500 + 10,
    (ABS(CHECKSUM(NEWID())) % 50) + 5,
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 60), GETUTCDATE())
FROM dbo.Products;
GO

-- =============================================
-- Seed: SalesHistory (~500,000 records)
-- =============================================
INSERT INTO dbo.SalesHistory (product_id, customer_id, order_id, sale_date, quantity, revenue, cost, region)
SELECT
    oi.product_id,
    o.customer_id,
    o.id,
    o.order_date,
    oi.quantity,
    oi.line_total,
    p.cost * oi.quantity,
    CHOOSE((ABS(CHECKSUM(NEWID())) % 5) + 1, 'Northeast', 'Southeast', 'Midwest', 'Southwest', 'West')
FROM dbo.OrderItems AS oi
INNER JOIN dbo.Orders AS o ON oi.order_id = o.id
INNER JOIN dbo.Products AS p ON oi.product_id = p.id;
GO

PRINT 'ECommerceDemo seed data loaded successfully.';
PRINT 'Customers: ' + CAST((SELECT COUNT(*) FROM dbo.Customers) AS NVARCHAR(20));
PRINT 'Products: ' + CAST((SELECT COUNT(*) FROM dbo.Products) AS NVARCHAR(20));
PRINT 'Orders: ' + CAST((SELECT COUNT(*) FROM dbo.Orders) AS NVARCHAR(20));
PRINT 'OrderItems: ' + CAST((SELECT COUNT(*) FROM dbo.OrderItems) AS NVARCHAR(20));
PRINT 'SalesHistory: ' + CAST((SELECT COUNT(*) FROM dbo.SalesHistory) AS NVARCHAR(20));
GO
