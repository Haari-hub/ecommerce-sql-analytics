-- Revenue trends: MoM and YoY growth, running totals, smoothed trend.
-- Revenue = SUM(quantity * unit_price) for 'completed'/'returned' orders;
-- cancelled orders are excluded throughout.

-- Monthly revenue with MoM growth, a running total, and a 3-month moving average.
WITH monthly AS (
    SELECT
        date_trunc('month', o.order_date)::date AS month,
        SUM(oi.quantity * oi.unit_price)        AS gross_revenue,
        COUNT(DISTINCT o.order_id)              AS orders
    FROM orders o
    JOIN order_items oi USING (order_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY 1
)
SELECT
    to_char(month, 'YYYY-Mon')               AS month_label,  -- aliased so ORDER BY still uses the date
    gross_revenue,
    orders,
    round(100.0 * (gross_revenue - LAG(gross_revenue) OVER (ORDER BY month))
          / NULLIF(LAG(gross_revenue) OVER (ORDER BY month), 0), 1) AS mom_growth_pct,
    SUM(gross_revenue) OVER (ORDER BY month)  AS running_total,
    round(AVG(gross_revenue) OVER (
        ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS moving_avg_3mo
FROM monthly
ORDER BY month;


-- Year-over-year growth: each month vs the same month a year earlier (LAG 12).
WITH monthly AS (
    SELECT date_trunc('month', o.order_date)::date AS month,
           SUM(oi.quantity * oi.unit_price)        AS revenue
    FROM orders o JOIN order_items oi USING (order_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY 1
)
SELECT
    to_char(month, 'Mon')                  AS calendar_month,
    extract(year FROM month)::int          AS yr,
    revenue,
    LAG(revenue, 12) OVER (ORDER BY month) AS revenue_prior_year,
    round(100.0 * (revenue - LAG(revenue, 12) OVER (ORDER BY month))
          / NULLIF(LAG(revenue, 12) OVER (ORDER BY month), 0), 1) AS yoy_growth_pct
FROM monthly
ORDER BY month;


-- Quarterly revenue and each quarter's share of its year.
WITH quarterly AS (
    SELECT
        extract(year FROM o.order_date)::int           AS yr,
        'Q' || extract(quarter FROM o.order_date)::int AS qtr,
        SUM(oi.quantity * oi.unit_price)               AS revenue
    FROM orders o JOIN order_items oi USING (order_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY 1, 2
)
SELECT
    yr, qtr, revenue,
    round(100.0 * revenue / SUM(revenue) OVER (PARTITION BY yr), 1) AS pct_of_year,
    RANK() OVER (PARTITION BY yr ORDER BY revenue DESC)            AS qtr_rank_in_year
FROM quarterly
ORDER BY yr, qtr;
