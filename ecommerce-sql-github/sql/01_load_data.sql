-- Load the sample CSVs. Run from the repo root so the relative paths resolve.
-- Load order follows the foreign keys: parents before children.

\copy product_categories FROM 'data/product_categories.csv' WITH (FORMAT csv, HEADER true);
\copy customers          FROM 'data/customers.csv'          WITH (FORMAT csv, HEADER true);
\copy products           FROM 'data/products.csv'           WITH (FORMAT csv, HEADER true);
\copy orders             FROM 'data/orders.csv'             WITH (FORMAT csv, HEADER true);
\copy order_items        FROM 'data/order_items.csv'        WITH (FORMAT csv, HEADER true);
\copy returns            FROM 'data/returns.csv'            WITH (FORMAT csv, HEADER true);
\copy web_events         FROM 'data/web_events.csv'         WITH (FORMAT csv, HEADER true);

ANALYZE;
