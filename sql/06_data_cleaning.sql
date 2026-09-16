-- ============================================================
-- MODULE 6: DATA CLEANING IN SQL
-- Objectives: standardize messy text, parse text dates into real
-- DATE values, handle NULL/blank values, and identify duplicates --
-- using the messy stg_customers_raw / stg_orders_raw tables.
-- ============================================================
USE retail_academy;

-- Look at the mess first. Always eyeball raw data before writing
-- cleaning logic.
SELECT * FROM stg_customers_raw;
SELECT * FROM stg_orders_raw;

-- ------------------------------------------------------------
-- STRING CLEANING
-- ------------------------------------------------------------
-- TRIM removes leading/trailing whitespace. LOWER/UPPER normalize
-- case for comparisons. LENGTH tells you how "empty" a string
-- really is (a string of only spaces is NOT the same as '').
SELECT
    full_name,
    TRIM(full_name)               AS trimmed,
    LOWER(TRIM(full_name))        AS normalized,
    LENGTH(full_name)             AS raw_length,
    LENGTH(TRIM(full_name))       AS trimmed_length
FROM stg_customers_raw;

-- Splitting a "full_name" column into first/last is a very common
-- real-world task. SUBSTRING_INDEX splits on a delimiter.
SELECT
    full_name,
    TRIM(SUBSTRING_INDEX(TRIM(full_name), ' ', 1)) AS first_name_guess,
    TRIM(SUBSTRING_INDEX(TRIM(full_name), ' ', -1)) AS last_name_guess
FROM stg_customers_raw
WHERE TRIM(full_name) != '';

-- Standardizing free-text categorical columns (country, status)
SELECT
    country_txt,
    -- Capitalize first letter of each word for display
    CONCAT(UPPER(LEFT(TRIM(country_txt),1)), LOWER(SUBSTRING(TRIM(country_txt),2))) AS country_clean
FROM stg_customers_raw;

SELECT
    status_txt,
    LOWER(TRIM(status_txt)) AS status_clean
FROM stg_orders_raw;

-- ------------------------------------------------------------
-- FINDING & HANDLING BLANK / NULL / JUNK ROWS
-- ------------------------------------------------------------
-- A blank string '' is NOT NULL -- you must check for both.
SELECT * FROM stg_customers_raw
WHERE full_name IS NULL OR TRIM(full_name) = '';

SELECT * FROM stg_orders_raw
WHERE customer_email IS NULL OR TRIM(customer_email) = '';

-- COALESCE returns the first non-NULL value -- handy for defaults
SELECT full_name, COALESCE(NULLIF(TRIM(country_txt), ''), 'unknown') AS country_final
FROM stg_customers_raw;

-- ------------------------------------------------------------
-- PARSING TEXT DATES
-- ------------------------------------------------------------
-- STR_TO_DATE converts a text date into a real DATE, given a
-- format string that matches what's actually in the data.
SELECT
    signup_txt,
    STR_TO_DATE(signup_txt, '%m/%d/%Y') AS signup_date_parsed
FROM stg_customers_raw
WHERE TRIM(signup_txt) != '';

SELECT
    order_date_txt,
    STR_TO_DATE(order_date_txt, '%m/%d/%Y') AS order_date_parsed
FROM stg_orders_raw;

-- ------------------------------------------------------------
-- FINDING DUPLICATES
-- ------------------------------------------------------------
-- Simple approach: GROUP BY the fields that define "the same
-- record" and look for a count > 1.
SELECT
    LOWER(TRIM(email_addr)) AS email_normalized,
    COUNT(*) AS occurrences
FROM stg_customers_raw
GROUP BY email_normalized
HAVING COUNT(*) > 1;

-- Window-function approach (covered in depth in Module 8): tag
-- every row with its rank within its duplicate group, then you can
-- keep only rank 1.
SELECT
    raw_id, full_name, email_addr,
    ROW_NUMBER() OVER (
        PARTITION BY LOWER(TRIM(email_addr))
        ORDER BY raw_id
    ) AS dup_rank
FROM stg_customers_raw
WHERE TRIM(email_addr) != '';

-- ============================================================
-- YOUR TURN
-- ============================================================
-- 1. Write a query against stg_orders_raw that outputs: a cleaned
--    lowercase/trimmed status, a real DATE from order_date_txt,
--    and qty_txt cast to an integer (hint: CAST(qty_txt AS UNSIGNED)).

-- 2. Identify duplicate rows in stg_orders_raw -- two rows count
--    as duplicates if they share the same customer_email,
--    order_date_txt, and product_name.

-- 3. Using ROW_NUMBER() PARTITION BY the same fields as #2, write
--    a query that returns only ONE copy of each duplicate group
--    (i.e., WHERE dup_rank = 1). This is the "deduplicated" staging
--    data you'd load into production in Module 7.

-- 4. stg_customers_raw has one fully blank/junk row. Write a query
--    that filters staging down to only usable rows: full_name not
--    blank AND email_addr not blank.


-- ============================================================
-- SOLUTIONS
-- ============================================================

-- 1.
SELECT
    raw_id,
    customer_email,
    LOWER(TRIM(status_txt)) AS status_clean,
    STR_TO_DATE(order_date_txt, '%m/%d/%Y') AS order_date_clean,
    CAST(qty_txt AS UNSIGNED) AS quantity_clean
FROM stg_orders_raw;

-- 2.
SELECT customer_email, order_date_txt, product_name, COUNT(*) AS occurrences
FROM stg_orders_raw
GROUP BY customer_email, order_date_txt, product_name
HAVING COUNT(*) > 1;

-- 3.
SELECT * FROM (
    SELECT
        raw_id, customer_email, order_date_txt, status_txt, product_name, qty_txt,
        ROW_NUMBER() OVER (
            PARTITION BY customer_email, order_date_txt, product_name
            ORDER BY raw_id
        ) AS dup_rank
    FROM stg_orders_raw
) AS ranked
WHERE dup_rank = 1;

-- 4.
SELECT *
FROM stg_customers_raw
WHERE TRIM(full_name) != '' AND TRIM(email_addr) != '';
