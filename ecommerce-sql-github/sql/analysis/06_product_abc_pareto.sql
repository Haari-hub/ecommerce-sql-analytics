-- Product ABC / Pareto analysis. Rank products by revenue and bucket them:
-- A = top 80% of revenue, B = next 15%, C = last 5%. Margin is tracked too,
-- since high revenue at thin margin isn't the same as a profitable product.

-- ABC classes: how few products make up most of the revenue.
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        pc.category_name,
        SUM(oi.quantity * oi.unit_price)                  AS revenue,
        SUM(oi.quantity * (oi.unit_price - p.cost_price)) AS margin
    FROM order_items oi
    JOIN orders o   USING (order_id)
    JOIN products p USING (product_id)
    JOIN product_categories pc USING (category_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY p.product_id, p.product_name, pc.category_name
),
ranked AS (
    SELECT *,
        SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cum_revenue_share
    FROM product_revenue
),
classified AS (
    SELECT *,
        CASE WHEN cum_revenue_share <= 0.80 THEN 'A'
             WHEN cum_revenue_share <= 0.95 THEN 'B'
             ELSE 'C' END AS abc_class
    FROM ranked
)
SELECT
    abc_class,
    COUNT(*)                                                   AS products,
    round(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)         AS pct_of_products,
    round(SUM(revenue), 0)                                     AS revenue,
    round(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue,
    round(SUM(margin), 0)                                      AS margin,
    round(100.0 * SUM(margin) / NULLIF(SUM(revenue), 0), 1)    AS margin_pct
FROM classified
GROUP BY abc_class
ORDER BY abc_class;


-- Top 10 products by revenue, with running cumulative share.
WITH product_revenue AS (
    SELECT p.product_id, p.product_name, pc.category_name,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN orders o USING (order_id)
    JOIN products p USING (product_id)
    JOIN product_categories pc USING (category_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY p.product_id, p.product_name, pc.category_name
)
SELECT
    ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rank,
    product_name,
    category_name,
    round(revenue, 0)                         AS revenue,
    round(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
          / SUM(revenue) OVER (), 1)          AS cumulative_pct_of_revenue
FROM product_revenue
ORDER BY revenue DESC
LIMIT 10;


-- Category scorecard: revenue, margin % and return rate side by side, plus
-- revenue net of refunds (the number that reaches the P&L).
WITH cat_sales AS (
    SELECT
        pc.category_id, pc.category_name,
        SUM(oi.quantity * oi.unit_price)                  AS revenue,
        SUM(oi.quantity * (oi.unit_price - p.cost_price)) AS margin,
        COUNT(oi.order_item_id)                           AS line_items
    FROM order_items oi
    JOIN orders o   USING (order_id)
    JOIN products p USING (product_id)
    JOIN product_categories pc USING (category_id)
    WHERE o.order_status IN ('completed', 'returned')
    GROUP BY pc.category_id, pc.category_name
),
cat_returns AS (
    SELECT p.category_id,
        COUNT(r.return_id)   AS returns,
        SUM(r.refund_amount) AS refunds
    FROM returns r
    JOIN order_items oi USING (order_item_id)
    JOIN products p     USING (product_id)
    GROUP BY p.category_id
)
SELECT
    cs.category_name,
    round(cs.revenue, 0)                                     AS revenue,
    round(100.0 * cs.margin / NULLIF(cs.revenue, 0), 1)      AS margin_pct,
    round(100.0 * COALESCE(cr.returns, 0) / cs.line_items, 1) AS return_rate_pct,
    round(COALESCE(cr.refunds, 0), 0)                        AS refunds,
    round(cs.revenue - COALESCE(cr.refunds, 0), 0)           AS net_revenue
FROM cat_sales cs
LEFT JOIN cat_returns cr USING (category_id)
ORDER BY revenue DESC;
