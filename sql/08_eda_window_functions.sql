-- ============================================================
-- MODULE 8: EXPLORATORY DATA ANALYSIS WITH WINDOW FUNCTIONS
-- Objectives: use window functions to rank, compute running totals,
-- find top-N per group, and analyze trends -- the core toolkit for
-- doing real EDA directly in SQL instead of exporting to Excel/Python.
-- ============================================================
USE retail_academy;

-- A window function computes a value ACROSS a set of rows (the
-- "window") related to the current row, WITHOUT collapsing them
-- into one row the way GROUP BY does. Syntax: FUNCTION() OVER (...)

-- ------------------------------------------------------------
-- RANKING FUNCTIONS
-- ------------------------------------------------------------
-- ROW_NUMBER: 1,2,3,4... no ties.
-- RANK: 1,2,2,4... ties share a rank, next rank skips.
-- DENSE_RANK: 1,2,2,3... ties share a rank, no gap after.
SELECT
    product_name, category, unit_price,
    ROW_NUMBER() OVER (ORDER BY unit_price DESC) AS row_num,
    RANK()       OVER (ORDER BY unit_price DESC) AS rank_num,
    DENSE_RANK() OVER (ORDER BY unit_price DESC) AS dense_rank_num
FROM products;

-- PARTITION BY resets the window per group -- e.g. rank products
-- WITHIN each category instead of overall
SELECT
    product_name, category, unit_price,
    RANK() OVER (PARTITION BY category ORDER BY unit_price DESC) AS rank_in_category
FROM products;

-- Classic "top-N per group" pattern: wrap the above in a subquery
-- and filter on the rank
SELECT * FROM (
    SELECT
        product_name, category, unit_price,
        RANK() OVER (PARTITION BY category ORDER BY unit_price DESC) AS rank_in_category
    FROM products
) AS ranked
WHERE rank_in_category <= 2;   -- top 2 most expensive per category

-- ------------------------------------------------------------
-- RUNNING TOTALS & MOVING CALCULATIONS
-- ------------------------------------------------------------
-- SUM() OVER (ORDER BY ...) with no PARTITION BY = a running total
-- across the whole result set, in the order specified.
SELECT
    order_id, order_date, order_total,
    SUM(order_total) OVER (ORDER BY order_date, order_id) AS running_revenue
FROM (
    SELECT o.order_id, o.order_date, SUM(oi.quantity * oi.unit_price) AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.order_date
) AS order_totals;

-- Monthly revenue with a running (cumulative) total across months.
-- Two-step pattern: first GROUP BY to get one row per month, THEN
-- apply the window function over that already-aggregated result.
SELECT
    order_month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (ORDER BY order_month) AS cumulative_revenue
FROM (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY order_month
) AS monthly
ORDER BY order_month;

-- ------------------------------------------------------------
-- LAG / LEAD: compare a row to the previous/next row
-- ------------------------------------------------------------
-- Useful for month-over-month change, or "days since last order"
SELECT
    order_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month) AS change_vs_prev_month
FROM (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
           SUM(oi.quantity * oi.unit_price) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY order_month
) AS monthly;

-- ------------------------------------------------------------
-- NTILE: split rows into N roughly equal buckets (e.g. quartiles)
-- ------------------------------------------------------------
SELECT
    customer_id, total_spent,
    NTILE(4) OVER (ORDER BY total_spent DESC) AS spend_quartile   -- 1 = top spenders
FROM (
    SELECT o.customer_id, SUM(oi.quantity * oi.unit_price) AS total_spent
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id
) AS spend;

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. Find each customer's FIRST order date and MOST RECENT order
--    date, and the number of days between them, using window
--    functions (MIN()/MAX() OVER PARTITION BY customer_id) --
--    don't use GROUP BY for this one.

-- 2. Rank customers by total lifetime spend, overall (not per
--    category), and return only the top 5.

-- 3. Compute month-over-month revenue GROWTH RATE (percentage),
--    using LAG. (percent change = (this - prev) / prev * 100)

-- 4. For each order, compute what % of that customer's total
--    lifetime spend this single order represents (hint: SUM(...)
--    OVER (PARTITION BY customer_id) gives the customer total
--    alongside each row).


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
SELECT DISTINCT
    customer_id,
    MIN(order_date) OVER (PARTITION BY customer_id) AS first_order,
    MAX(order_date) OVER (PARTITION BY customer_id) AS last_order,
    DATEDIFF(
        MAX(order_date) OVER (PARTITION BY customer_id),
        MIN(order_date) OVER (PARTITION BY customer_id)
    ) AS days_active
FROM orders;

-- 2.
SELECT customer_id, total_spent, spend_rank FROM (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.unit_price) AS total_spent,
        RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS spend_rank
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id
) AS ranked
WHERE spend_rank <= 5;

-- 3.
SELECT
    order_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY order_month) AS prev_month,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month))
        / LAG(monthly_revenue) OVER (ORDER BY order_month) * 100
    , 1) AS pct_growth
FROM (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
           SUM(oi.quantity * oi.unit_price) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY order_month
) AS monthly;

-- 4.
SELECT
    order_id, customer_id, order_total,
    ROUND(order_total / SUM(order_total) OVER (PARTITION BY customer_id) * 100, 1) AS pct_of_customer_lifetime
FROM (
    SELECT o.order_id, o.customer_id, SUM(oi.quantity * oi.unit_price) AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.customer_id
) AS order_totals;
