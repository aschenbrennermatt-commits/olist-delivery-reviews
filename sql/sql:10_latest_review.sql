WITH ranked_reviews AS(
		SELECT order_id,
			   review_score,
			   review_answer_timestamp,
			   ROW_NUMBER() OVER (
					PARTITION BY order_id
					ORDER BY review_answer_timestamp DESC, review_id
			   ) AS rn
	    FROM order_reviews
	)
	SELECT order_id, review_score, review_answer_timestamp
	FROM ranked_reviews
	WHERE rn = 1;