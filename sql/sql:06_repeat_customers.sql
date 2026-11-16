WITH orders_per_person AS (
	SELECT c.customer_unique_id AS person,
		COUNT(*) AS num_orders
	FROM orders o
	JOIN customers c ON c.customer_id = o.customer_id
	WHERE o.order_status NOT IN ('canceled', 'unavailable')
	GROUP BY c.customer_unique_id
)
SELECT num_orders,
	COUNT(*) AS customers,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM orders_per_person
GROUP BY num_orders
ORDER BY num_orders;