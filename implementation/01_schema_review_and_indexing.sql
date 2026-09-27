-- Phase 1: Schema Review and Indexing Strategy
-- Project: E-commerce Customer Analytics - Pure SQL Edition
-- Database: PostgreSQL
--
-- Run this file after schema/create_tables.sql has been executed.
-- The statements are intentionally idempotent so the script can be rerun safely.

-- ---------------------------------------------------------------------------
-- 0. Baseline performance capture (before Phase 1 indexes)
-- ---------------------------------------------------------------------------
-- Save this plan and its execution time before running the index section.
EXPLAIN (ANALYZE, BUFFERS, COSTS, SUMMARY)
SELECT
    o.customer_id,
    date_trunc('month', o.order_purchase_timestamp)::date AS order_month,
    COUNT(*) AS order_count
FROM public.orders AS o
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY o.customer_id, order_month
ORDER BY o.customer_id, order_month;

BEGIN;

-- Expected relationships in the Olist-style schema:
-- customers.customer_id      1 -> many orders.customer_id
-- orders.order_id            1 -> many order_items.order_id
-- orders.order_id            1 -> many payments.order_id
-- orders.order_id            1 -> many reviews.order_id
-- products.product_id        1 -> many order_items.product_id
--
-- The customer_unique_id column identifies a person across customer records.
-- Analytical customer-level queries should use customer_unique_id when the
-- business question is about people rather than order records.

-- ---------------------------------------------------------------------------
-- 1. Schema review checks
-- ---------------------------------------------------------------------------

-- Confirm the expected tables exist before creating indexes.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
      'customers',
      'orders',
      'order_items',
      'payments',
      'products',
      'reviews'
  )
ORDER BY table_name;

-- Check primary-key and foreign-key definitions recorded in the database.
SELECT
    constraint_name,
    table_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name IN (
      'customers',
      'orders',
      'order_items',
      'payments',
      'products',
      'reviews'
  )
  AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY table_name, constraint_type, constraint_name;

-- ---------------------------------------------------------------------------
-- 2. Index strategy
-- ---------------------------------------------------------------------------
-- Indexes are aligned to the planned workload:
--   * customer history and cohort construction: orders.customer_id plus date
--   * time-series filtering and ordering: orders.order_purchase_timestamp
--   * order-to-item/payment/review joins: each child table's order_id
--   * product category rollups: order_items.product_id and products category
--
-- Avoid indexing low-selectivity status columns by themselves. Add those only
-- after EXPLAIN ANALYZE demonstrates a benefit for a real query.

-- Cohort, CLV, RFM, and churn queries read orders by customer and date.
CREATE INDEX IF NOT EXISTS idx_orders_customer_purchase_ts
    ON public.orders (customer_id, order_purchase_timestamp);

-- Growth analysis filters and orders the fact table by purchase time.
CREATE INDEX IF NOT EXISTS idx_orders_purchase_timestamp
    ON public.orders (order_purchase_timestamp);

-- Customer-level analysis may group by the stable customer identity.
CREATE INDEX IF NOT EXISTS idx_customers_customer_unique_id
    ON public.customers (customer_unique_id);

-- Support the order-to-line-item, payment, and review joins.
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON public.order_items (order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON public.order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_payments_order_id
    ON public.payments (order_id);

CREATE INDEX IF NOT EXISTS idx_reviews_order_id
    ON public.reviews (order_id);

-- Product/category rollups join through product_id and group by category.
CREATE INDEX IF NOT EXISTS idx_products_category_product_id
    ON public.products (product_category_name, product_id);

-- Refresh planner statistics after index creation and data loading.
ANALYZE public.customers;
ANALYZE public.orders;
ANALYZE public.order_items;
ANALYZE public.payments;
ANALYZE public.products;
ANALYZE public.reviews;

COMMIT;

-- ---------------------------------------------------------------------------
-- 3. Post-index performance capture
-- ---------------------------------------------------------------------------
-- Compare this plan with the pre-index plan above. Repeat the comparison in
-- Phase 7 after any query rewrite or additional index change.

EXPLAIN (ANALYZE, BUFFERS, COSTS, SUMMARY)
SELECT
    o.customer_id,
    date_trunc('month', o.order_purchase_timestamp)::date AS order_month,
    COUNT(*) AS order_count
FROM public.orders AS o
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY o.customer_id, order_month
ORDER BY o.customer_id, order_month;

-- Verify that the indexes created by this file are visible to PostgreSQL.
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
      'idx_orders_customer_purchase_ts',
      'idx_orders_purchase_timestamp',
      'idx_customers_customer_unique_id',
      'idx_order_items_order_id',
      'idx_order_items_product_id',
      'idx_payments_order_id',
      'idx_reviews_order_id',
      'idx_products_category_product_id'
  )
ORDER BY tablename, indexname;
