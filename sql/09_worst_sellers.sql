-- Worst 10 sellers by average review (delivered orders, sellers with 30+ orders)

WITH seller_stats AS(
	SELECT oi.seller_id,
		COUNT(DISTINCT oi.order_id) AS orders,
		ROUND(SUM(oi.price), 2) AS gmv,
		ROUND(AVG(r.review_score), 2) AS avg_review
	FROM order_items oi
	JOIN orders o ON o.order_id = oi.order_id
	JOIN order_reviews r ON r.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
	GROUP BY oi.seller_id
	HAVING COUNT(DISTINCT oi.order_id) >= 30
)
SELECT seller_id,
	orders,
	gmv,
	avg_review,
	RANK() OVER(ORDER BY avg_review ASC) AS review_rank
FROM seller_stats
ORDER BY review_rank
LIMIT 10;