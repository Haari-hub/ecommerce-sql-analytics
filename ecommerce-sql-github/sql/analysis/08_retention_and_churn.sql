-- Retention and churn. Recency-based status (standard for non-subscription retail):
--   Active  = ordered in the last 90 days
--   Lapsed  = last order 91-180 days ago
--   Churned = no order in over 180 days
-- Measured as-of the day after the last order in the data.

-- Lifecycle status and the revenue sitting in each bucket (win-back sizing).
WITH snapshot AS (SELECT (MAX(order_date) + 1)::date AS as_of_date FROM orders),
customer_last AS (
    SELECT
        o.customer_id,
        MAX(o.order_date)                                     AS last_order,
        (SELECT as_of_date FROM snapshot) - MAX(o.order_date) AS recency_days,
        SUM(oi.quantity * oi.unit_price)                      AS lifetime_revenue
    FROM orders o
    JOIN order_items oi USING (order_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY o.customer_id
),
status AS (
    SELECT *,
        CASE WHEN recency_days <= 90  THEN '1. Active (<=90d)'
             WHEN recency_days <= 180 THEN '2. Lapsed (91-180d)'
             ELSE '3. Churned (>180d)' END AS lifecycle_status
    FROM customer_last
)
SELECT
    lifecycle_status,
    COUNT(*)                                          AS customers,
    round(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_customers,
    round(SUM(lifetime_revenue), 0)                   AS revenue_in_group,
    round(100.0 * SUM(lifetime_revenue) / SUM(SUM(lifetime_revenue)) OVER (), 1) AS pct_of_revenue
FROM status
GROUP BY lifecycle_status
ORDER BY lifecycle_status;


-- Repeat-purchase rate: what share of customers order more than once.
WITH per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS orders
    FROM orders WHERE order_status <> 'cancelled' GROUP BY customer_id
)
SELECT
    COUNT(*)                                          AS total_customers,
    COUNT(*) FILTER (WHERE orders = 1)                AS one_time_buyers,
    COUNT(*) FILTER (WHERE orders >= 2)               AS repeat_buyers,
    round(100.0 * COUNT(*) FILTER (WHERE orders >= 2) / COUNT(*), 1) AS repeat_purchase_rate_pct,
    round(AVG(orders), 2)                             AS avg_orders_per_customer
FROM per_customer;


-- Days between consecutive orders, by gap number (1st->2nd, 2nd->3rd, ...).
-- Uses LAG over each customer's ordered purchase history.
WITH customer_orders AS (
    SELECT
        customer_id,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_seq,
        order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)
            AS days_since_prev
    FROM (SELECT DISTINCT customer_id, order_date
          FROM orders WHERE order_status <> 'cancelled') d
)
SELECT
    order_seq - 1                           AS gap_number,
    (order_seq - 1) || ' -> ' || order_seq  AS between_orders,
    COUNT(*)                                AS num_gaps,
    round(AVG(days_since_prev), 1)          AS avg_days_between,
    round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_since_prev))::numeric, 0)
                                            AS median_days_between
FROM customer_orders
WHERE days_since_prev IS NOT NULL
  AND order_seq <= 6
GROUP BY order_seq
ORDER BY order_seq;
