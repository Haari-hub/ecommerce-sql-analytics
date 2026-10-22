-- Customer lifetime value. LTV breaks down into three levers: order frequency,
-- average order value, and margin per order. Margin = unit_price - cost_price.

-- LTV by acquisition channel, decomposed into its drivers.
WITH order_value AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(oi.quantity * oi.unit_price)                  AS order_revenue,
        SUM(oi.quantity * (oi.unit_price - p.cost_price)) AS order_margin
    FROM orders o
    JOIN order_items oi USING (order_id)
    JOIN products p     USING (product_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY o.order_id, o.customer_id
),
customer_value AS (
    SELECT
        customer_id,
        COUNT(*)           AS orders,
        SUM(order_revenue) AS lifetime_revenue,
        SUM(order_margin)  AS lifetime_margin,
        AVG(order_revenue) AS avg_order_value
    FROM order_value
    GROUP BY customer_id
)
SELECT
    c.acquisition_channel,
    COUNT(*)                            AS customers,
    round(AVG(cv.orders), 2)            AS avg_orders_per_cust,
    round(AVG(cv.avg_order_value), 2)   AS avg_order_value,
    round(AVG(cv.lifetime_revenue), 2)  AS avg_ltv_revenue,
    round(AVG(cv.lifetime_margin), 2)   AS avg_ltv_margin,
    round(SUM(cv.lifetime_margin), 0)   AS total_margin
FROM customer_value cv
JOIN customers c USING (customer_id)
GROUP BY c.acquisition_channel
ORDER BY avg_ltv_margin DESC;


-- AOV by quarter, split by new vs returning customers.
WITH first_order AS (
    SELECT customer_id, MIN(order_date) AS first_dt
    FROM orders WHERE order_status <> 'cancelled' GROUP BY customer_id
),
order_value AS (
    SELECT
        o.order_id, o.customer_id, o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_revenue,
        CASE WHEN o.order_date = fo.first_dt THEN 'New' ELSE 'Returning' END AS customer_type
    FROM orders o
    JOIN order_items oi USING (order_id)
    JOIN first_order fo USING (customer_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY o.order_id, o.customer_id, o.order_date, fo.first_dt
)
SELECT
    to_char(date_trunc('quarter', order_date), 'YYYY-"Q"Q') AS quarter,
    customer_type,
    COUNT(*)                    AS orders,
    round(AVG(order_revenue), 2) AS avg_order_value
FROM order_value
GROUP BY date_trunc('quarter', order_date), customer_type
ORDER BY date_trunc('quarter', order_date), customer_type;


-- Cumulative LTV by cohort age: average revenue per customer accrued by month N.
WITH first_order AS (
    SELECT customer_id, date_trunc('month', MIN(order_date))::date AS cohort_month
    FROM orders WHERE order_status <> 'cancelled' GROUP BY customer_id
),
monthly_rev AS (
    SELECT
        fo.cohort_month,
        (extract(year FROM o.order_date) - extract(year FROM fo.cohort_month)) * 12
      + (extract(month FROM o.order_date) - extract(month FROM fo.cohort_month)) AS age_months,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi USING (order_id)
    JOIN first_order fo USING (customer_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY fo.cohort_month, age_months
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS n FROM first_order GROUP BY cohort_month
),
cumulative AS (
    SELECT
        mr.cohort_month, mr.age_months,
        SUM(mr.revenue) OVER (PARTITION BY mr.cohort_month ORDER BY mr.age_months) / cs.n
            AS cum_rev_per_customer
    FROM monthly_rev mr JOIN cohort_size cs USING (cohort_month)
)
SELECT
    age_months,
    round(AVG(cum_rev_per_customer), 2) AS avg_cumulative_ltv_per_customer
FROM cumulative
WHERE age_months IN (0, 1, 2, 3, 6, 12)
GROUP BY age_months
ORDER BY age_months;
