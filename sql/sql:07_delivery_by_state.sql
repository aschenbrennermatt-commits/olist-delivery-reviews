WITH delivered AS (
	SELECT c.customer_state,
		o.order_delivered_customer_date::date
		  - o.order_purchase_timestamp::date AS days_to_deliver,
		o.order_estimated_delivery_date::date
		  - o.order_purchase_timestamp::date AS days_promised,
		(o.order_delivered_customer_date::date
		  > o.order_estimated_delivery_date::date) AS is_late
	FROM orders o
	JOIN customers c ON c.customer_id = o.customer_id
	WHERE o.order_status = 'delivered'
	   AND o.order_delivered_customer_date IS NOT NULL
)
SELECT customer_state,
	COUNT(*) AS orders,
	ROUND(AVG(days_to_deliver), 1) AS avg_days,
	ROUND(AVG(days_promised), 1) AS avg_promised,
	ROUND(100.0 * AVG(is_late::int), 1) AS pct_late,
	ROUND(AVG(days_promised - days_to_deliver), 1) AS avg_buffer
FROM delivered
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY pct_late DESC;