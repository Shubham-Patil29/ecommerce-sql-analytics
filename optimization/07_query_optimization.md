# Phase 7: Query Optimization Case Study

## Query Selected

The cohort-retention query from `queries/02_cohort_retention.sql` is the optimization target because it joins the two largest analytical tables, deduplicates customer-month activity, and calculates a window function over customer history.

The comparison must be run on the same PostgreSQL database, dataset, cache state, and session settings. Do not compare plans collected from different environments.

## Baseline

Run the query before adding or changing the Phase 1 indexes:

```sql
EXPLAIN (ANALYZE, BUFFERS, COSTS, SUMMARY)
WITH customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        date_trunc('month', o.order_purchase_timestamp)::date AS order_month
    FROM public.customers AS c
    INNER JOIN public.orders AS o
        ON o.customer_id = c.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
)
SELECT COUNT(*)
FROM customer_orders;
```

Record these fields in the table below:

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Execution time | _run locally_ | _run locally_ | _calculate_ |
| Planning time | _run locally_ | _run locally_ | _calculate_ |
| Shared blocks read | _run locally_ | _run locally_ | _calculate_ |
| Shared blocks hit | _run locally_ | _run locally_ | _calculate_ |

## Optimization Applied

Phase 1 adds the composite index:

```sql
CREATE INDEX IF NOT EXISTS idx_orders_customer_purchase_ts
    ON public.orders (customer_id, order_purchase_timestamp);
```

This index supports the customer join and makes the purchase timestamp available in the same access path. The separate timestamp index supports time-based growth queries but is not assumed to improve every cohort plan.

Refresh statistics before measuring:

```sql
ANALYZE public.customers;
ANALYZE public.orders;
```

The implementation intentionally keeps the CTE readable. PostgreSQL may inline eligible CTEs, so no `MATERIALIZED` hint is added without evidence that repeated evaluation is the bottleneck.

## After Plan

Run the same baseline query after creating the index:

```sql
EXPLAIN (ANALYZE, BUFFERS, COSTS, SUMMARY)
WITH customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        date_trunc('month', o.order_purchase_timestamp)::date AS order_month
    FROM public.customers AS c
    INNER JOIN public.orders AS o
        ON o.customer_id = c.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
)
SELECT COUNT(*)
FROM customer_orders;
```

Save the complete plans beside this document when the benchmark is run. A good result may still use a sequential scan if most rows are needed; an index is not automatically faster for a broad analytical scan.

## Analysis Template

- **Observed bottleneck:** Record the node with the highest actual time, such as a sort, hash join, or sequential scan.
- **Plan change:** State whether the index changed the join, scan, sort, or buffer behavior.
- **Performance change:** Compare execution time and shared buffers using the table above.
- **Decision:** Keep the index only when the measured workload justifies its storage and write cost.
- **Limitation:** This is a single-query benchmark; validate the index against the other project queries before treating it as a general improvement.
