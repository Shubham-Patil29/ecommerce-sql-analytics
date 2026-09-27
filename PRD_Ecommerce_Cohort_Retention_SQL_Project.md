# PRD: E-commerce Cohort & Retention Analysis (Advanced SQL Portfolio Project)

## 1. Overview

**Project Name:** E-commerce Customer Analytics — Pure SQL Edition
**Owner:** Shubham Patil
**Type:** Personal portfolio project (Data Analyst job applications)
**Tech Stack:** PostgreSQL, SQL only (no Python, no BI tool)
**Dataset:** Olist Brazilian E-Commerce Dataset (or equivalent public e-commerce dataset with orders, customers, order_items, payments, reviews)

## 2. Problem Statement

Most analyst portfolios demonstrate SQL only at the SELECT/JOIN/GROUP BY level, then hand off all real analysis to Python or a BI tool. This project proves the ability to perform advanced, business-relevant analysis **entirely in SQL** — cohort retention, CLV, RFM segmentation, and churn detection — using window functions, CTEs, and query optimization techniques that are directly relevant to a Data Analyst / Analytics Engineer role.

## 3. Goals

- Demonstrate advanced SQL: window functions (LAG, LEAD, NTILE, PERCENT_RANK), recursive CTEs, ROLLUP/CUBE
- Answer real business questions (retention, CLV, churn, segmentation) without leaving the database
- Show query optimization skills (EXPLAIN ANALYZE, indexing, rewriting)
- Produce a GitHub-ready repo with README, documented queries, and sample outputs
- Have concrete talking points for interviews ("walk me through a project where you used window functions")

## 4. Non-Goals

- No dashboarding (Power BI/Tableau) — this project is explicitly SQL-only
- No machine learning models for churn prediction (rule-based flagging only)
- No production deployment/pipeline — this is an analysis project, not an ETL system

## 5. Success Criteria

- All 7 core queries run correctly on the dataset and return business-sensible results
- At least one query has a documented before/after optimization with EXPLAIN ANALYZE
- README clearly states the business problem, approach, and 3–4 key insights
- Repo is clean enough to link directly in a resume/LinkedIn

---

## 6. Project Phases

### Phase 0 — Environment & Dataset Setup
**Goal:** Get a working PostgreSQL instance with the dataset loaded and ready to query.

- Install/confirm PostgreSQL (local or a free-tier cloud instance)
- Download Olist dataset from Kaggle
- Write `CREATE TABLE` scripts for: customers, orders, order_items, payments, products, reviews
- Load CSVs into tables (`COPY` command or a loader tool)
- Sanity-check row counts and spot-check a few joins

**Deliverable:** `/schema/create_tables.sql`, loaded database, `01_setup_notes.md`

---

### Phase 1 — Schema Review & Indexing Strategy
**Goal:** Understand the data model and prepare it for analytical query performance.

- Document table relationships (ERD, even a simple hand-drawn one)
- Identify columns used in JOINs, WHERE, and ORDER BY across planned queries
- Add indexes on foreign keys and frequently filtered columns (e.g., `customer_id`, `order_purchase_timestamp`)
- Note baseline query performance before optimization phase

**Deliverable:** `/schema/indexes.sql`, ERD diagram, indexing rationale notes

---

### Phase 2 — Monthly Cohort Retention Analysis
**Goal:** Build a retention matrix showing what % of each acquisition cohort keeps ordering over time.

- Define cohort = month of customer's first order
- Use window functions to compute order month relative to cohort month
- Build retention % matrix (cohort month × months since acquisition)
- Interpret results: which cohorts retain best/worst, and why

**Deliverable:** `/queries/02_cohort_retention.sql`, sample output table, insight notes

---

### Phase 3 — Customer Lifetime Value (CLV)
**Goal:** Calculate historical and projected CLV per customer.

- Cumulative revenue per customer using window functions (running SUM)
- Recursive CTE to project forward CLV based on historical order frequency/spend
- Rank/segment customers by CLV tier

**Deliverable:** `/queries/03_clv.sql`, sample output, insight notes

---

### Phase 4 — RFM Segmentation
**Goal:** Segment customers by Recency, Frequency, Monetary value using pure SQL scoring.

- Compute R, F, M per customer
- Score each dimension using NTILE or PERCENT_RANK
- Classify into segments (Champions, Loyal, At Risk, Lost, etc.) via CASE logic on combined scores
- Summarize segment sizes and revenue contribution

**Deliverable:** `/queries/04_rfm_segmentation.sql`, segment summary table, insight notes

---

### Phase 5 — Churn Flagging
**Goal:** Flag customers likely to have churned based on their own historical ordering pattern.

- Calculate each customer's average gap between orders using LAG/LEAD
- Define churn threshold (e.g., no order within 1.5x their average gap, or a fixed N-day window)
- Flag customers as Active / At Risk / Churned
- Cross-reference churn flags with RFM segments for a combined view

**Deliverable:** `/queries/05_churn_flagging.sql`, sample output, insight notes

---

### Phase 6 — Growth Trends & ROLLUP Summary
**Goal:** Produce a month-over-month and category-level revenue summary with subtotals.

- Monthly revenue/order count using GROUP BY ROLLUP or CUBE (category × month)
- MoM growth % using LAG
- Identify best/worst performing months and categories

**Deliverable:** `/queries/06_growth_rollup.sql`, sample output, insight notes

---

### Phase 7 — Query Optimization Case Study
**Goal:** Demonstrate the ability to diagnose and fix slow queries.

- Pick the heaviest query from Phases 2–6 (likely cohort retention or CLV)
- Run EXPLAIN ANALYZE before optimization
- Apply indexing, query rewriting, or CTE materialization improvements
- Run EXPLAIN ANALYZE after, document the performance delta

**Deliverable:** `/optimization/07_query_optimization.md` (before/after plans + explanation)

---

### Phase 8 — Documentation & Portfolio Packaging
**Goal:** Package the project so it's resume- and interview-ready.

- Write README.md: business problem, approach, tech used, key insights (3–4 bullet takeaways)
- Add sample output screenshots/tables for each phase
- Organize repo folders: `/schema`, `/queries`, `/optimization`, `/docs`
- Prepare 2–3 interview talking points per phase (e.g., "why NTILE over PERCENT_RANK here")

**Deliverable:** Finalized GitHub repo, README.md, interview prep notes

---

## 7. Suggested Repo Structure

```
ecommerce-sql-analytics/
├── README.md
├── schema/
│   ├── create_tables.sql
│   └── indexes.sql
├── queries/
│   ├── 02_cohort_retention.sql
│   ├── 03_clv.sql
│   ├── 04_rfm_segmentation.sql
│   ├── 05_churn_flagging.sql
│   └── 06_growth_rollup.sql
├── optimization/
│   └── 07_query_optimization.md
└── docs/
    ├── erd.png
    └── sample_outputs/
```

## 8. Timeline (Suggested, Self-Paced)

| Phase | Estimated Time |
|---|---|
| 0. Setup | 0.5 day |
| 1. Schema & Indexing | 0.5 day |
| 2. Cohort Retention | 1 day |
| 3. CLV | 1 day |
| 4. RFM Segmentation | 1 day |
| 5. Churn Flagging | 1 day |
| 6. Growth/ROLLUP | 0.5 day |
| 7. Optimization | 0.5–1 day |
| 8. Documentation | 0.5 day |
| **Total** | **~6–7 days** |

## 9. Risks / Open Questions

- Olist dataset spans a limited real time window — cohort analysis may show fewer months than ideal; may need to simulate/extend or clearly caveat this in the README
- Recursive CTE for CLV projection needs a clear, defensible assumption (e.g., average order frequency) — should be documented, not just coded
- Churn definition is inherently a business judgment call — document the reasoning, not just the query
