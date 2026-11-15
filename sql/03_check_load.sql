-- =============================================================================
-- 03_check_load.sql
-- Confirms the load worked and surfaces the data quirks that matter later.
--
-- Run from the repo root:   psql -d olist -f sql/03_check_load.sql
-- =============================================================================

\set ON_ERROR_STOP on
\pset null '(null)'

\echo
\echo '=== 1. Row counts: every row should say OK ==='
WITH counts AS (
    SELECT 'category_translation' AS table_name, COUNT(*) AS loaded, 73      AS expected FROM category_translation  -- 71 from the file + 2 added
    UNION ALL SELECT 'customers',      COUNT(*), 99441   FROM customers
    UNION ALL SELECT 'sellers',        COUNT(*), 3095    FROM sellers
    UNION ALL SELECT 'products',       COUNT(*), 32951   FROM products
    UNION ALL SELECT 'orders',         COUNT(*), 99441   FROM orders
    UNION ALL SELECT 'order_items',    COUNT(*), 112650  FROM order_items
    UNION ALL SELECT 'order_payments', COUNT(*), 103886  FROM order_payments
    UNION ALL SELECT 'order_reviews',  COUNT(*), 99224   FROM order_reviews
    UNION ALL SELECT 'geolocation',    COUNT(*), 1000163 FROM geolocation
)
SELECT table_name,
       loaded,
       expected,
       CASE WHEN loaded = expected THEN 'OK' ELSE 'MISMATCH' END AS status
FROM counts
ORDER BY table_name;


\echo
\echo '=== 2. Customers vs people: customer_id is per order, customer_unique_id is the person ==='
SELECT COUNT(*)                           AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS actual_people
FROM customers;


\echo
\echo '=== 3. Review quirks (decide how to handle these before the stats) ==='
SELECT
    (SELECT COUNT(*) - COUNT(DISTINCT review_id) FROM order_reviews)        AS repeated_review_ids,
    (SELECT COUNT(*) FROM (SELECT order_id FROM order_reviews
                           GROUP BY order_id HAVING COUNT(*) > 1) AS x)      AS orders_with_2plus_reviews,
    (SELECT COUNT(*) FROM orders o
      WHERE NOT EXISTS (SELECT 1 FROM order_reviews r
                         WHERE r.order_id = o.order_id))                     AS orders_with_no_review;


\echo
\echo '=== 4. Order status and missing delivery dates ==='
SELECT order_status,
       COUNT(*)                                                    AS orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS no_delivery_date
FROM orders
GROUP BY order_status
ORDER BY orders DESC;


\echo
\echo '=== 5. Date range of the data ==='
SELECT MIN(order_purchase_timestamp)::date AS first_order,
       MAX(order_purchase_timestamp)::date AS last_order
FROM orders;


\echo
\echo '=== 6. Gaps that affect later joins ==='
SELECT
    (SELECT COUNT(*) FROM products WHERE product_category_name IS NULL)  AS products_no_category,
    (SELECT COUNT(*) FROM orders o
      WHERE NOT EXISTS (SELECT 1 FROM order_items i
                         WHERE i.order_id = o.order_id))                 AS orders_no_items,
    (SELECT COUNT(*) FROM orders o
      WHERE NOT EXISTS (SELECT 1 FROM order_payments p
                         WHERE p.order_id = o.order_id))                 AS orders_no_payment,
    (SELECT COUNT(*) FROM customers c
      WHERE NOT EXISTS (SELECT 1 FROM geolocation g
                         WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix))
                                                                         AS customers_zip_not_in_geo;


\echo
\echo '=== 7. First taste of the main question: on-time vs late, delivered orders only ==='
SELECT CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
            THEN 'late' ELSE 'on time or early' END   AS delivery,
       COUNT(*)                                       AS reviews,
       ROUND(AVG(r.review_score), 2)                  AS avg_score
FROM orders o
JOIN order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
ORDER BY 1;
\echo 'This is a raw first look, NOT the answer. It double-counts orders with 2+ reviews'
\echo 'and ignores confounders. Step 3 (statistics) does this properly.'
