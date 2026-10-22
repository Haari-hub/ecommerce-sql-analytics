-- RFM segmentation. Score each customer 1-5 on Recency (days since last order),
-- Frequency (order count) and Monetary (total revenue) with NTILE, then map the
-- score combination to a named segment. Recency measured as-of the day after the
-- last order in the data.

-- Per-customer RFM scores and segment (top 20 by spend).
WITH snapshot AS (
    SELECT (MAX(order_date) + 1)::date AS as_of_date FROM orders
),
customer_metrics AS (
    SELECT
        o.customer_id,
        (SELECT as_of_date FROM snapshot) - MAX(o.order_date) AS recency_days,
        COUNT(DISTINCT o.order_id)                            AS frequency,
        SUM(oi.quantity * oi.unit_price)                      AS monetary
    FROM orders o
    JOIN order_items oi USING (order_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT
        customer_id, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- lower recency = higher score
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM customer_metrics
)
SELECT
    customer_id, recency_days, frequency, monetary,
    r_score, f_score, m_score,
    (r_score::text || f_score::text || m_score::text) AS rfm_cell,
    CASE
        WHEN r_score >= 4 AND f_score >= 4                  THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 4                  THEN 'At Risk (was valuable)'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 4 THEN 'Cannot Lose Them'
        WHEN r_score <= 2 AND f_score <= 2                  THEN 'Hibernating / Churned'
        ELSE 'Needs Attention'
    END AS segment
FROM rfm_scores
ORDER BY monetary DESC
LIMIT 20;


-- Segment summary: customer count and revenue share per segment.
WITH snapshot AS (SELECT (MAX(order_date) + 1)::date AS as_of_date FROM orders),
customer_metrics AS (
    SELECT o.customer_id,
        (SELECT as_of_date FROM snapshot) - MAX(o.order_date) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.quantity * oi.unit_price) AS monetary
    FROM orders o JOIN order_items oi USING (order_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY o.customer_id
),
rfm AS (
    SELECT customer_id, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM customer_metrics
),
labelled AS (
    SELECT customer_id, monetary,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
            WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk (was valuable)'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 4 THEN 'Cannot Lose Them'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating / Churned'
            ELSE 'Needs Attention'
        END AS segment
    FROM rfm
)
SELECT
    segment,
    COUNT(*)                                                    AS customers,
    round(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_customers,
    round(SUM(monetary), 0)                                     AS total_revenue,
    round(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
    round(AVG(monetary), 0)                                     AS avg_customer_value
FROM labelled
GROUP BY segment
ORDER BY total_revenue DESC;
