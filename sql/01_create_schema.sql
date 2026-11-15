-- =============================================================================
-- 01_create_schema.sql
-- Builds the 9 Olist tables with primary keys, foreign keys and basic checks.
--
-- Run from the repo root:   psql -d olist -f sql/01_create_schema.sql
-- Safe to re-run: it drops the tables first (this deletes any loaded data).
-- =============================================================================

\set ON_ERROR_STOP on

DROP TABLE IF EXISTS
    order_reviews, order_payments, order_items, orders,
    products, sellers, customers, category_translation, geolocation
CASCADE;


-- -----------------------------------------------------------------------------
-- Lookup table: Portuguese category name -> English category name
-- -----------------------------------------------------------------------------
CREATE TABLE category_translation (
    product_category_name          TEXT PRIMARY KEY,
    product_category_name_english  TEXT NOT NULL
);


-- -----------------------------------------------------------------------------
-- Customers
-- Gotcha: customer_id is created fresh for every ORDER. The real person is
-- customer_unique_id. Use customer_unique_id for repeat-customer analysis.
-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id               VARCHAR(32) PRIMARY KEY,
    customer_unique_id        VARCHAR(32) NOT NULL,
    customer_zip_code_prefix  CHAR(5)     NOT NULL,  -- stored as text to keep leading zeros (e.g. 01151)
    customer_city             TEXT        NOT NULL,
    customer_state            CHAR(2)     NOT NULL
);
CREATE INDEX idx_customers_unique_id ON customers (customer_unique_id);


-- -----------------------------------------------------------------------------
-- Sellers
-- -----------------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id               VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix  CHAR(5)     NOT NULL,
    seller_city             TEXT        NOT NULL,
    seller_state            CHAR(2)     NOT NULL
);


-- -----------------------------------------------------------------------------
-- Products
-- The CSV misspells two columns ("lenght"). They are renamed here; COPY loads
-- by column position, so the rename does not affect loading.
-- 610 products have no category, so product_category_name allows NULL.
-- -----------------------------------------------------------------------------
CREATE TABLE products (
    product_id                  VARCHAR(32) PRIMARY KEY,
    product_category_name       TEXT REFERENCES category_translation (product_category_name),
    product_name_length         INTEGER,
    product_description_length  INTEGER,
    product_photos_qty          INTEGER,
    product_weight_g            INTEGER,
    product_length_cm           INTEGER,
    product_height_cm           INTEGER,
    product_width_cm            INTEGER
);
CREATE INDEX idx_products_category ON products (product_category_name);


-- -----------------------------------------------------------------------------
-- Orders: the central table. One row per order.
-- customer_id is UNIQUE because each customer_id belongs to exactly one order.
-- -----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id                       VARCHAR(32) PRIMARY KEY,
    customer_id                    VARCHAR(32) NOT NULL UNIQUE
                                       REFERENCES customers (customer_id),
    order_status                   TEXT        NOT NULL
                                       CHECK (order_status IN ('created', 'approved', 'invoiced',
                                                               'processing', 'shipped', 'delivered',
                                                               'canceled', 'unavailable')),
    order_purchase_timestamp       TIMESTAMP   NOT NULL,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,  -- NULL if not delivered (and for 8 "delivered" orders)
    order_estimated_delivery_date  TIMESTAMP   NOT NULL
);
CREATE INDEX idx_orders_purchase_ts ON orders (order_purchase_timestamp);


-- -----------------------------------------------------------------------------
-- Order items: one row per item in an order.
-- order_item_id is the item's position in the order (1, 2, 3, ...).
-- -----------------------------------------------------------------------------
CREATE TABLE order_items (
    order_id             VARCHAR(32)   NOT NULL REFERENCES orders (order_id),
    order_item_id        SMALLINT      NOT NULL,
    product_id           VARCHAR(32)   NOT NULL REFERENCES products (product_id),
    seller_id            VARCHAR(32)   NOT NULL REFERENCES sellers (seller_id),
    shipping_limit_date  TIMESTAMP     NOT NULL,
    price                NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    freight_value        NUMERIC(10,2) NOT NULL CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);
CREATE INDEX idx_order_items_product ON order_items (product_id);
CREATE INDEX idx_order_items_seller  ON order_items (seller_id);


-- -----------------------------------------------------------------------------
-- Payments: an order can be paid in several parts (e.g. card + voucher).
-- -----------------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id              VARCHAR(32)   NOT NULL REFERENCES orders (order_id),
    payment_sequential    SMALLINT      NOT NULL,
    payment_type          TEXT          NOT NULL,
    payment_installments  SMALLINT      NOT NULL,
    payment_value         NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);


-- -----------------------------------------------------------------------------
-- Reviews
-- Gotcha: review_id is NOT unique on its own (814 repeats: the same review is
-- attached to more than one order). The key is (review_id, order_id).
-- Also, 547 orders have more than one review. Decide how to handle that in
-- the analysis (e.g. keep the latest review per order) and write it down.
-- -----------------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id                VARCHAR(32) NOT NULL,
    order_id                 VARCHAR(32) NOT NULL REFERENCES orders (order_id),
    review_score             SMALLINT    NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP   NOT NULL,  -- when the survey was sent (time is almost always 00:00)
    review_answer_timestamp  TIMESTAMP   NOT NULL,
    PRIMARY KEY (review_id, order_id)
);
CREATE INDEX idx_order_reviews_order ON order_reviews (order_id);


-- -----------------------------------------------------------------------------
-- Geolocation: ~1M rows of lat/lng points per zip prefix.
-- There is no natural key (many points per zip, and ~262k exact duplicate
-- rows), so it gets a surrogate id. Customers and sellers do NOT get a foreign
-- key to it: 278 customer zips and 7 seller zips are missing from this table.
-- -----------------------------------------------------------------------------
CREATE TABLE geolocation (
    geolocation_id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    geolocation_zip_code_prefix  CHAR(5)          NOT NULL,
    geolocation_lat              DOUBLE PRECISION NOT NULL,
    geolocation_lng              DOUBLE PRECISION NOT NULL,
    geolocation_city             TEXT             NOT NULL,
    geolocation_state            CHAR(2)          NOT NULL
);
CREATE INDEX idx_geolocation_zip ON geolocation (geolocation_zip_code_prefix);
