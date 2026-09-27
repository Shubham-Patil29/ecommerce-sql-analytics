-- Phase 5: Customer Churn Flagging
-- Project: E-commerce Customer Analytics - Pure SQL Edition
-- Database: PostgreSQL
--
-- Churn rules:
--   Active:  days since last order <= expected gap
--   At Risk: expected gap < days since last order <= 1.5 * expected gap
--   Churned: days since last order > 1.5 * expected gap
--
-- Customers with one order have no personal gap history, so a conservative
-- 180-day expected gap is used for them. The analysis date is the latest
-- completed order date in the dataset for reproducible results.

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
ordered_history AS (
    SELECT
        customer_unique_id,
        order_id,
        order_date,
        order_revenue,
        LAG(order_date) OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_date, order_id
        ) AS previous_order_date
    FROM customer_orders
),
customer_behavior AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS order_count,
        MAX(order_date) AS last_order_date,
        SUM(order_revenue) AS monetary_value,
        AVG(order_date - previous_order_date)
            FILTER (WHERE previous_order_date IS NOT NULL) AS average_gap_days
    FROM ordered_history
    GROUP BY customer_unique_id
),
analysis_date AS (
    SELECT MAX(order_date) AS latest_order_date
    FROM customer_orders
),
churn_metrics AS (
    SELECT
        cb.*,
        ad.latest_order_date,
        ad.latest_order_date - cb.last_order_date AS days_since_last_order,
        COALESCE(cb.average_gap_days, 180)::numeric AS expected_gap_days
    FROM customer_behavior AS cb
    CROSS JOIN analysis_date AS ad
),
churn_flags AS (
    SELECT
        *,
        CASE
            WHEN days_since_last_order <= expected_gap_days
                THEN 'Active'
            WHEN days_since_last_order <= expected_gap_days * 1.5
                THEN 'At Risk'
            ELSE 'Churned'
        END AS churn_status
    FROM churn_metrics
)
SELECT
    customer_unique_id,
    order_count,
    last_order_date,
    latest_order_date AS analysis_date,
    days_since_last_order,
    ROUND(expected_gap_days, 1) AS expected_gap_days,
    ROUND(average_gap_days, 1) AS average_gap_days,
    ROUND(monetary_value, 2) AS monetary_value,
    churn_status
FROM churn_flags
ORDER BY
    CASE churn_status
        WHEN 'Churned' THEN 1
        WHEN 'At Risk' THEN 2
        ELSE 3
    END,
    days_since_last_order DESC,
    customer_unique_id;

-- ---------------------------------------------------------------------------
-- RFM cross-reference: churn status by customer segment
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
ordered_history AS (
    SELECT
        *,
        LAG(order_date) OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_date, order_id
        ) AS previous_order_date
    FROM customer_orders
),
customer_behavior AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS frequency,
        MAX(order_date) AS last_order_date,
        SUM(order_revenue) AS monetary_value,
        AVG(order_date - previous_order_date)
            FILTER (WHERE previous_order_date IS NOT NULL) AS average_gap_days
    FROM ordered_history
    GROUP BY customer_unique_id
),
analysis_date AS (
    SELECT MAX(order_date) AS latest_order_date
    FROM customer_orders
),
rfm_base AS (
    SELECT
        cb.*,
        ad.latest_order_date,
        ad.latest_order_date - cb.last_order_date AS recency_days
    FROM customer_behavior AS cb
    CROSS JOIN analysis_date AS ad
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC, customer_unique_id) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency DESC, customer_unique_id) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary_value DESC, customer_unique_id) AS monetary_score
    FROM rfm_base
),
classified AS (
    SELECT
        *,
        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4 THEN 'Champions'
            WHEN recency_score >= 3 AND frequency_score >= 4 THEN 'Loyal Customers'
            WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
            WHEN recency_score <= 2
             AND frequency_score >= 3
             AND monetary_score >= 3 THEN 'At Risk'
            WHEN recency_score = 1
             AND frequency_score <= 2
             AND monetary_score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalists'
        END AS customer_segment,
        COALESCE(average_gap_days, 180)::numeric AS expected_gap_days
    FROM rfm_scores
),
status_assigned AS (
    SELECT
        *,
        CASE
            WHEN recency_days <= expected_gap_days THEN 'Active'
            WHEN recency_days <= expected_gap_days * 1.5 THEN 'At Risk'
            ELSE 'Churned'
        END AS churn_status
    FROM classified
)
SELECT
    customer_segment,
    churn_status,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary_value), 2) AS segment_revenue,
    ROUND(AVG(recency_days), 1) AS average_recency_days
FROM status_assigned
GROUP BY customer_segment, churn_status
ORDER BY customer_segment, churn_status;

-- Interpretation checklist:
-- 1. Prioritize Churned and At Risk customers in high-value RFM segments.
-- 2. Review the 180-day fallback assumption when business context is known.
-- 3. Recalibrate the 1.5x multiplier with retention experiments or historical
--    reactivation outcomes rather than treating it as a universal truth.
