-- Phase 0: Minimal PostgreSQL schema for local testing
-- Replace or extend this schema when loading the full Olist dataset.

CREATE TABLE IF NOT EXISTS customers (
    customer_id text PRIMARY KEY,
    customer_unique_id text NOT NULL,
    customer_zip_code_prefix integer,
    customer_city text,
    customer_state text
);

CREATE TABLE IF NOT EXISTS orders (
    order_id text PRIMARY KEY,
    customer_id text NOT NULL REFERENCES customers(customer_id),
    order_status text NOT NULL,
    order_purchase_timestamp timestamp NOT NULL,
    order_delivered_customer_date timestamp,
    order_estimated_delivery_date timestamp
);

CREATE TABLE IF NOT EXISTS products (
    product_id text PRIMARY KEY,
    product_category_name text
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id text NOT NULL REFERENCES orders(order_id),
    order_item_id integer NOT NULL,
    product_id text NOT NULL REFERENCES products(product_id),
    price numeric(12, 2) NOT NULL,
    freight_value numeric(12, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS payments (
    order_id text NOT NULL REFERENCES orders(order_id),
    payment_sequential integer NOT NULL,
    payment_type text,
    payment_installments integer,
    payment_value numeric(12, 2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE IF NOT EXISTS reviews (
    review_id text PRIMARY KEY,
    order_id text NOT NULL REFERENCES orders(order_id),
    review_score integer CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title text,
    review_comment_message text
);
