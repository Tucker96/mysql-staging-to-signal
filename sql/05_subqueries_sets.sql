-- ============================================================
-- MODULE 5: SUBQUERIES & SET OPERATIONS
-- Objectives: nest queries inside WHERE/FROM/SELECT, use EXISTS
-- and IN with subqueries, and combine result sets with UNION.
-- ============================================================
USE retail_academy;

-- Subquery in WHERE: find products priced above the OVERALL average
SELECT product_name, unit_price
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products);

-- Subquery with IN: customers who have placed at least one order
SELECT first_name, last_name
FROM customers
WHERE customer_id IN (SELECT DISTINCT customer_id FROM orders);

-- Subquery with NOT IN: customers who have NEVER ordered
-- (careful: NOT IN + a subquery that could contain NULL is a classic
-- bug -- if any customer_id in orders were NULL, this would return
-- ZERO rows unexpectedly. Our orders.customer_id is NOT NULL so
-- we're safe, but prefer NOT EXISTS below when in doubt.)
SELECT first_name, last_name
FROM customers
WHERE customer_id NOT IN (SELECT customer_id FROM orders);

-- EXISTS: often faster and safer than IN for "does a related row
-- exist" checks, because it stops at the first match instead of
-- building a full list.
SELECT c.first_name, c.last_name
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- NOT EXISTS: the safe version of "NOT IN"
SELECT c.first_name, c.last_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- Subquery in FROM (a "derived table"): treat a query's result
-- like a table you can further filter/join
SELECT customer_id, order_total
FROM (
    SELECT o.customer_id, SUM(oi.quantity * oi.unit_price) AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id
) AS customer_totals
WHERE order_total > 100;

-- Correlated subquery: the inner query references the OUTER query's
-- current row, so it re-runs once per outer row. Here: each
-- customer's most recent order date.
SELECT
    c.customer_id, c.first_name,
    (SELECT MAX(o.order_date) FROM orders o WHERE o.customer_id = c.customer_id) AS last_order_date
FROM customers c;

-- Subquery in SELECT works, but is often slower than an equivalent
-- JOIN for larger tables -- know both approaches.

-- UNION: stack two result sets with the SAME number/type of columns,
-- removing duplicates. UNION ALL keeps duplicates and is faster.
SELECT first_name, 'customer' AS role FROM customers
UNION
SELECT first_name, 'employee' AS role FROM employees;

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. Find all products that have NEVER appeared in order_items,
--    using NOT EXISTS instead of the LEFT JOIN approach from
--    Module 4.

-- 2. Find every order whose total value (quantity * unit_price,
--    summed) is greater than the AVERAGE order value across all
--    orders. Show order_id and order_total.

-- 3. Find customers who have ordered from the 'Electronics'
--    category at least once, using EXISTS with a join inside the
--    subquery.

-- 4. Using a derived table, find the single product category with
--    the highest total revenue (quantity * unit_price summed).

-- 5. Produce one combined list of "names to contact": all active
--    customers' full names labeled 'customer', UNIONed with all
--    Sales department employees' full names labeled 'sales_rep'.


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
SELECT p.product_name
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);

-- 2.
SELECT order_id, order_total
FROM (
    SELECT order_id, SUM(quantity * unit_price) AS order_total
    FROM order_items
    GROUP BY order_id
) AS totals
WHERE order_total > (
    SELECT AVG(order_total) FROM (
        SELECT order_id, SUM(quantity * unit_price) AS order_total
        FROM order_items
        GROUP BY order_id
    ) AS avg_calc
);

-- 3.
SELECT DISTINCT c.first_name, c.last_name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p      ON p.product_id = oi.product_id
    WHERE o.customer_id = c.customer_id
      AND p.category = 'Electronics'
);

-- 4.
SELECT category, total_revenue
FROM (
    SELECT p.category, SUM(oi.quantity * oi.unit_price) AS total_revenue
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category
) AS category_revenue
ORDER BY total_revenue DESC
LIMIT 1;

-- 5.
SELECT CONCAT(first_name, ' ', last_name) AS full_name, 'customer' AS contact_type
FROM customers
WHERE is_active = 1
UNION
SELECT CONCAT(first_name, ' ', last_name), 'sales_rep'
FROM employees
WHERE department = 'Sales';
