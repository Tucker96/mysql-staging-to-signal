-- ============================================================
-- MODULE 2: SCHEMA DESIGN & NAMING CONVENTIONS
-- Objectives: understand keys/constraints, why we normalize data
-- into multiple tables, and the naming conventions professional
-- teams use so a database is self-documenting.
-- ============================================================
USE retail_academy;

-- Inspect a table's structure
DESCRIBE customers;
SHOW CREATE TABLE orders;

-- ------------------------------------------------------------
-- WHY MULTIPLE TABLES? (normalization, informally)
-- ------------------------------------------------------------
-- Imagine one giant "orders" table with columns like
-- customer_name, customer_email, product_name, product_price...
-- repeated on every row. Problems:
--   - Update anomaly: customer changes their email -> you must
--     update it on every one of their orders, or data disagrees.
--   - Insert anomaly: can't record a new product until someone
--     orders it.
--   - Delete anomaly: delete a customer's only order and you've
--     also erased that they exist.
-- Splitting into customers / products / orders / order_items
-- (this course's schema) means each fact is stored exactly once.
-- This is the same idea behind "staging vs production" you'll
-- see in Module 7: staging holds raw, repetitive, unvalidated
-- data; production holds the normalized, de-duplicated version.

-- ------------------------------------------------------------
-- KEYS
-- ------------------------------------------------------------
-- PRIMARY KEY: uniquely identifies a row. Our convention:
--   <table_singular>_id, e.g. customer_id, product_id.
-- FOREIGN KEY: a column that points to another table's primary
--   key, enforcing that the referenced row must exist.
-- Try to break referential integrity -- MySQL should stop you:
-- (Uncomment to test -- this SHOULD fail with an FK error)
-- INSERT INTO orders (customer_id, order_date, status)
-- VALUES (9999, '2024-01-01', 'pending');

-- ------------------------------------------------------------
-- CONSTRAINTS
-- ------------------------------------------------------------
-- NOT NULL          -- column must always have a value
-- UNIQUE             -- no two rows can share this value (customers.email)
-- DEFAULT            -- value used when none is supplied (orders.status)
-- CHECK               -- a condition every row must satisfy (MySQL 8.0.16+)
-- ENUM                -- restrict a column to a fixed list of text values

-- Example: adding a CHECK constraint to an existing table
ALTER TABLE products
  ADD CONSTRAINT chk_unit_price_positive CHECK (unit_price >= 0);

-- Example: adding a new nullable column (safe on a live/production table)
ALTER TABLE customers
  ADD COLUMN loyalty_points INT NOT NULL DEFAULT 0;

-- Example: renaming a column the modern way (MySQL 8.0+)
-- ALTER TABLE customers RENAME COLUMN loyalty_points TO reward_points;

-- ------------------------------------------------------------
-- NAMING CONVENTIONS used across this whole course
-- ------------------------------------------------------------
-- tables:        plural, snake_case          customers, order_items
-- columns:       snake_case, singular        first_name, order_date
-- primary keys:  <table_singular>_id         customer_id
-- foreign keys:  same name as the PK it refs order_id in order_items
-- booleans:      is_/has_ prefix             is_active
-- staging tables: stg_ prefix                stg_orders_raw
-- Consistency here is what makes a schema "self-documenting" --
-- anyone on the team can guess a column name correctly without
-- opening the docs.

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. Use DESCRIBE to inspect the order_items table. Which column
--    is the primary key? Which two are foreign keys?

-- 2. Add a new NOT NULL column `sku` (VARCHAR(20)) to products
--    with a DEFAULT of 'UNASSIGNED' so the ALTER doesn't fail on
--    existing rows.

-- 3. Add a CHECK constraint to order_items ensuring quantity is
--    always greater than 0.

-- 4. In your own words (as a SQL comment), explain why order_items
--    stores its own unit_price column instead of just joining to
--    products.unit_price every time. (Hint: think about what
--    happens when a product's price changes next month.)


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
DESCRIBE order_items;
-- PK: order_item_id. FKs: order_id -> orders.order_id, product_id -> products.product_id.

-- 2.
ALTER TABLE products
  ADD COLUMN sku VARCHAR(20) NOT NULL DEFAULT 'UNASSIGNED';

-- 3.
ALTER TABLE order_items
  ADD CONSTRAINT chk_quantity_positive CHECK (quantity > 0);

-- 4.
-- order_items.unit_price freezes the price at the moment the sale
-- happened. If products.unit_price changes later (a price increase
-- or sale), historical orders must NOT change value retroactively --
-- otherwise your revenue reports for past months would silently
-- shift every time you looked at them. This is a very common real-
-- world pattern: snapshot the fact at transaction time.
