-- ============================================================
-- MODULE 0: DATABASE SETUP
-- ============================================================
-- Run this file first, top to bottom, in MySQL Workbench or the
-- MySQL CLI. It builds a small "retail_academy" database with:
--   1. A clean PRODUCTION schema (what a real app/analytics team
--      queries every day)
--   2. A messy STAGING schema (what a raw data dump/export looks
--      like before anyone has cleaned it)
--
-- You'll use the production tables for Modules 1-5 and 8-9, and
-- the staging tables for Modules 6-7 (data cleaning + ETL).
-- ============================================================

DROP DATABASE IF EXISTS retail_academy;
CREATE DATABASE retail_academy
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE retail_academy;

-- ------------------------------------------------------------
-- PRODUCTION SCHEMA
-- Naming convention used throughout this course:
--   - table names: plural, snake_case (customers, order_items)
--   - primary key: <singular_table_name>_id
--   - foreign key: same name as the primary key it points to
--   - booleans prefixed is_/has_
-- ------------------------------------------------------------

CREATE TABLE customers (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    country       VARCHAR(50)  NOT NULL,
    signup_date   DATE         NOT NULL,
    is_active     TINYINT(1)   NOT NULL DEFAULT 1
);

CREATE TABLE products (
    product_id    INT AUTO_INCREMENT PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    category      VARCHAR(50)  NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    in_stock      INT NOT NULL DEFAULT 0
);

CREATE TABLE employees (
    employee_id   INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    department    VARCHAR(50) NOT NULL,
    hire_date     DATE NOT NULL,
    manager_id    INT NULL,
    CONSTRAINT fk_employees_manager
        FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

CREATE TABLE orders (
    order_id      INT AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT NOT NULL,
    order_date    DATE NOT NULL,
    status        ENUM('pending','shipped','delivered','cancelled') NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id      INT NOT NULL,
    product_id    INT NOT NULL,
    quantity      INT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,  -- price AT TIME OF ORDER (can differ from products.unit_price today)
    CONSTRAINT fk_items_order  FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ------------------------------------------------------------
-- SEED DATA: employees (used for self-join lessons)
-- ------------------------------------------------------------
INSERT INTO employees (first_name, last_name, department, hire_date, manager_id) VALUES
('Maria','Chen','Executive','2016-01-10', NULL),
('Diego','Alvarez','Sales','2017-03-01', 1),
('Priya','Nair','Sales','2019-06-15', 2),
('Sam','Ok','Sales','2021-02-11', 2),
('Wei','Zhang','Support','2018-08-20', 1),
('Fatima','Hassan','Support','2020-11-02', 5),
('Liam','O''Brien','Warehouse','2019-01-05', 1),
('Ana','Souza','Warehouse','2022-04-18', 7);

-- ------------------------------------------------------------
-- SEED DATA: customers
-- ------------------------------------------------------------
INSERT INTO customers (first_name, last_name, email, country, signup_date, is_active) VALUES
('Jordan','Lee','jordan.lee@example.com','USA','2022-01-15',1),
('Aisha','Bello','aisha.bello@example.com','Nigeria','2022-02-03',1),
('Marco','Rossi','marco.rossi@example.com','Italy','2022-02-20',1),
('Yuki','Tanaka','yuki.tanaka@example.com','Japan','2022-03-05',1),
('Emma','Wilson','emma.wilson@example.com','UK','2022-03-22',1),
('Carlos','Mendez','carlos.mendez@example.com','Mexico','2022-04-01',1),
('Sofia','Kowalski','sofia.kowalski@example.com','Poland','2022-04-19',0),
('Liam','Murphy','liam.murphy@example.com','Ireland','2022-05-02',1),
('Nina','Petrova','nina.petrova@example.com','Russia','2022-05-28',1),
('Tom','Baker','tom.baker@example.com','USA','2022-06-10',1),
('Grace','Kim','grace.kim@example.com','South Korea','2022-06-30',1),
('Hassan','Ali','hassan.ali@example.com','Egypt','2022-07-14',1),
('Ivy','Nguyen','ivy.nguyen@example.com','Vietnam','2022-08-01',1),
('Oscar','Dupont','oscar.dupont@example.com','France','2022-08-19',0),
('Lena','Schmidt','lena.schmidt@example.com','Germany','2022-09-09',1);

-- ------------------------------------------------------------
-- SEED DATA: products
-- ------------------------------------------------------------
INSERT INTO products (product_name, category, unit_price, in_stock) VALUES
('Wireless Mouse','Electronics',19.99,120),
('Mechanical Keyboard','Electronics',59.99,80),
('USB-C Hub','Electronics',29.50,60),
('Noise Cancelling Headphones','Electronics',89.00,45),
('Standing Desk Mat','Furniture',34.00,30),
('Ergonomic Chair','Furniture',210.00,15),
('Desk Lamp','Furniture',24.99,50),
('Notebook Set','Office Supplies',8.50,200),
('Fountain Pen','Office Supplies',15.00,90),
('Sticky Notes Pack','Office Supplies',4.25,300),
('Water Bottle','Lifestyle',12.00,150),
('Backpack','Lifestyle',45.00,40);

-- ------------------------------------------------------------
-- SEED DATA: orders + order_items
-- (Deliberately uneven across customers/dates/status for EDA later)
-- ------------------------------------------------------------
INSERT INTO orders (customer_id, order_date, status) VALUES
(1,'2022-02-01','delivered'), (1,'2022-03-15','delivered'), (1,'2022-06-02','delivered'),
(2,'2022-02-10','delivered'), (2,'2022-05-01','cancelled'),
(3,'2022-03-01','delivered'), (3,'2022-03-20','delivered'), (3,'2022-09-01','shipped'),
(4,'2022-03-10','delivered'),
(5,'2022-04-01','delivered'), (5,'2022-04-15','delivered'), (5,'2022-07-01','delivered'),
(6,'2022-04-05','delivered'),
(7,'2022-05-01','delivered'),
(8,'2022-05-10','delivered'), (8,'2022-08-01','delivered'),
(9,'2022-06-01','delivered'), (9,'2022-06-20','pending'),
(10,'2022-06-15','delivered'), (10,'2022-09-05','delivered'),
(11,'2022-07-05','delivered'),
(12,'2022-07-20','delivered'), (12,'2022-08-10','delivered'),
(13,'2022-08-05','delivered'),
(14,'2022-08-25','cancelled'),
(15,'2022-09-10','delivered'), (15,'2022-09-12','shipped');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1,1,1,19.99), (1,8,2,8.50),
(2,4,1,89.00),
(3,2,1,59.99), (3,3,1,29.50),
(4,11,3,12.00),
(5,6,1,210.00),
(6,1,2,19.99), (6,9,1,15.00),
(7,12,1,45.00),
(8,4,1,89.00), (8,5,1,34.00),
(9,7,2,24.99),
(10,2,1,59.99),
(11,3,2,29.50),
(12,10,5,4.25),
(13,1,1,19.99),
(14,6,1,210.00),
(15,8,4,8.50),
(16,4,1,89.00), (16,11,1,12.00),
(17,2,1,59.99),
(18,9,3,15.00),
(19,12,1,45.00), (19,1,1,19.99),
(20,5,2,34.00),
(21,3,1,29.50),
(22,4,2,89.00),
(23,7,1,24.99),
(24,6,1,210.00),
(25,10,2,4.25),
(26,1,3,19.99),
(27,2,1,59.99), (27,3,1,29.50);

-- ------------------------------------------------------------
-- STAGING SCHEMA
-- This is what a raw CSV export / upstream system dump usually
-- looks like: everything is text, formatting is inconsistent,
-- there are duplicates and blanks. Nothing here has foreign
-- keys or real data types -- that's the point.
-- ------------------------------------------------------------

CREATE TABLE stg_customers_raw (
    raw_id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(150),
    email_addr    VARCHAR(150),
    country_txt   VARCHAR(80),
    signup_txt    VARCHAR(40)   -- dates arrive as messy text, e.g. "10/2/2022"
);

INSERT INTO stg_customers_raw (full_name, email_addr, country_txt, signup_txt) VALUES
('  Priya Shah ', 'PRIYA.SHAH@EXAMPLE.COM', 'india', '10/2/2022'),
('Priya Shah', 'priya.shah@example.com', 'India', '10/2/2022'),          -- duplicate of above, different casing/spacing
('ben carter', 'ben.carter@example.com', 'canada', '10/5/2022'),
('Ben Carter', 'ben.carter@example.com', 'Canada', '10/5/2022'),        -- duplicate
('Chloe Martin', 'chloe.martin@example.com', 'france', '10/11/2022'),
('  ', '', 'unknown', ''),                                              -- junk row
('Noah Becker', 'noah.becker@example.com', 'Germany', '11/1/2022'),
('Sara Ahmed', 'SARA.AHMED@EXAMPLE.COM ', ' Egypt', '11/3/2022'),
('sara ahmed', 'sara.ahmed@example.com', 'egypt', '11/3/2022');         -- duplicate

CREATE TABLE stg_orders_raw (
    raw_id         INT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(150),
    order_date_txt VARCHAR(40),
    status_txt     VARCHAR(40),
    product_name   VARCHAR(150),
    qty_txt        VARCHAR(20)
);

INSERT INTO stg_orders_raw (customer_email, order_date_txt, status_txt, product_name, qty_txt) VALUES
('jordan.lee@example.com','10/01/2022','Delivered','Wireless Mouse','2'),
('jordan.lee@example.com','10/01/2022','delivered','Wireless Mouse','2'),   -- duplicate row from a double-submit
('aisha.bello@example.com','10/03/2022','DELIVERED','Fountain Pen','1'),
('marco.rossi@example.com','10/05/2022','shipped','Ergonomic Chair','1'),
('yuki.tanaka@example.com','10/07/2022',' Pending ','USB-C Hub','3'),
('nina.petrova@example.com','10/09/2022','cancelled','Backpack','1'),
('','10/09/2022','delivered','Desk Lamp','1'),                              -- missing email, unusable row
('tom.baker@example.com','10/12/2022','Delivered','Notebook Set','4');

-- ------------------------------------------------------------
-- Sanity check
-- ------------------------------------------------------------
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'stg_customers_raw', COUNT(*) FROM stg_customers_raw
UNION ALL SELECT 'stg_orders_raw', COUNT(*) FROM stg_orders_raw;
