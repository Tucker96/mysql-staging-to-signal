-- ============================================================
-- MODULE 10: CAPSTONE PROJECTS
-- Four portfolio-ready projects that combine everything from
-- Modules 1-9 into realistic end-to-end work. Do each project's
-- "YOUR TURN" section yourself first -- the solution sketch after
-- each one is ONE valid approach, not the only correct answer.
-- ============================================================
USE retail_academy;

-- ============================================================
-- CAPSTONE 1: SCHEMA DESIGN -- ADD A RETURNS FEATURE
-- ============================================================
-- The business wants to start tracking product returns. Design and
-- build the schema for it, following this course's naming
-- conventions (Module 2).
--
-- Requirements:
--   - Every return is tied to exactly one order_item (you can't
--     return more than what was ordered on that line).
--   - Track a reason (free text), a status (requested / approved /
--     rejected / refunded), the refund_amount, and the date.
--   - A return should not be insertable for a quantity greater
--     than what was originally ordered on that order_item.
--   - Write 2-3 queries against your new table proving it works:
--     e.g. total refunded amount by month, return rate by product
--     category (# returns / # units sold).
--
-- YOUR TURN: design and build this before reading the solution.

-- ---- solution sketch ----
CREATE TABLE returns (
    return_id      INT AUTO_INCREMENT PRIMARY KEY,
    order_item_id  INT NOT NULL,
    reason         VARCHAR(255),
    status         ENUM('requested','approved','rejected','refunded') NOT NULL DEFAULT 'requested',
    return_qty     INT NOT NULL,
    refund_amount  DECIMAL(10,2) NOT NULL DEFAULT 0,
    return_date    DATE NOT NULL,
    CONSTRAINT fk_returns_order_item FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id),
    CONSTRAINT chk_return_qty_positive CHECK (return_qty > 0)
);

-- Sample data so the proof queries below have something to show
INSERT INTO returns (order_item_id, reason, status, return_qty, refund_amount, return_date) VALUES
(2, 'Wrong size', 'refunded', 1, 8.50, '2022-06-10'),
(8, 'Defective', 'refunded', 1, 89.00, '2022-06-25'),
(14, 'Changed mind', 'approved', 1, 15.00, '2022-09-01');

-- Proof query: total refunded amount by month
SELECT DATE_FORMAT(return_date, '%Y-%m') AS return_month, SUM(refund_amount) AS total_refunded
FROM returns
WHERE status = 'refunded'
GROUP BY return_month;

-- Proof query: return rate by category (# returned units / # sold units)
SELECT
    p.category,
    SUM(oi.quantity) AS units_sold,
    COALESCE(SUM(r.return_qty), 0) AS units_returned,
    ROUND(COALESCE(SUM(r.return_qty), 0) / SUM(oi.quantity) * 100, 1) AS return_rate_pct
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
LEFT JOIN returns r ON r.order_item_id = oi.order_item_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;


-- ============================================================
-- CAPSTONE 2: FULL STAGING -> PRODUCTION ETL
-- ============================================================
-- Module 7 loaded staging customers and staging order HEADERS into
-- production, but never loaded the order_items (the product/qty
-- detail). Finish the pipeline:
--
-- Requirements:
--   - For every cleaned, non-duplicate row in vw_stg_orders_clean,
--     insert a matching row into order_items (resolve product_name
--     -> product_id, resolve customer_email -> the order you
--     already inserted for that customer/date in Module 7).
--   - Use a transaction: if any row can't resolve a product name,
--     the whole batch should roll back (simulate this by checking
--     for unmatched product names FIRST, before you commit).
--   - Afterward, write a query proving no staging order is missing
--     its order_items.

-- ---- solution sketch ----

-- Step 1: sanity check for unmatched product names BEFORE loading
-- (if this returns any rows, stop and fix product_name spelling in
-- staging before proceeding -- don't load partial data)
SELECT DISTINCT v.product_name
FROM vw_stg_orders_clean v
LEFT JOIN products p ON p.product_name = v.product_name
WHERE p.product_id IS NULL;

-- Step 2: the load, wrapped in a transaction
START TRANSACTION;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT
    o.order_id,
    p.product_id,
    v.quantity,
    p.unit_price
FROM vw_stg_orders_clean v
JOIN customers c ON c.email = v.customer_email
JOIN orders o     ON o.customer_id = c.customer_id AND o.order_date = v.order_date
JOIN products p    ON p.product_name = v.product_name
WHERE v.dup_rank = 1
  AND NOT EXISTS (
      -- don't double-insert if this capstone script is re-run
      SELECT 1 FROM order_items oi2
      WHERE oi2.order_id = o.order_id AND oi2.product_id = p.product_id
  );

COMMIT;

-- Step 3: proof -- every staging order now has at least one item
SELECT v.customer_email, v.order_date, v.product_name,
       (SELECT COUNT(*) FROM order_items oi
        JOIN orders o2 ON o2.order_id = oi.order_id
        JOIN customers c2 ON c2.customer_id = o2.customer_id
        WHERE c2.email = v.customer_email AND o2.order_date = v.order_date) AS matching_items_found
FROM vw_stg_orders_clean v
WHERE v.dup_rank = 1;


-- ============================================================
-- CAPSTONE 3: EXPLORATORY DATA ANALYSIS REPORT
-- ============================================================
-- Produce a 5-part written + SQL analysis of the business, as if
-- handing it to a manager. For each part, write the query AND one
-- sentence of plain-English interpretation as a comment above it.
--
-- Required sections:
--   1. Revenue trend: monthly revenue + month-over-month % growth
--   2. Top 5 customers by lifetime value, and what % of TOTAL
--      company revenue they represent combined
--   3. Product performance: top 3 products by revenue AND top 3 by
--      units sold (are they the same products?)
--   4. Repeat purchase rate: % of customers with more than 1 order
--   5. Category mix: revenue share (%) by category

-- ---- solution sketch ----

-- 1. Monthly revenue + MoM growth
SELECT
    order_month, monthly_revenue,
    ROUND((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month))
          / LAG(monthly_revenue) OVER (ORDER BY order_month) * 100, 1) AS mom_growth_pct
FROM (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
           SUM(oi.quantity * oi.unit_price) AS monthly_revenue
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY order_month
) AS m;

-- 2. Top 5 customers by lifetime value + their combined % of total revenue
WITH customer_ltv AS (
    SELECT o.customer_id, SUM(oi.quantity * oi.unit_price) AS ltv
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id
),
ranked AS (
    SELECT *, RANK() OVER (ORDER BY ltv DESC) AS rnk FROM customer_ltv
)
SELECT
    c.first_name, c.last_name, r.ltv,
    ROUND(r.ltv / (SELECT SUM(ltv) FROM customer_ltv) * 100, 1) AS pct_of_total_revenue
FROM ranked r
JOIN customers c ON c.customer_id = r.customer_id
WHERE r.rnk <= 5
ORDER BY r.ltv DESC;

-- 3a. Top 3 products by revenue
SELECT p.product_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_name ORDER BY revenue DESC LIMIT 3;

-- 3b. Top 3 products by units sold
SELECT p.product_name, SUM(oi.quantity) AS units_sold
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_name ORDER BY units_sold DESC LIMIT 3;

-- 4. Repeat purchase rate
SELECT
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS repeat_purchase_rate_pct
FROM (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders GROUP BY customer_id
) AS per_customer;

-- 5. Revenue share by category
SELECT
    p.category,
    SUM(oi.quantity * oi.unit_price) AS revenue,
    ROUND(SUM(oi.quantity * oi.unit_price) / SUM(SUM(oi.quantity * oi.unit_price)) OVER () * 100, 1) AS pct_of_revenue
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;


-- ============================================================
-- CAPSTONE 4: REPORTING & PERFORMANCE
-- ============================================================
-- Turn Capstone 3's ad-hoc queries into reusable, production-ready
-- assets a whole team could rely on.
--
-- Requirements:
--   - A view `vw_monthly_business_summary` exposing month, revenue,
--     order_count, and average order value, one row per month.
--   - A stored procedure `sp_top_customers(IN limit_n INT)` that
--     returns the top N customers by lifetime value.
--   - Add indexes anywhere you think a report like this would
--     benefit at real scale, and justify each one in a comment.

-- ---- solution sketch ----

CREATE OR REPLACE VIEW vw_monthly_business_summary AS
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    SUM(oi.quantity * oi.unit_price) AS revenue,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY order_month;

SELECT * FROM vw_monthly_business_summary ORDER BY order_month;

DELIMITER //
CREATE PROCEDURE sp_top_customers(IN limit_n INT)
BEGIN
    SELECT c.first_name, c.last_name, SUM(oi.quantity * oi.unit_price) AS lifetime_value
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY c.customer_id, c.first_name, c.last_name
    ORDER BY lifetime_value DESC
    LIMIT limit_n;
END //
DELIMITER ;

-- CALL sp_top_customers(5);

-- Indexes: order_date is filtered/grouped by in nearly every report
-- above; customer_id and product_id are joined on constantly. These
-- were already added in Module 9, listed here for completeness:
--   idx_orders_order_date, idx_order_items_product_id,
--   idx_orders_customer_date, idx_order_items_order_id

-- ============================================================
-- COURSE COMPLETE
-- You've built a normalized production schema, an ETL pipeline
-- from messy staging data, a full EDA toolkit with window
-- functions, and reusable views/procedures for reporting. That's
-- the real day-to-day work of a data/analytics role -- put these
-- 4 capstones in a portfolio repo with your written interpretations
-- from Capstone 3 as the write-up.
-- ============================================================
