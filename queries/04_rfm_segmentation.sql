-- Phase 4: RFM Customer Segmentation
-- Project: E-commerce Customer Analytics - Pure SQL Edition
-- Database: PostgreSQL
--
-- RFM definitions:
--   Recency  = days since the customer's most recent completed order
--   Frequency = number of completed orders
--   Monetary = total payment value from completed orders
--
-- The analysis date is the latest completed order date in the dataset. This
-- makes the result reproducible and avoids using the query execution date.

-- ---------------------------------------------------------------------------
-- 1. Customer-level RFM scores and segment assignments
-- ---------------------------------------------------------------------------
WITH order_revenue AS (
    SELECT
        p.order_id,
        SUM(p.payment_value) AS order_revenue
    FROM public.payments AS p
    GROUP BY p.order_id
),
customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp::date AS order_date,
        COALESCE(r.order_revenue, 0::numeric) AS order_revenue
    FROM public.customers AS c
    INNER JOIN public.orders AS o
        ON o.customer_id = c.customer_id
    LEFT JOIN order_revenue AS r
        ON r.order_id = o.order_id
    WHERE c.customer_unique_id IS NOT NULL
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_status NOT IN ('canceled', 'unavailable')
),
analysis_date AS (
    SELECT MAX(order_date) AS latest_order_date
    FROM customer_orders
),
rfm_values AS (
    SELECT
        co.customer_unique_id,
        (ad.latest_order_date - MAX(co.order_date)) AS recency_days,
        COUNT(DISTINCT co.order_id) AS frequency,
        SUM(co.order_revenue) AS monetary_value
    FROM customer_orders AS co
    CROSS JOIN analysis_date AS ad
    GROUP BY co.customer_unique_id, ad.latest_order_date
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,
        NTILE(5) OVER (
            ORDER BY recency_days ASC, customer_unique_id
        ) AS recency_score,
        NTILE(5) OVER (
            ORDER BY frequency DESC, customer_unique_id
        ) AS frequency_score,
        NTILE(5) OVER (
            ORDER BY monetary_value DESC, customer_unique_id
        ) AS monetary_score
    FROM rfm_values
),
classified_customers AS (
    SELECT
        *,
        (recency_score + frequency_score + monetary_score) AS rfm_score,
        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4
                THEN 'Champions'
            WHEN recency_score >= 3
             AND frequency_score >= 4
                THEN 'Loyal Customers'
            WHEN recency_score >= 4
             AND frequency_score <= 2
                THEN 'New Customers'
            WHEN recency_score <= 2
             AND frequency_score >= 3
             AND monetary_score >= 3
                THEN 'At Risk'
            WHEN recency_score = 1
             AND frequency_score <= 2
             AND monetary_score <= 2
                THEN 'Lost Customers'
            ELSE 'Potential Loyalists'
        END AS customer_segment
    FROM rfm_scores
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    ROUND(monetary_value, 2) AS monetary_value,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_score,
    customer_segment
FROM classified_customers
ORDER BY rfm_score DESC, monetary_value DESC, customer_unique_id;

-- ---------------------------------------------------------------------------
-- 2. Segment size and revenue contribution
-- ---------------------------------------------------------------------------
WITH order_revenue AS (
    SELECT
        p.order_id,
        SUM(p.payment_value) AS order_revenue
    FROM public.payments AS p
    GROUP BY p.order_id
),
customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp::date AS order_date,
        COALESCE(r.order_revenue, 0::numeric) AS order_revenue
    FROM public.customers AS c
    INNER JOIN public.orders AS o
        ON o.customer_id = c.customer_id
    LEFT JOIN order_revenue AS r
        ON r.order_id = o.order_id
    WHERE c.customer_unique_id IS NOT NULL
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_status NOT IN ('canceled', 'unavailable')
),
analysis_date AS (
    SELECT MAX(order_date) AS latest_order_date
    FROM customer_orders
),
rfm_values AS (
    SELECT
        co.customer_unique_id,
        (ad.latest_order_date - MAX(co.order_date)) AS recency_days,
        COUNT(DISTINCT co.order_id) AS frequency,
        SUM(co.order_revenue) AS monetary_value
    FROM customer_orders AS co
    CROSS JOIN analysis_date AS ad
    GROUP BY co.customer_unique_id, ad.latest_order_date
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,
        NTILE(5) OVER (
            ORDER BY recency_days ASC, customer_unique_id
        ) AS recency_score,
        NTILE(5) OVER (
            ORDER BY frequency DESC, customer_unique_id
        ) AS frequency_score,
        NTILE(5) OVER (
            ORDER BY monetary_value DESC, customer_unique_id
        ) AS monetary_score
    FROM rfm_values
),
classified_customers AS (
    SELECT
        *,
        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4
                THEN 'Champions'
            WHEN recency_score >= 3
             AND frequency_score >= 4
                THEN 'Loyal Customers'
            WHEN recency_score >= 4
             AND frequency_score <= 2
                THEN 'New Customers'
            WHEN recency_score <= 2
             AND frequency_score >= 3
             AND monetary_score >= 3
                THEN 'At Risk'
            WHEN recency_score = 1
             AND frequency_score <= 2
             AND monetary_score <= 2
                THEN 'Lost Customers'
            ELSE 'Potential Loyalists'
        END AS customer_segment
    FROM rfm_scores
),
total_value AS (
    SELECT SUM(monetary_value) AS all_customer_revenue
    FROM classified_customers
)
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
    ROUND(SUM(monetary_value), 2) AS segment_revenue,
    ROUND(
        100.0 * SUM(monetary_value)
        / NULLIF(MAX(tv.all_customer_revenue), 0),
        2
    ) AS revenue_contribution_pct,
    ROUND(AVG(monetary_value), 2) AS average_customer_revenue
FROM classified_customers AS cc
CROSS JOIN total_value AS tv
GROUP BY customer_segment
ORDER BY segment_revenue DESC;

-- Interpretation checklist:
-- 1. Champions combine recent activity, repeat ordering, and high spend.
-- 2. At Risk customers are valuable or frequent but have weak recency scores.
-- 3. Lost Customers have both long inactivity and low historical engagement.
-- 4. Compare segment revenue contribution with customer share before choosing
--    retention or reactivation priorities.
--
-- NTILE creates five equal-population bands and may split tied values across
-- adjacent scores. The customer_unique_id tie-breaker makes that assignment
-- deterministic for reproducible portfolio results.
