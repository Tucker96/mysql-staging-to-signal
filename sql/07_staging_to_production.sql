-- ============================================================
-- MODULE 7: STAGING -> PRODUCTION WORKFLOWS (ETL)
-- Objectives: understand why real data teams separate staging from
-- production, load cleaned staging data into production tables,
-- avoid inserting duplicates against data that already exists, use
-- transactions for safety, and build a view that acts as a
-- reusable "clean staging" layer.
-- ============================================================
USE retail_academy;

-- ------------------------------------------------------------
-- WHY STAGING TABLES EXIST
-- ------------------------------------------------------------
-- Production tables (customers, orders, ...) have strict types,
-- foreign keys, and constraints -- great for keeping data correct,
-- but a raw CSV export will violate half of them on load.
-- Staging tables (stg_*) are permissive: everything is text,
-- nothing is validated, so the load NEVER fails. Cleaning and
-- validation happen in SQL, in a controlled, reviewable step,
-- between staging and production. This is the same pattern behind
-- "ETL" (Extract, Transform, Load) or modern "ELT" pipelines.

-- ------------------------------------------------------------
-- STEP 1: BUILD A "CLEAN STAGING" VIEW
-- ------------------------------------------------------------
-- A VIEW is a saved query you can SELECT from like a table. It
-- doesn't store data itself -- it re-runs the underlying query
-- every time. Perfect for a reusable cleaning layer.
CREATE OR REPLACE VIEW vw_stg_customers_clean AS
SELECT
    raw_id,
    TRIM(full_name) AS full_name,
    LOWER(TRIM(email_addr)) AS email,
    LOWER(TRIM(country_txt)) AS country,
    STR_TO_DATE(TRIM(signup_txt), '%m/%d/%Y') AS signup_date,
    ROW_NUMBER() OVER (
        PARTITION BY LOWER(TRIM(email_addr))
        ORDER BY raw_id
    ) AS dup_rank
FROM stg_customers_raw
WHERE TRIM(full_name) != '' AND TRIM(email_addr) != '';

SELECT * FROM vw_stg_customers_clean WHERE dup_rank = 1;

-- ------------------------------------------------------------
-- STEP 2: LOAD INTO PRODUCTION WITH INSERT ... SELECT
-- ------------------------------------------------------------
-- Split full_name into first/last to match the production schema,
-- and only insert customers who don't already exist (by email).
INSERT INTO customers (first_name, last_name, email, country, signup_date)
SELECT
    TRIM(SUBSTRING_INDEX(v.full_name, ' ', 1))  AS first_name,
    TRIM(SUBSTRING_INDEX(v.full_name, ' ', -1)) AS last_name,
    v.email,
    -- Capitalize for display consistency with existing production rows
    CONCAT(UPPER(LEFT(v.country,1)), LOWER(SUBSTRING(v.country,2))) AS country,
    v.signup_date
FROM vw_stg_customers_clean v
WHERE v.dup_rank = 1                                  -- drop in-batch duplicates
  AND NOT EXISTS (                                     -- drop customers already in production
      SELECT 1 FROM customers c WHERE c.email = v.email
  );

-- Verify the load
SELECT * FROM customers WHERE email IN (
    SELECT email FROM vw_stg_customers_clean
);

-- ------------------------------------------------------------
-- UPSERT: ON DUPLICATE KEY UPDATE
-- ------------------------------------------------------------
-- Sometimes you want to insert a new row OR update it if it
-- already exists (matched by a UNIQUE/PRIMARY key), in one
-- statement. Classic use: refreshing a product's stock count from
-- a daily inventory feed without caring whether it's a new SKU.
INSERT INTO products (product_id, product_name, category, unit_price, in_stock, sku)
VALUES (1, 'Wireless Mouse', 'Electronics', 19.99, 500, 'UNASSIGNED')
ON DUPLICATE KEY UPDATE in_stock = VALUES(in_stock);

SELECT product_id, product_name, in_stock FROM products WHERE product_id = 1;

-- ------------------------------------------------------------
-- TRANSACTIONS: all-or-nothing changes
-- ------------------------------------------------------------
-- If a load involves multiple statements (e.g., insert customers,
-- THEN insert their orders), you don't want a failure halfway
-- through to leave the database in a half-loaded state. Wrap the
-- batch in a transaction.
START TRANSACTION;

INSERT INTO customers (first_name, last_name, email, country, signup_date)
VALUES ('Test', 'Rollback', 'test.rollback@example.com', 'Testland', '2024-01-01');

-- Imagine a second statement here fails validation -- you can undo
-- everything in the transaction:
ROLLBACK;

-- Confirm it was NOT actually saved
SELECT * FROM customers WHERE email = 'test.rollback@example.com';  -- 0 rows

-- If everything succeeds, you'd COMMIT instead of ROLLBACK:
START TRANSACTION;
INSERT INTO customers (first_name, last_name, email, country, signup_date)
VALUES ('Real', 'Insert', 'real.insert@example.com', 'Testland', '2024-01-01');
COMMIT;

SELECT * FROM customers WHERE email = 'real.insert@example.com';  -- 1 row
-- cleanup so re-running this file stays repeatable:
DELETE FROM customers WHERE email = 'real.insert@example.com';

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. Build a view `vw_stg_orders_clean` over stg_orders_raw that:
--    trims/lowercases status, parses order_date_txt into a real
--    DATE, casts qty_txt to an integer, and uses ROW_NUMBER to tag
--    duplicates (partition by customer_email, order_date_txt,
--    product_name).

-- 2. Using that view (dup_rank = 1 only, and customer_email not
--    blank), write an INSERT ... SELECT that loads new rows into
--    `orders`, resolving customer_email to customers.customer_id
--    via a JOIN, and resolving product_name to products.product_id
--    via a JOIN. Default status to the cleaned status value.
--    (Note: order_items would need a similar second insert to
--    record quantity/product -- that's part of Capstone 2.)

-- 3. Explain (as a comment) why we check `NOT EXISTS` against
--    production by email/business-key, rather than just trusting
--    that staging never contains something already loaded.


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
CREATE OR REPLACE VIEW vw_stg_orders_clean AS
SELECT
    raw_id,
    LOWER(TRIM(customer_email)) AS customer_email,
    STR_TO_DATE(TRIM(order_date_txt), '%m/%d/%Y') AS order_date,
    LOWER(TRIM(status_txt)) AS status,
    TRIM(product_name) AS product_name,
    CAST(qty_txt AS UNSIGNED) AS quantity,
    ROW_NUMBER() OVER (
        PARTITION BY LOWER(TRIM(customer_email)), order_date_txt, TRIM(product_name)
        ORDER BY raw_id
    ) AS dup_rank
FROM stg_orders_raw;

-- 2.
INSERT INTO orders (customer_id, order_date, status)
SELECT DISTINCT
    c.customer_id,
    v.order_date,
    -- production only allows a fixed ENUM, so map free-text 'pending'/etc.
    CASE WHEN v.status IN ('pending','shipped','delivered','cancelled')
         THEN v.status ELSE 'pending' END
FROM vw_stg_orders_clean v
JOIN customers c ON c.email = v.customer_email
WHERE v.dup_rank = 1
  AND v.customer_email != ''
  AND NOT EXISTS (
      SELECT 1 FROM orders o
      WHERE o.customer_id = c.customer_id AND o.order_date = v.order_date
  );

-- 3.
-- Staging almost always represents an incremental batch (e.g. "today's
-- export"), and pipelines get re-run -- for retries after a failure,
-- for backfills, or because a scheduler fired twice. Without checking
-- production first, re-running the same load would insert the same
-- customers/orders again, silently duplicating revenue and record
-- counts. Checking NOT EXISTS against a stable business key (email,
-- not an auto-increment id staging can't know) makes the load
-- idempotent: safe to run more than once with the same result.
