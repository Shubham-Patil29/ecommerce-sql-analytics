-- Phase 2: Monthly Cohort Retention Analysis
-- Project: E-commerce Customer Analytics - Pure SQL Edition
-- Database: PostgreSQL
--
-- Cohort definition: the calendar month of a customer's first order.
-- Customer grain: customer_unique_id, which identifies a person across orders.
-- Retention definition: a customer is retained in a month when they place at
-- least one order during that calendar month.

WITH customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        date_trunc('month', o.order_purchase_timestamp)::date AS order_month
    FROM public.customers AS c
    INNER JOIN public.orders AS o
        ON o.customer_id = c.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
      AND c.customer_unique_id IS NOT NULL
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        order_month,
        MIN(order_month) OVER (
            PARTITION BY customer_unique_id
        ) AS cohort_month
    FROM customer_orders
),
cohort_activity AS (
    SELECT
        cohort_month,
        order_month,
        (
            (EXTRACT(YEAR FROM order_month) - EXTRACT(YEAR FROM cohort_month)) * 12
            + EXTRACT(MONTH FROM order_month)
            - EXTRACT(MONTH FROM cohort_month)
        )::integer AS months_since_cohort,
        COUNT(*) AS retained_customers
    FROM customer_cohorts
    GROUP BY cohort_month, order_month
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_customers
    FROM customer_cohorts
    WHERE order_month = cohort_month
    GROUP BY cohort_month
)

-- Long-format retention matrix: one row per cohort and month offset.
SELECT
    a.cohort_month,
    a.months_since_cohort,
    s.cohort_customers,
    a.retained_customers,
    ROUND(
        100.0 * a.retained_customers / NULLIF(s.cohort_customers, 0),
        2
    ) AS retention_rate_pct
FROM cohort_activity AS a
INNER JOIN cohort_sizes AS s
    ON s.cohort_month = a.cohort_month
ORDER BY a.cohort_month, a.months_since_cohort;

-- Optional pivot for a compact portfolio-ready matrix. The long-format query
-- above is preferred for downstream analysis because it supports any horizon.
WITH customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        date_trunc('month', o.order_purchase_timestamp)::date AS order_month
    FROM public.customers AS c
    INNER JOIN public.orders AS o
        ON o.customer_id = c.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
      AND c.customer_unique_id IS NOT NULL
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        order_month,
        MIN(order_month) OVER (
            PARTITION BY customer_unique_id
        ) AS cohort_month
    FROM customer_orders
),
cohort_activity AS (
    SELECT
        cohort_month,
        (
            (EXTRACT(YEAR FROM order_month) - EXTRACT(YEAR FROM cohort_month)) * 12
            + EXTRACT(MONTH FROM order_month)
            - EXTRACT(MONTH FROM cohort_month)
        )::integer AS months_since_cohort,
        COUNT(*) AS retained_customers
    FROM customer_cohorts
    GROUP BY cohort_month, months_since_cohort
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_customers
    FROM customer_cohorts
    WHERE order_month = cohort_month
    GROUP BY cohort_month
),
retention_rates AS (
    SELECT
        a.cohort_month,
        a.months_since_cohort,
        ROUND(
            100.0 * a.retained_customers / NULLIF(s.cohort_customers, 0),
            2
        ) AS retention_rate_pct
    FROM cohort_activity AS a
    INNER JOIN cohort_sizes AS s
        ON s.cohort_month = a.cohort_month
)
SELECT
    cohort_month,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 0) AS month_0,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 1) AS month_1,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 2) AS month_2,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 3) AS month_3,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 4) AS month_4,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 5) AS month_5,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 6) AS month_6,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 7) AS month_7,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 8) AS month_8,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 9) AS month_9,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 10) AS month_10,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 11) AS month_11,
    MAX(retention_rate_pct) FILTER (WHERE months_since_cohort = 12) AS month_12
FROM retention_rates
GROUP BY cohort_month
ORDER BY cohort_month;

-- Interpretation checklist:
-- 1. Month 0 should be 100% for every cohort with a valid first order.
-- 2. Compare the same month offset across cohorts, not only calendar months.
-- 3. Exclude the newest cohorts from long-horizon comparisons because they have
--    not had enough time to reach later months.
-- 4. Investigate unusually strong or weak cohorts against promotions, product
--    mix, delivery experience, and review scores in later phases.
