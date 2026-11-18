CREATE OR REPLACE VIEW analysis_orders AS
WITH latest_review AS (
	SELECT order_id, review_score
	FROM (
		SELECT order_id, review_score,
			ROW_NUMBER() OVER (PARTITION BY order_id
							   ORDER BY review_answer_timestamp DESC, review_id) AS rn
		FROM order_reviews
	) r
	WHERE rn = 1
),
order_totals AS (
	SELECT order_id,
	COUNT(*) AS n_items,
	COUNT(DISTINCT seller_id) AS n_sellers,
	SUM(PRICE) AS order_price,
	SUM(freight_value) AS order_freight
	FROM order_items
	GROUP BY order_id
),
main_category AS (
	SELECT order_id, category
	FROM ( 
		SELECT oi.order_id,
			COALESCE(t.product_category_name_english, 'unkown') AS category,
			ROW_NUMBER() OVER (PARTITION BY oi.order_id
							   ORDER BY oi.price DESC, oi.order_item_id) AS rn
		FROM order_items oi
		JOIN products p ON p.product_id = oi.product_id
		LEFT JOIN category_translation t ON  t.product_category_name = p.product_category_name
		) x
		WHERE rn = 1
)
SELECT o.order_id,
	   lr.review_score,
	   (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) AS is_late,
       o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date  AS days_late,
       o.order_delivered_customer_date::date - o.order_purchase_timestamp::date       AS days_to_deliver,
       o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date       AS days_promised,
       c.customer_state,
       ot.order_price,
       ot.order_freight,
       ot.n_items,
       ot.n_sellers,
       mc.category,
       DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month
FROM orders o
JOIN customers     c  ON c.customer_id = o.customer_id
JOIN latest_review lr ON lr.order_id   = o.order_id
JOIN order_totals  ot ON ot.order_id   = o.order_id
JOIN main_category mc ON mc.order_id   = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

SELECT COUNT(*),
       COUNT(DISTINCT order_id),
       ROUND(AVG(review_score) FILTER (WHERE is_late), 2)     AS late_avg,
       ROUND(AVG(review_score) FILTER (WHERE NOT is_late), 2) AS ontime_avg
FROM analysis_orders;





