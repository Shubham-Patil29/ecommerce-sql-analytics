-- Phase 3: Customer Lifetime Value (CLV)
-- Project: E-commerce Customer Analytics - Pure SQL Edition
-- Database: PostgreSQL
--
-- Revenue definition: sum of payment_value by order, excluding canceled and
-- unavailable orders. This keeps revenue at the order grain before customer
-- aggregation and avoids duplicating revenue across order_items.
--
-- Projection assumption: each customer maintains their observed monthly order
-- frequency and average order value for the next 12 months. This is a simple
-- scenario estimate, not a predictive model.

-- ---------------------------------------------------------------------------
-- 1. Historical customer value and running revenue
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
customer_order_history AS (
    SELECT
        customer_unique_id,
        order_id,
        order_date,
        order_revenue,
        SUM(order_revenue) OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_date, order_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue
    FROM customer_orders
)
SELECT
    customer_unique_id,
    order_id,
    order_date,
    order_revenue,
    cumulative_revenue
FROM customer_order_history
ORDER BY customer_unique_id, order_date, order_id;

-- ---------------------------------------------------------------------------
-- 2. Historical and projected CLV by customer
-- ---------------------------------------------------------------------------
WITH RECURSIVE order_revenue AS (
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
customer_summary AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS order_count,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        SUM(order_revenue) AS historical_revenue,
        AVG(order_revenue) AS average_order_value,
        COUNT(*)::numeric
            / GREATEST(
                1,
                ((MAX(order_date) - MIN(order_date))::numeric / 30.4375) + 1
            ) AS monthly_order_frequency
    FROM customer_orders
    GROUP BY customer_unique_id
),
customer_assumptions AS (
    SELECT
        customer_unique_id,
        order_count,
        first_order_date,
        last_order_date,
        historical_revenue,
        average_order_value,
        monthly_order_frequency,
        average_order_value * monthly_order_frequency AS projected_monthly_revenue
    FROM customer_summary
),
clv_projection AS (
    SELECT
        customer_unique_id,
        0 AS projection_month,
        historical_revenue AS cumulative_projected_clv
    FROM customer_assumptions

    UNION ALL

    SELECT
        p.customer_unique_id,
        p.projection_month + 1,
        p.cumulative_projected_clv + a.projected_monthly_revenue
    FROM clv_projection AS p
    INNER JOIN customer_assumptions AS a
        ON a.customer_unique_id = p.customer_unique_id
    WHERE p.projection_month < 12
),
projected_clv AS (
    SELECT
        customer_unique_id,
        MAX(cumulative_projected_clv) AS projected_12_month_clv
    FROM clv_projection
    GROUP BY customer_unique_id
),
scored_customers AS (
    SELECT
        a.*,
        p.projected_12_month_clv,
        NTILE(4) OVER (
            ORDER BY p.projected_12_month_clv DESC, a.customer_unique_id
        ) AS clv_quartile
    FROM customer_assumptions AS a
    INNER JOIN projected_clv AS p
        ON p.customer_unique_id = a.customer_unique_id
)
SELECT
    customer_unique_id,
    order_count,
    first_order_date,
    last_order_date,
    ROUND(historical_revenue, 2) AS historical_revenue,
    ROUND(average_order_value, 2) AS average_order_value,
    ROUND(monthly_order_frequency, 4) AS monthly_order_frequency,
    ROUND(projected_monthly_revenue, 2) AS projected_monthly_revenue,
    ROUND(projected_12_month_clv, 2) AS projected_12_month_clv,
    clv_quartile,
    CASE clv_quartile
        WHEN 1 THEN 'Top CLV'
        WHEN 2 THEN 'High CLV'
        WHEN 3 THEN 'Mid CLV'
        WHEN 4 THEN 'Low CLV'
    END AS clv_tier
FROM scored_customers
ORDER BY projected_12_month_clv DESC, customer_unique_id;

-- ---------------------------------------------------------------------------
-- 3. CLV tier summary
-- ---------------------------------------------------------------------------
WITH RECURSIVE order_revenue AS (
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
customer_summary AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS order_count,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        SUM(order_revenue) AS historical_revenue,
        AVG(order_revenue) AS average_order_value,
        COUNT(*)::numeric
            / GREATEST(
                1,
                ((MAX(order_date) - MIN(order_date))::numeric / 30.4375) + 1
            ) AS monthly_order_frequency
    FROM customer_orders
    GROUP BY customer_unique_id
),
clv_projection AS (
    SELECT
        customer_unique_id,
        0 AS projection_month,
        historical_revenue AS cumulative_projected_clv
    FROM customer_summary

    UNION ALL

    SELECT
        p.customer_unique_id,
        p.projection_month + 1,
        p.cumulative_projected_clv
            + (s.average_order_value * s.monthly_order_frequency)
    FROM clv_projection AS p
    INNER JOIN customer_summary AS s
        ON s.customer_unique_id = p.customer_unique_id
    WHERE p.projection_month < 12
),
customer_clv AS (
    SELECT
        customer_unique_id,
        MAX(cumulative_projected_clv) AS projected_12_month_clv
    FROM clv_projection
    GROUP BY customer_unique_id
),
ranked_clv AS (
    SELECT
        customer_unique_id,
        projected_12_month_clv,
        NTILE(4) OVER (
            ORDER BY projected_12_month_clv DESC, customer_unique_id
        ) AS clv_quartile
    FROM customer_clv
)
SELECT
    clv_quartile,
    CASE clv_quartile
        WHEN 1 THEN 'Top CLV'
        WHEN 2 THEN 'High CLV'
        WHEN 3 THEN 'Mid CLV'
        WHEN 4 THEN 'Low CLV'
    END AS clv_tier,
    COUNT(*) AS customer_count,
    ROUND(SUM(projected_12_month_clv), 2) AS projected_clv_total,
    ROUND(AVG(projected_12_month_clv), 2) AS projected_clv_average
FROM ranked_clv
GROUP BY clv_quartile
ORDER BY clv_quartile;
