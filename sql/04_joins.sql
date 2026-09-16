-- ============================================================
-- MODULE 4: JOINS & RELATIONSHIPS
-- Objectives: combine rows across tables with INNER/LEFT/RIGHT
-- joins, join more than two tables, and join a table to itself.
-- ============================================================
USE retail_academy;

-- INNER JOIN: only rows that match in BOTH tables survive
SELECT o.order_id, c.first_name, c.last_name, o.order_date
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id;

-- LEFT JOIN: every row from the LEFT table, plus matches from the
-- right table where they exist (NULLs where they don't).
-- This is how you find "customers with NO orders":
SELECT c.customer_id, c.first_name, c.last_name, o.order_id
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- RIGHT JOIN: mirror of LEFT JOIN (right table drives, left may be
-- NULL). Rare in practice -- most people just flip the tables and
-- use LEFT JOIN instead, but you should recognize the syntax:
SELECT c.first_name, o.order_id
FROM orders o
RIGHT JOIN customers c ON c.customer_id = o.customer_id;

-- MySQL has no native FULL OUTER JOIN. You simulate it with a
-- LEFT JOIN UNION a RIGHT JOIN (or UNION of LEFT JOIN + a second
-- LEFT JOIN with tables swapped, filtered to only-right rows):
SELECT c.customer_id, o.order_id FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
UNION
SELECT c.customer_id, o.order_id FROM orders o LEFT JOIN customers c ON o.customer_id = c.customer_id;

-- Joining THREE+ tables: chain the joins. Order rarely matters for
-- correctness, but put the most restrictive join first for readability.
SELECT
    c.first_name, c.last_name,
    o.order_id, o.order_date,
    p.product_name,
    oi.quantity, oi.unit_price
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN products p      ON p.product_id  = oi.product_id
ORDER BY o.order_id;

-- SELF JOIN: join a table to itself to compare rows within it --
-- classic use case is an org chart (employees.manager_id points
-- back to employees.employee_id)
SELECT
    e.first_name AS employee_name,
    m.first_name AS manager_name
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id;

-- Joins can have extra conditions beyond the key match
SELECT o.order_id, c.first_name
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id AND c.is_active = 1;

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. List every product that has NEVER been ordered (name only).
--    Hint: LEFT JOIN products -> order_items, filter for NULL.

-- 2. List each employee's name alongside their manager's name AND
--    department, but only for employees in the 'Sales' department.

-- 3. For every order, show the customer's full name, the order
--    date, and the TOTAL value of that order (quantity * unit_price
--    summed across its items). One row per order.

-- 4. Find all customers who share the same country as at least one
--    other customer (self join customers to itself on country,
--    excluding a row matching itself).

-- 5. List every customer and the number of DISTINCT products
--    they've ordered (0 for customers with no orders -- use LEFT
--    JOINs all the way through).


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
SELECT p.product_name
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_item_id IS NULL;

-- 2.
SELECT
    e.first_name AS employee_name,
    m.first_name AS manager_name,
    e.department
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
WHERE e.department = 'Sales';

-- 3.
SELECT
    o.order_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_date,
    SUM(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
GROUP BY o.order_id, customer_name, o.order_date;

-- 4.
SELECT DISTINCT c1.first_name, c1.last_name, c1.country
FROM customers c1
JOIN customers c2 ON c1.country = c2.country AND c1.customer_id != c2.customer_id
ORDER BY c1.country;

-- 5.
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT oi.product_id) AS distinct_products_ordered
FROM customers c
LEFT JOIN orders o       ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON oi.order_id   = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;
