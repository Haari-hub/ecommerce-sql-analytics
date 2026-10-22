-- Conversion funnel from the web_events clickstream.
-- Stages in order: page_view -> add_to_cart -> checkout -> purchase.

-- Overall funnel with step-over-step conversion and drop-off.
WITH session_funnel AS (
    SELECT
        session_id,
        MAX((event_type = 'page_view')::int)   AS reached_view,
        MAX((event_type = 'add_to_cart')::int) AS reached_cart,
        MAX((event_type = 'checkout')::int)    AS reached_checkout,
        MAX((event_type = 'purchase')::int)    AS reached_purchase
    FROM web_events
    GROUP BY session_id
),
stage_counts AS (
    SELECT 1 AS step_order, 'View'        AS stage, SUM(reached_view)     AS sessions FROM session_funnel
    UNION ALL SELECT 2, 'Add to Cart', SUM(reached_cart)     FROM session_funnel
    UNION ALL SELECT 3, 'Checkout',    SUM(reached_checkout) FROM session_funnel
    UNION ALL SELECT 4, 'Purchase',    SUM(reached_purchase) FROM session_funnel
)
SELECT
    stage,
    sessions,
    round(100.0 * sessions / FIRST_VALUE(sessions) OVER (ORDER BY step_order), 1)    AS pct_of_top,
    round(100.0 * sessions / NULLIF(LAG(sessions) OVER (ORDER BY step_order), 0), 1) AS step_conversion_pct,
    LAG(sessions) OVER (ORDER BY step_order) - sessions                              AS dropped_from_prev
FROM stage_counts
ORDER BY step_order;


-- Funnel by acquisition channel (logged-in sessions only).
WITH session_funnel AS (
    SELECT
        we.session_id,
        c.acquisition_channel,
        MAX((we.event_type = 'page_view')::int)   AS reached_view,
        MAX((we.event_type = 'add_to_cart')::int) AS reached_cart,
        MAX((we.event_type = 'checkout')::int)    AS reached_checkout,
        MAX((we.event_type = 'purchase')::int)    AS reached_purchase
    FROM web_events we
    JOIN customers c ON c.customer_id = we.customer_id   -- drops anonymous sessions
    GROUP BY we.session_id, c.acquisition_channel
)
SELECT
    acquisition_channel,
    SUM(reached_view)                                          AS sessions,
    SUM(reached_cart)                                          AS carted,
    SUM(reached_purchase)                                      AS purchased,
    round(100.0 * SUM(reached_cart)     / SUM(reached_view), 1) AS view_to_cart_pct,
    round(100.0 * SUM(reached_purchase) / SUM(reached_view), 1) AS view_to_purchase_pct
FROM session_funnel
GROUP BY acquisition_channel
ORDER BY view_to_purchase_pct DESC;


-- Cart abandonment: did they drop at the cart, or later at the payment page?
WITH session_funnel AS (
    SELECT session_id,
        MAX((event_type = 'add_to_cart')::int) AS reached_cart,
        MAX((event_type = 'checkout')::int)    AS reached_checkout,
        MAX((event_type = 'purchase')::int)    AS reached_purchase
    FROM web_events GROUP BY session_id
)
SELECT
    COUNT(*) FILTER (WHERE reached_cart = 1)                          AS sessions_with_cart,
    COUNT(*) FILTER (WHERE reached_cart = 1 AND reached_purchase = 0) AS abandoned_total,
    COUNT(*) FILTER (WHERE reached_cart = 1 AND reached_checkout = 1
                        AND reached_purchase = 0)                     AS abandoned_at_payment,
    COUNT(*) FILTER (WHERE reached_cart = 1 AND reached_checkout = 0) AS abandoned_at_cart,
    round(100.0 * COUNT(*) FILTER (WHERE reached_cart = 1 AND reached_purchase = 0)
          / NULLIF(COUNT(*) FILTER (WHERE reached_cart = 1), 0), 1)   AS cart_abandonment_rate_pct
FROM session_funnel;
