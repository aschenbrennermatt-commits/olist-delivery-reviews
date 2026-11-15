-- =============================================================================
-- 02_load_data.sql
-- Loads the 9 Kaggle CSVs into the tables from 01_create_schema.sql.
--
-- Run from the repo root (the file paths below are relative to it):
--     psql -d olist -f sql/02_load_data.sql
--
-- Expects the unzipped Kaggle CSVs in data/raw/.
-- \copy runs on your machine and streams the file to the server, so it works
-- without superuser rights. Everything runs in one transaction: if any file
-- fails, nothing is loaded. Safe to re-run (it empties the tables first).
-- =============================================================================

\set ON_ERROR_STOP on
\timing on

BEGIN;

TRUNCATE order_reviews, order_payments, order_items, orders,
         products, sellers, customers, category_translation, geolocation
RESTART IDENTITY;

-- Load order matters: parent tables before the tables that reference them.

-- 1. Category lookup (71 rows in the file)
\copy category_translation FROM 'data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true)

-- Two categories used in products are missing from the translation file.
-- Without these rows the products foreign key would reject 13 products.
-- The English names are my own translations (documented in docs/data_notes.md).
INSERT INTO category_translation (product_category_name, product_category_name_english) VALUES
    ('pc_gamer',                                       'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos',  'portable_kitchen_and_food_preparers');

-- 2. Parent tables
\copy customers FROM 'data/raw/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy sellers   FROM 'data/raw/olist_sellers_dataset.csv'   WITH (FORMAT csv, HEADER true)
\copy products  FROM 'data/raw/olist_products_dataset.csv'  WITH (FORMAT csv, HEADER true)

-- 3. Orders (needs customers)
\copy orders FROM 'data/raw/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true)

-- 4. Child tables of orders
\copy order_items    FROM 'data/raw/olist_order_items_dataset.csv'    WITH (FORMAT csv, HEADER true)
\copy order_payments FROM 'data/raw/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy order_reviews  FROM 'data/raw/olist_order_reviews_dataset.csv'  WITH (FORMAT csv, HEADER true)

-- 5. Geolocation (column list needed because geolocation_id is generated)
\copy geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state) FROM 'data/raw/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true)

COMMIT;

-- Refresh the planner's statistics so the first queries run fast.
ANALYZE;
