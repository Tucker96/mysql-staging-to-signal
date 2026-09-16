-- ============================================================
-- MODULE 9: CTEs, STORED PROCEDURES, INDEXES & TRIGGERS
-- Objectives: write readable multi-step queries with CTEs, package
-- logic into reusable stored procedures, speed up queries with
-- indexes, and automate side effects with triggers.
-- ============================================================
USE retail_academy;

-- ------------------------------------------------------------
-- CTEs (Common Table Expressions): WITH ... AS (...)
-- ------------------------------------------------------------
-- A CTE is a named, temporary result set you can reference later
-- in the same query -- like a derived table, but far more readable
-- when you need several steps, and you can reference it more than
-- once.
WITH order_totals AS (
    SELECT o.order_id, o.customer_id, SUM(oi.quantity * oi.unit_price) AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.customer_id
),
customer_totals AS (
    SELECT customer_id, SUM(order_total) AS lifetime_value
    FROM order_totals
    GROUP BY customer_id
)
SELECT c.first_name, c.last_name, ct.lifetime_value
FROM customer_totals ct
JOIN customers c ON c.customer_id = ct.customer_id
ORDER BY ct.lifetime_value DESC;

-- Chaining several CTEs like this turns a tangled nested-subquery
-- query into a readable, step-by-step narrative -- prefer CTEs over
-- deeply nested subqueries once you have more than 2 steps.

-- Recursive CTEs can walk a hierarchy -- e.g. every employee under
-- Maria Chen (employee_id 1), at any depth:
WITH RECURSIVE org_chart AS (
    SELECT employee_id, first_name, last_name, manager_id, 0 AS depth
    FROM employees
    WHERE employee_id = 1
    UNION ALL
    SELECT e.employee_id, e.first_name, e.last_name, e.manager_id, oc.depth + 1
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.employee_id
)
SELECT * FROM org_chart ORDER BY depth, employee_id;

-- ------------------------------------------------------------
-- STORED PROCEDURES
-- ------------------------------------------------------------
-- A stored procedure packages a parameterized block of SQL that
-- you can call by name -- great for reports run the same way every
-- time (e.g. "give me this month's summary for any given month").
DELIMITER //

CREATE PROCEDURE sp_monthly_sales_report(IN report_month VARCHAR(7))
BEGIN
    SELECT
        p.category,
        SUM(oi.quantity) AS units_sold,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p      ON p.product_id = oi.product_id
    WHERE DATE_FORMAT(o.order_date, '%Y-%m') = report_month
    GROUP BY p.category
    ORDER BY revenue DESC;
END //

DELIMITER ;

-- Call it like a function:
CALL sp_monthly_sales_report('2022-08');

-- ------------------------------------------------------------
-- INDEXES & EXPLAIN
-- ------------------------------------------------------------
-- An index is a lookup structure that lets MySQL find matching
-- rows without scanning every row in the table -- essential once
-- tables have real volume (our sample data is small enough that
-- you won't SEE a speed difference, but the pattern matters).
EXPLAIN SELECT * FROM orders WHERE order_date = '2022-08-05';

-- Add an index on a column you frequently filter/join on
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- Composite index: useful when you filter/sort on two columns together
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);

-- Re-run EXPLAIN -- notice the `key` column now shows the index
-- being used instead of a full table scan (`ALL` under `type`)
EXPLAIN SELECT * FROM orders WHERE order_date = '2022-08-05';

-- Rule of thumb: index columns used in WHERE, JOIN ON, and ORDER BY
-- on LARGE tables. Don't over-index small lookup tables or columns
-- you rarely filter on -- every index speeds up reads but slows
-- down writes (INSERT/UPDATE/DELETE must maintain it too).

-- ------------------------------------------------------------
-- TRIGGERS
-- ------------------------------------------------------------
-- A trigger automatically runs SQL in response to an INSERT/UPDATE/
-- DELETE on a table. Use sparingly -- they're invisible side effects
-- that can surprise the next engineer -- but they're the right tool
-- for things like maintaining an audit trail.
CREATE TABLE order_status_audit (
    audit_id    INT AUTO_INCREMENT PRIMARY KEY,
    order_id    INT NOT NULL,
    old_status  VARCHAR(20),
    new_status  VARCHAR(20),
    changed_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE TRIGGER trg_orders_status_audit
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO order_status_audit (order_id, old_status, new_status)
        VALUES (OLD.order_id, OLD.status, NEW.status);
    END IF;
END //

DELIMITER ;

-- Test it:
UPDATE orders SET status = 'shipped' WHERE order_id = 18;  -- was 'pending'
SELECT * FROM order_status_audit;

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. Rewrite the "top 2 most expensive products per category"
--    query from Module 8 using a CTE instead of a bare subquery.

-- 2. Write a stored procedure `sp_customer_lifetime_value(IN
--    cust_id INT)` that returns a single customer's total lifetime
--    spend, number of orders, and average order value.

-- 3. Add an index that would help this query run faster on a large
--    table, and explain (as a comment) why you chose that column:
--      SELECT * FROM order_items WHERE order_id = 42;

-- 4. Extend the audit trigger idea: create a trigger that prevents
--    (SIGNAL an error for) any order_items row with quantity <= 0
--    from being inserted, as a belt-and-suspenders check alongside
--    the CHECK constraint from Module 2.


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
WITH ranked_products AS (
    SELECT
        product_name, category, unit_price,
        RANK() OVER (PARTITION BY category ORDER BY unit_price DESC) AS rank_in_category
    FROM products
)
SELECT * FROM ranked_products WHERE rank_in_category <= 2;

-- 2.
DELIMITER //
CREATE PROCEDURE sp_customer_lifetime_value(IN cust_id INT)
BEGIN
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        COUNT(DISTINCT o.order_id) AS num_orders,
        SUM(oi.quantity * oi.unit_price) AS lifetime_value,
        AVG(order_totals.order_total) AS avg_order_value
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN (
        SELECT order_id, SUM(quantity * unit_price) AS order_total
        FROM order_items GROUP BY order_id
    ) AS order_totals ON order_totals.order_id = o.order_id
    WHERE c.customer_id = cust_id
    GROUP BY c.customer_id, c.first_name, c.last_name;
END //
DELIMITER ;
-- CALL sp_customer_lifetime_value(5);

-- 3.
-- order_items.order_id is a foreign key that's queried directly here
-- and joined on constantly elsewhere -- MySQL does NOT automatically
-- index foreign key columns unless you tell it to, so without an
-- index this is a full table scan on every lookup.
CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- 4.
DELIMITER //
CREATE TRIGGER trg_order_items_qty_check
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'order_items.quantity must be greater than 0';
    END IF;
END //
DELIMITER ;
