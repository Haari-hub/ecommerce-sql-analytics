-- Market basket analysis: which categories get bought together, via the three
-- association-rule metrics for a pair (A, B):
--   support(A,B)    = orders with both / all orders
--   confidence(A->B)= orders with both / orders with A
--   lift(A,B)       = confidence / support(B)   (> 1 means genuine affinity)

-- Category pairs ranked by lift.
WITH order_categories AS (
    SELECT DISTINCT o.order_id, p.category_id
    FROM orders o
    JOIN order_items oi USING (order_id)
    JOIN products p     USING (product_id)
    WHERE o.order_status IN ('completed', 'returned')
),
total_orders AS (
    SELECT COUNT(DISTINCT order_id) AS n FROM order_categories
),
cat_counts AS (
    SELECT category_id, COUNT(DISTINCT order_id) AS orders_with_cat
    FROM order_categories GROUP BY category_id
),
pairs AS (
    -- a.category_id < b.category_id keeps each unordered pair once.
    SELECT a.category_id AS cat_a, b.category_id AS cat_b, COUNT(*) AS orders_together
    FROM order_categories a
    JOIN order_categories b ON a.order_id = b.order_id AND a.category_id < b.category_id
    GROUP BY a.category_id, b.category_id
)
SELECT
    ca.category_name AS category_a,
    cb.category_name AS category_b,
    p.orders_together,
    round(100.0 * p.orders_together / t.n, 2)                AS support_pct,
    round(100.0 * p.orders_together / cca.orders_with_cat, 1) AS confidence_a_to_b_pct,
    round((p.orders_together::numeric / cca.orders_with_cat)
          / (ccb.orders_with_cat::numeric / t.n), 2)         AS lift
FROM pairs p
CROSS JOIN total_orders t
JOIN cat_counts cca ON cca.category_id = p.cat_a
JOIN cat_counts ccb ON ccb.category_id = p.cat_b
JOIN product_categories ca ON ca.category_id = p.cat_a
JOIN product_categories cb ON cb.category_id = p.cat_b
WHERE p.orders_together >= 50   -- drop rare, noisy pairs
ORDER BY lift DESC
LIMIT 15;


-- Drill into the top category: products most often bought alongside Accessories.
WITH orders_with_accessories AS (
    SELECT DISTINCT o.order_id
    FROM orders o
    JOIN order_items oi USING (order_id)
    JOIN products p     USING (product_id)
    JOIN product_categories pc USING (category_id)
    WHERE o.order_status IN ('completed', 'returned')
      AND pc.category_name = 'Accessories'
)
SELECT
    p.product_name,
    pc.category_name,
    COUNT(DISTINCT oi.order_id) AS co_purchase_orders
FROM orders_with_accessories oa
JOIN order_items oi USING (order_id)
JOIN products p     USING (product_id)
JOIN product_categories pc USING (category_id)
WHERE pc.category_name <> 'Accessories'
GROUP BY p.product_name, pc.category_name
ORDER BY co_purchase_orders DESC
LIMIT 10;
