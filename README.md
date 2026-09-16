# Full MySQL Course — Staging, Production & EDA

An original, from-scratch MySQL course covering fundamentals through advanced
topics, built around one realistic theme: taking messy raw data from a
staging schema and turning it into clean, query-ready production data and
business analysis — the actual day-to-day work of a data/analytics role.

## Requirements

- MySQL 8.0+ (needed for window functions and CTEs used from Module 6 on)
- MySQL Workbench, the `mysql` CLI, or any SQL client of your choice

## How to use this

1. Run `sql/00_setup_database.sql` first — it creates the `retail_academy`
   database with a clean production schema (customers, products, orders,
   order_items, employees) and a messy staging schema (stg_customers_raw,
   stg_orders_raw) used later.
2. Work through `sql/01_fundamentals.sql` → `sql/10_capstone_projects.sql`
   in order. Each file has:
   - Taught concepts with runnable example queries
   - A "YOUR TURN" section — write these yourself before scrolling further
   - A "SOLUTIONS" section at the bottom — one valid approach, not the only one
3. Open `course-site.html` (or the published link, if you got one) for the
   same curriculum as an interactive, browsable course with explanations
   alongside the code.

## Curriculum

| # | Module | Covers |
|---|--------|--------|
| 1 | Fundamentals | SELECT, WHERE, ORDER BY, LIMIT, DISTINCT, LIKE, IN, BETWEEN, NULL |
| 2 | Schema Design & Naming Conventions | Keys, constraints, ALTER TABLE, why normalize |
| 3 | Aggregates & Grouping | COUNT/SUM/AVG, GROUP BY, HAVING, CASE |
| 4 | Joins & Relationships | INNER/LEFT/RIGHT, multi-table joins, self joins |
| 5 | Subqueries & Set Operations | WHERE/FROM subqueries, EXISTS, IN, UNION |
| 6 | Data Cleaning | TRIM/UPPER/LOWER, STR_TO_DATE, NULL handling, dedup |
| 7 | Staging → Production (ETL) | Views as a cleaning layer, INSERT...SELECT, upserts, transactions |
| 8 | EDA with Window Functions | ROW_NUMBER/RANK, running totals, LAG/LEAD, NTILE |
| 9 | CTEs, Procedures, Indexes, Triggers | WITH, recursive CTEs, stored procs, EXPLAIN, triggers |
| 10 | Capstone Projects (×4) | Schema design, full ETL, EDA report, reporting layer |

## Why this structure

Most SQL courses teach syntax in isolation. This one is built around a
single realistic scenario — a "staging" schema full of raw, messy export
data, and a normalized "production" schema a real application/analytics team
would query — so every module's skills compound toward the four capstone
projects instead of staying abstract exercises.

## Note on originality

This course was built independently as an original curriculum, using its own
sample dataset, explanations, and exercises. It was not copied from, and does
not reproduce, any paid course's proprietary lesson content — it exists as a
free, self-contained alternative covering similar topic areas.
