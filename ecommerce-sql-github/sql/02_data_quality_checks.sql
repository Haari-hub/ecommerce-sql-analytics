-- Data quality checks. Each query returns zero rows if the data is clean;
-- run after loading, before trusting any analysis.

-- Referential integrity: no child rows pointing at a missing parent.
SELECT 'order_items -> orders (orphans)' AS check_name, count(*) AS bad_rows
FROM order_items oi LEFT JOIN orders o USING (order_id)
WHERE o.order_id IS NULL
HAVING count(*) > 0
UNION ALL
SELECT 'returns -> order_items (orphans)', count(*)
FROM returns r LEFT JOIN order_items oi USING (order_item_id)
WHERE oi.order_item_id IS NULL
HAVING count(*) > 0;

-- An order cannot predate the customer's signup.
SELECT 'orders before customer signup' AS check_name, count(*) AS bad_rows
FROM orders o JOIN customers c USING (customer_id)
WHERE o.order_date < c.signup_date
HAVING count(*) > 0;

-- Cancelled orders should have no returns (nothing shipped).
SELECT 'returns against cancelled orders' AS check_name, count(*) AS bad_rows
FROM returns r
JOIN order_items oi USING (order_item_id)
JOIN orders o USING (order_id)
WHERE o.order_status = 'cancelled'
HAVING count(*) > 0;

-- Prices and quantities positive.
SELECT 'non-positive price or quantity' AS check_name, count(*) AS bad_rows
FROM order_items WHERE unit_price <= 0 OR quantity <= 0
HAVING count(*) > 0;

-- Line-item natural key is unique.
SELECT 'duplicate (order_id, product_id, qty, price)' AS check_name,
       count(*) - count(DISTINCT (order_id, product_id, quantity, unit_price)) AS bad_rows
FROM order_items
HAVING count(*) - count(DISTINCT (order_id, product_id, quantity, unit_price)) > 0;

-- A purchase event implies the session also reached checkout.
SELECT 'purchase without checkout in session' AS check_name, count(*) AS bad_rows
FROM (
    SELECT session_id,
           max((event_type = 'checkout')::int) AS has_checkout,
           max((event_type = 'purchase')::int) AS has_purchase
    FROM web_events GROUP BY session_id
) s
WHERE has_purchase = 1 AND has_checkout = 0
HAVING count(*) > 0;

SELECT 'ALL CHECKS PASSED' AS result;
