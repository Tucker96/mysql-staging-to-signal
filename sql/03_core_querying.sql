-- ============================================================
-- MODULE 3: AGGREGATES, GROUP BY, HAVING, CASE
-- Objectives: summarize data with aggregate functions, group rows
-- into buckets, filter groups (not rows) with HAVING, and branch
-- logic inline with CASE.
-- ============================================================
USE retail_academy;

-- Aggregate functions collapse many rows into one number
SELECT COUNT(*) AS total_products FROM products;
SELECT AVG(unit_price) AS avg_price, MIN(unit_price) AS cheapest, MAX(unit_price) AS priciest
FROM products;
SELECT SUM(quantity) AS total_units_sold FROM order_items;

-- GROUP BY: run the aggregate once PER GROUP instead of once overall
SELECT category, COUNT(*) AS num_products, AVG(unit_price) AS avg_price
FROM products
GROUP BY category;

-- Rule: every column in SELECT that ISN'T inside an aggregate
-- function must appear in GROUP BY. MySQL will sometimes let you
-- break this rule silently -- don't. It produces meaningless output.

-- Order matters: WHERE filters rows BEFORE grouping,
-- HAVING filters groups AFTER aggregation.
SELECT status, COUNT(*) AS order_count
FROM orders
WHERE order_date >= '2022-06-01'      -- filter rows first
GROUP BY status
HAVING COUNT(*) > 1;                   -- then filter the resulting groups

-- Real example: total revenue per customer, customers who've
-- spent over $100 only
SELECT
    o.customer_id,
    SUM(oi.quantity * oi.unit_price) AS total_spent
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.customer_id
HAVING SUM(oi.quantity * oi.unit_price) > 100
ORDER BY total_spent DESC;

-- CASE: inline if/else logic, very useful for bucketing
SELECT
    product_name,
    unit_price,
    CASE
        WHEN unit_price < 15 THEN 'Budget'
        WHEN unit_price BETWEEN 15 AND 60 THEN 'Mid-range'
        ELSE 'Premium'
    END AS price_tier
FROM products;

-- CASE inside an aggregate is a very common pattern: conditional counting
SELECT
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled_orders,
    COUNT(*) AS total_orders
FROM orders;

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. Count how many orders exist per status value.

-- 2. Find the average order value (quantity * unit_price, summed
--    per order) across ALL orders -- i.e. one number.
--    (Hint: you need a subquery or a two-step GROUP BY -- try
--    grouping by order_id first, then averaging.)

-- 3. List each product category with total units sold (from
--    order_items), but only show categories that have sold more
--    than 5 total units.

-- 4. For each customer, count how many of their orders were
--    'cancelled' vs everything else, using CASE + COUNT.

-- 5. Bucket customers into 'New' (signup_date in 2022 H2, i.e.
--    July-Dec) vs 'Early' (signup_date in 2022 H1) using CASE,
--    and count how many fall into each bucket.


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
SELECT status, COUNT(*) AS order_count
FROM orders
GROUP BY status;

-- 2.
SELECT AVG(order_total) AS avg_order_value
FROM (
    SELECT order_id, SUM(quantity * unit_price) AS order_total
    FROM order_items
    GROUP BY order_id
) AS order_totals;

-- 3.
SELECT p.category, SUM(oi.quantity) AS total_units_sold
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
HAVING SUM(oi.quantity) > 5;

-- 4.
SELECT
    customer_id,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled_count,
    COUNT(CASE WHEN status != 'cancelled' THEN 1 END) AS other_count
FROM orders
GROUP BY customer_id;

-- 5.
SELECT
    CASE
        WHEN signup_date < '2022-07-01' THEN 'Early'
        ELSE 'New'
    END AS signup_bucket,
    COUNT(*) AS num_customers
FROM customers
GROUP BY signup_bucket;
