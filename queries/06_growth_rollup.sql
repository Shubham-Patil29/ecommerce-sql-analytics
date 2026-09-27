-- Phase 6: Growth Trends and ROLLUP Summary
-- Project: E-commerce Customer Analytics - Pure SQL Edition
-- Database: PostgreSQL
--
-- Revenue grain: order_items.price + order_items.freight_value. Allocating
-- payment totals to every line item would duplicate an order's revenue across
-- categories, so item-level revenue is used for category analysis.

WITH monthly_category_revenue AS (
    SELECT
        date_trunc('month', o.order_purchase_timestamp)::date AS revenue_month,
        COALESCE(p.product_category_name, 'Unknown') AS product_category,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM public.orders AS o
    INNER JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
    LEFT JOIN public.products AS p
        ON p.product_id = oi.product_id
    WHERE o.order_purchase_timestamp IS NOT NULL
      AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY revenue_month, product_category
),
category_growth AS (
    SELECT
        revenue_month,
        product_category,
        order_count,
        revenue,
        LAG(revenue) OVER (
            PARTITION BY product_category
            ORDER BY revenue_month
        ) AS previous_month_revenue
    FROM monthly_category_revenue
),
category_detail AS (
    SELECT
        revenue_month,
        product_category,
        order_count,
        ROUND(revenue, 2) AS revenue,
        ROUND(
            100.0 * (revenue - previous_month_revenue)
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth_pct
    FROM category_growth
),
rollup_summary AS (
    SELECT
        revenue_month,
        product_category,
        SUM(order_count) AS order_count,
        SUM(revenue) AS revenue
    FROM category_detail
    GROUP BY ROLLUP (product_category, revenue_month)
)
SELECT
    revenue_month,
    product_category,
    CASE
        WHEN product_category IS NULL AND revenue_month IS NULL THEN 'Grand Total'
        WHEN revenue_month IS NULL THEN 'Category Subtotal'
        ELSE 'Monthly Category'
    END AS summary_level,
    order_count,
    ROUND(revenue, 2) AS revenue,
    CASE
        WHEN product_category IS NULL THEN NULL
        ELSE (
            SELECT cd.mom_growth_pct
            FROM category_detail AS cd
            WHERE cd.revenue_month = rs.revenue_month
              AND cd.product_category = rs.product_category
        )
    END AS mom_growth_pct
FROM rollup_summary AS rs
ORDER BY
    revenue_month NULLS LAST,
    product_category NULLS LAST;

-- ---------------------------------------------------------------------------
-- Monthly overall growth and performance extremes
-- ---------------------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        date_trunc('month', o.order_purchase_timestamp)::date AS revenue_month,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM public.orders AS o
    INNER JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_purchase_timestamp IS NOT NULL
      AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY revenue_month
),
monthly_growth AS (
    SELECT
        revenue_month,
        order_count,
        revenue,
        LAG(revenue) OVER (ORDER BY revenue_month) AS previous_month_revenue
    FROM monthly_revenue
),
ranked_months AS (
    SELECT
        *,
        RANK() OVER (ORDER BY revenue DESC) AS revenue_rank_high,
        RANK() OVER (ORDER BY revenue ASC) AS revenue_rank_low
    FROM monthly_growth
)
SELECT
    revenue_month,
    order_count,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0),
        2
    ) AS mom_growth_pct,
    CASE
        WHEN revenue_rank_high = 1 THEN 'Best Revenue Month'
        WHEN revenue_rank_low = 1 THEN 'Lowest Revenue Month'
    END AS performance_flag
FROM ranked_months
WHERE revenue_rank_high = 1
   OR revenue_rank_low = 1
ORDER BY revenue_month;

-- Interpretation checklist:
-- 1. Use category detail rows for category-level MoM comparisons.
-- 2. Use category subtotals to compare category performance across all months.
-- 3. Grand totals provide a reconciliation point for the item-level revenue.
-- 4. The first month for each category has NULL MoM growth because no prior
--    month exists; a zero prior month should not be treated as 0% growth.
