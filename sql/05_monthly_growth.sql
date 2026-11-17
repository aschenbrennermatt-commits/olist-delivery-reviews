-- Month-over-month GMV growth (absolute and %), plus a daily check confirming the Nov 2017 Black Friday spike

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
),

monthly AS (
	SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
	  	   COUNT(*) AS orders,
		   SUM(revenue) AS gmv
	FROM order_revenue
	GROUP BY month
)

SELECT month,
	orders, 
	ROUND(gmv, 2) AS gmv,
	ROUND(LAG(gmv) OVER(ORDER BY month), 2) AS prev_month_gmv,
	ROUND(gmv - LAG(gmv) OVER (ORDER BY month), 2) AS abs_change,
	ROUND(100.0 * (gmv - LAG(gmv) OVER (ORDER BY month))
				/ LAG(gmv) OVER (ORDER BY month), 1) AS pct_change
FROM monthly
ORDER BY month;

-- Daily orders in Nov 2017: was 24 Nov (Black Friday) the peak?

SELECT order_purchase_timestamp::date AS day,
	COUNT(*) AS orders
FROM orders 
WHERE order_purchase_timestamp >= '2017-11-01'
	AND order_purchase_timestamp < '2017-12-01'
GROUP BY day
ORDER BY orders DESC
LIMIT 5;