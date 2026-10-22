-- E-commerce analytics schema (PostgreSQL 14+).
-- Star schema: order_items is the fact grain, with customer/product/category
-- dimensions, a web_events clickstream for funnel analysis, and a returns table.
-- unit_price lives on the line item (price actually paid); products carry
-- cost_price so revenue queries can also report margin.

DROP TABLE IF EXISTS returns        CASCADE;
DROP TABLE IF EXISTS web_events     CASCADE;
DROP TABLE IF EXISTS order_items    CASCADE;
DROP TABLE IF EXISTS orders         CASCADE;
DROP TABLE IF EXISTS products       CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS customers      CASCADE;

CREATE TABLE customers (
    customer_id         INTEGER PRIMARY KEY,
    signup_date         DATE    NOT NULL,
    country             TEXT    NOT NULL,
    city                TEXT    NOT NULL,
    acquisition_channel TEXT    NOT NULL
        CHECK (acquisition_channel IN
               ('Organic Search','Paid Search','Social','Email','Referral','Direct')),
    age_group           TEXT    NOT NULL
);

CREATE TABLE product_categories (
    category_id   INTEGER PRIMARY KEY,
    category_name TEXT    NOT NULL UNIQUE
);

CREATE TABLE products (
    product_id   INTEGER       PRIMARY KEY,
    product_name TEXT          NOT NULL,
    category_id  INTEGER       NOT NULL REFERENCES product_categories(category_id),
    cost_price   NUMERIC(10,2) NOT NULL CHECK (cost_price >= 0),
    list_price   NUMERIC(10,2) NOT NULL CHECK (list_price  >= 0),
    launch_date  DATE          NOT NULL
);

CREATE TABLE orders (
    order_id        INTEGER       PRIMARY KEY,
    customer_id     INTEGER       NOT NULL REFERENCES customers(customer_id),
    order_date      DATE          NOT NULL,
    order_status    TEXT          NOT NULL
        CHECK (order_status IN ('completed','cancelled','returned')),
    payment_method  TEXT          NOT NULL
        CHECK (payment_method IN ('Credit Card','Debit Card','PayPal','Wallet','COD')),
    shipping_cost   NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0)
);

CREATE TABLE order_items (
    order_item_id BIGINT        PRIMARY KEY,
    order_id      INTEGER       NOT NULL REFERENCES orders(order_id),
    product_id    INTEGER       NOT NULL REFERENCES products(product_id),
    quantity      INTEGER       NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    UNIQUE (order_id, product_id)   -- one line per product per order
);

-- customer_id is null for anonymous (pre-login) sessions.
CREATE TABLE web_events (
    event_id    BIGINT    PRIMARY KEY,
    session_id  TEXT      NOT NULL,
    customer_id INTEGER   REFERENCES customers(customer_id),
    event_type  TEXT      NOT NULL
        CHECK (event_type IN ('page_view','add_to_cart','checkout','purchase')),
    product_id  INTEGER   REFERENCES products(product_id),
    event_ts    TIMESTAMP NOT NULL
);

CREATE TABLE returns (
    return_id     BIGINT        PRIMARY KEY,
    order_item_id BIGINT        NOT NULL REFERENCES order_items(order_item_id),
    return_date   DATE          NOT NULL,
    return_reason TEXT          NOT NULL
        CHECK (return_reason IN
               ('Defective','Wrong Item','Not as Described','No Longer Needed','Size/Fit')),
    refund_amount NUMERIC(10,2) NOT NULL CHECK (refund_amount >= 0)
);

CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_date       ON orders(order_date);
CREATE INDEX idx_orders_status     ON orders(order_status);
CREATE INDEX idx_items_order       ON order_items(order_id);
CREATE INDEX idx_items_product     ON order_items(product_id);
CREATE INDEX idx_events_session    ON web_events(session_id);
CREATE INDEX idx_events_type_ts    ON web_events(event_type, event_ts);
CREATE INDEX idx_events_customer   ON web_events(customer_id);
CREATE INDEX idx_returns_item      ON returns(order_item_id);
CREATE INDEX idx_customers_signup  ON customers(signup_date);
CREATE INDEX idx_products_category ON products(category_id);
