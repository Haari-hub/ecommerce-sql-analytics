-- Cohort retention: group customers by the month of their first order, then
-- track what share come back in each later month. The grid is triangular —
-- a cohort has no month_N value until N months have actually elapsed.

-- Retention grid: % of each cohort active N months after their first order.
WITH first_purchase AS (
    SELECT customer_id, date_trunc('month', MIN(order_date))::date AS cohort_month
    FROM orders
    WHERE order_status <> 'cancelled'
    GROUP BY customer_id
),
activity AS (
    -- Whole months between each order and the customer's cohort month.
    SELECT
        fp.cohort_month,
        o.customer_id,
        (extract(year  FROM o.order_date) - extract(year  FROM fp.cohort_month)) * 12
      + (extract(month FROM o.order_date) - extract(month FROM fp.cohort_month)) AS month_offset
    FROM orders o
    JOIN first_purchase fp USING (customer_id)
    WHERE o.order_status <> 'cancelled'
),
cohort_meta AS (
    -- Cohort size and how many months have elapsed since it formed (for the NULL guard).
    SELECT
        fp.cohort_month,
        COUNT(*) AS cohort_size,
        (extract(year  FROM b.max_month) - extract(year  FROM fp.cohort_month)) * 12
      + (extract(month FROM b.max_month) - extract(month FROM fp.cohort_month)) AS months_elapsed
    FROM first_purchase fp
    CROSS JOIN (SELECT date_trunc('month', MAX(order_date))::date AS max_month FROM orders) b
    GROUP BY fp.cohort_month, b.max_month
)
SELECT
    to_char(a.cohort_month, 'YYYY-Mon') AS cohort,
    cm.cohort_size,
    CASE WHEN cm.months_elapsed >= 1 THEN
        round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_offset = 1)
              / cm.cohort_size, 1) END AS month_1,
    CASE WHEN cm.months_elapsed >= 2 THEN
        round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_offset = 2)
              / cm.cohort_size, 1) END AS month_2,
    CASE WHEN cm.months_elapsed >= 3 THEN
        round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_offset = 3)
              / cm.cohort_size, 1) END AS month_3,
    CASE WHEN cm.months_elapsed >= 6 THEN
        round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_offset = 6)
              / cm.cohort_size, 1) END AS month_6
FROM activity a
JOIN cohort_meta cm USING (cohort_month)
GROUP BY a.cohort_month, cm.cohort_size, cm.months_elapsed
ORDER BY a.cohort_month;


-- Headline retention curve, all cohorts combined.
WITH first_purchase AS (
    SELECT customer_id, date_trunc('month', MIN(order_date))::date AS cohort_month
    FROM orders WHERE order_status <> 'cancelled' GROUP BY customer_id
),
activity AS (
    SELECT o.customer_id,
        (extract(year FROM o.order_date) - extract(year FROM fp.cohort_month)) * 12
      + (extract(month FROM o.order_date) - extract(month FROM fp.cohort_month)) AS month_offset
    FROM orders o JOIN first_purchase fp USING (customer_id)
    WHERE o.order_status <> 'cancelled'
),
total AS (SELECT COUNT(*) AS n FROM first_purchase)
SELECT
    month_offset,
    COUNT(DISTINCT customer_id) AS customers_active,
    round(100.0 * COUNT(DISTINCT customer_id) / (SELECT n FROM total), 1) AS pct_of_all_customers
FROM activity
WHERE month_offset BETWEEN 0 AND 12
GROUP BY month_offset
ORDER BY month_offset;


-- 3-month repeat rate by acquisition channel — which channels bring customers
-- who come back, not just cheap first orders.
WITH first_purchase AS (
    SELECT customer_id, date_trunc('month', MIN(order_date))::date AS cohort_month
    FROM orders WHERE order_status <> 'cancelled' GROUP BY customer_id
),
retained_m3 AS (
    SELECT fp.customer_id,
        MAX(CASE WHEN (extract(year FROM o.order_date) - extract(year FROM fp.cohort_month)) * 12
                    + (extract(month FROM o.order_date) - extract(month FROM fp.cohort_month))
                 BETWEEN 1 AND 3 THEN 1 ELSE 0 END) AS active_by_m3
    FROM first_purchase fp
    JOIN orders o ON o.customer_id = fp.customer_id AND o.order_status <> 'cancelled'
    GROUP BY fp.customer_id
)
SELECT
    c.acquisition_channel,
    COUNT(*)                                         AS customers,
    SUM(r.active_by_m3)                              AS retained_within_3mo,
    round(100.0 * SUM(r.active_by_m3) / COUNT(*), 1) AS retention_3mo_pct
FROM retained_m3 r
JOIN customers c USING (customer_id)
GROUP BY c.acquisition_channel
ORDER BY retention_3mo_pct DESC;
