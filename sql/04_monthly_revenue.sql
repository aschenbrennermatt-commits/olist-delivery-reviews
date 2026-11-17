-- Monthly GMV (item prices, excl. canceled/unavailable), Jan 2017 – Aug 2018, with delivered-only comparison

WITH order_revenue AS (
	SELECT o.order_id,
		   o.order_purchase_timestamp,
		   o.order_status,
		   SUM(oi.price) AS revenue
	FROM orders o
	JOIN order_items oi ON oi.order_id = o.order_id
	WHERE o.order_status NOT IN ('canceled', 'unavailable')
	  AND o.order_purchase_timestamp >= '2017-01-01'
	  AND o.order_purchase_timestamp < '2018-09-01'
	GROUP BY o.order_id, o.order_purchase_timestamp, o.order_status
)

SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
	COUNT(*) AS orders,
	ROUND(SUM(revenue), 2) AS gmv,
	ROUND(SUM(revenue) FILTER (WHERE order_status = 'delivered'), 2) AS delivered_only
FROM order_revenue
GROUP BY month
ORDER BY month;

