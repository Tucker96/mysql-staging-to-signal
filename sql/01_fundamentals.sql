-- ============================================================
-- MODULE 1: MYSQL FUNDAMENTALS
-- Objectives: connect mentally to how a query executes, write
-- basic SELECT statements, filter with WHERE, sort with ORDER BY,
-- limit results, and remove duplicates with DISTINCT.
-- ============================================================
USE retail_academy;

-- A query is read by MySQL roughly in this logical order, even
-- though you TYPE it in a different order:
--   FROM -> WHERE -> GROUP BY -> HAVING -> SELECT -> ORDER BY -> LIMIT
-- Keep that order in your head; it explains a lot of "why can't
-- I do that here" errors later in the course.

-- Select everything from a table
SELECT * FROM customers;

-- Select specific columns (always prefer this over * in real work --
-- it's faster, clearer, and won't break if someone adds a column)
SELECT first_name, last_name, country FROM customers;

-- Alias a column for a friendlier output name
SELECT first_name AS given_name, last_name AS family_name
FROM customers;

-- Filter rows with WHERE
SELECT product_name, unit_price
FROM products
WHERE unit_price > 50;

-- Combine conditions with AND / OR, and use parentheses -- don't
-- trust operator precedence to do what you mean
SELECT product_name, category, unit_price
FROM products
WHERE category = 'Electronics' AND (unit_price < 25 OR in_stock < 50);

-- Pattern matching with LIKE ( % = any characters, _ = one character )
SELECT product_name FROM products WHERE product_name LIKE '%Desk%';

-- Membership check with IN (cleaner than a chain of ORs)
SELECT product_name, category FROM products
WHERE category IN ('Furniture','Lifestyle');

-- Range check with BETWEEN (inclusive on both ends)
SELECT product_name, unit_price FROM products
WHERE unit_price BETWEEN 10 AND 30;

-- NULL is not a value, it's an absence of one -- never use = or != with it
SELECT * FROM employees WHERE manager_id IS NULL;   -- the one exec with no manager
SELECT * FROM employees WHERE manager_id IS NOT NULL;

-- Sorting: ASC is default, DESC reverses it, you can sort by multiple columns
SELECT product_name, category, unit_price
FROM products
ORDER BY category ASC, unit_price DESC;

-- LIMIT caps the number of rows returned -- use with ORDER BY or the
-- rows you get are arbitrary
SELECT product_name, unit_price FROM products
ORDER BY unit_price DESC
LIMIT 3;

-- DISTINCT removes duplicate rows from the result
SELECT DISTINCT category FROM products;
SELECT DISTINCT country FROM customers ORDER BY country;

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. List every customer's first_name, last_name, and country,
--    for customers in either 'USA' or 'Germany', sorted by
--    last_name A-Z.

-- 2. List all products priced under $20, sorted cheapest first,
--    and only show product_name and unit_price.

-- 3. List the distinct list of departments that appear in the
--    employees table.

-- 4. Find the 5 most expensive products overall (name + price only).

-- 5. Find every customer whose email address contains "example.com"
--    AND whose signup_date is in 2022 (hint: you can compare dates
--    to string literals like '2022-01-01').


-- ============================================================
-- SOLUTIONS -- try it yourself before reading these!
-- ============================================================

-- 1.
SELECT first_name, last_name, country
FROM customers
WHERE country IN ('USA','Germany')
ORDER BY last_name;

-- 2.
SELECT product_name, unit_price
FROM products
WHERE unit_price < 20
ORDER BY unit_price ASC;

-- 3.
SELECT DISTINCT department FROM employees;

-- 4.
SELECT product_name, unit_price
FROM products
ORDER BY unit_price DESC
LIMIT 5;

-- 5.
SELECT first_name, last_name, email, signup_date
FROM customers
WHERE email LIKE '%example.com%'
  AND signup_date BETWEEN '2022-01-01' AND '2022-12-31';
