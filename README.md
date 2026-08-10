# UrbanKart Analytics Engineering Project

> **End-to-end Analytics Engineering portfolio project** built using dbt + Snowflake + Power BI on the Olist Brazilian E-Commerce public dataset. Simulates a real-world analytics platform for a fictional e-commerce company — **UrbanKart**.

---

## Project Status

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Environment Setup | ✅ Complete |
| Phase 2 | Snowflake Setup + Raw Data Load | ✅ Complete |
| Phase 3 | Business Understanding + Requirements | ✅ Complete |
| Phase 4 | dbt Init + Staging Layer | ✅ Complete |
| Phase 5A | Intermediate Layer | ✅ Complete |
| Phase 5B | Marts Layer (Star Schema) | ✅ Complete  |
| Phase 6 | Advanced dbt (Incremental, Snapshots, Macros) |✅ Complete |
| Phase 7 | CI/CD (GitHub Actions) | 🔄 In Progress |
| Phase 8 | Power BI Dashboard | ⏳ Planned |

---

## Business Context

**UrbanKart** is a fictional multi-category e-commerce marketplace (modeled after Olist's marketplace structure — connecting third-party sellers to customers). Before this project, the Finance and Ops teams were tracking KPIs manually in spreadsheets pulled from the OLTP database.

**This project builds a single source of truth** — a production-style analytics engineering platform that serves Finance, Operations, Marketing, and CX teams through a unified, tested, documented data model.

### Key Business Problems Solved

| Department | Problem | Solution |
|---|---|---|
| Logistics/Ops | No automated SLA tracking — delays caught too late | `int_delivery_performance` + source freshness alerts |
| Finance | Revenue numbers inconsistent across teams (fan-out bug) | `int_order_payments_summary` — aggregated before join |
| CX | No way to correlate late delivery with bad reviews | `fct_reviews` with delivery context join |
| Marketing | Product category names in Portuguese only | English translation via `dim_products` |
| Leadership | No trust in numbers — bad data reached dashboards before | dbt tests + CI/CD gate on every PR |
| Engineering | Bad model broke CFO dashboard (no review process) | Git branching + PR workflow + GitHub Actions |

---

## Tech Stack

| Tool | Purpose | Version |
|---|---|---|
| **Snowflake** | Cloud Data Warehouse | Trial — XSMALL warehouse |
| **dbt Core** | Data Transformation | 1.11.x |
| **dbt-utils** | Surrogate keys + macros | 1.x |
| **Git + GitHub** | Version control + collaboration | — |
| **VS Code** | IDE | Latest |
| **Power BI** | BI Dashboard (Phase 8) | Desktop |
| **Snowflake CLI** | Data loading + ad-hoc SQL | 3.21 |

---

## Dataset

**Source:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)

| Table | Description | Rows (approx) |
|---|---|---|
| orders | Order lifecycle events | ~99K |
| order_items | Line items per order | ~112K |
| customers | Customer records | ~99K |
| sellers | Seller profiles | ~3K |
| products | Product catalog | ~33K |
| payments | Payment transactions | ~103K |
| reviews | Customer reviews | ~99K |
| geolocation | ZIP code coordinates | ~1M |
| product_category_translation | Portuguese → English | ~71 |

---

## Architecture

```
Raw Layer (Snowflake — AE_PROJECTS.RAW)
    ↓
Staging Layer (AE_PROJECTS.STAGING — dbt views)
    ↓
Intermediate Layer (Ephemeral — compiled as CTEs)
    ↓
Marts Layer (AE_PROJECTS.MARTS — dbt tables)
    ↓
Power BI Dashboard
```

### Layer Responsibilities

| Layer | Prefix | Materialization | Purpose |
|---|---|---|---|
| Staging | `stg_` | View | Rename, cast, clean — 1:1 with source |
| Intermediate | `int_` | Ephemeral | Join, aggregate, business logic |
| Marts — Dimension | `dim_` | Table | Descriptive context for fact joins |
| Marts — Fact | `fct_` | Table | Metrics + KPIs — consumption ready |

---

## Project Structure

```
urbankart_analytics/
├── models/
│   ├── staging/
│   │   ├── _olist__sources.yml          # Source declarations + freshness
│   │   ├── _olist__staging.yml          # Tests + documentation
│   │   ├── stg_olist__customers.sql
│   │   ├── stg_olist__orders.sql
│   │   ├── stg_olist__order_items.sql
│   │   ├── stg_olist__payments.sql
│   │   ├── stg_olist__products.sql
│   │   ├── stg_olist__reviews.sql
│   │   ├── stg_olist__sellers.sql
│   │   ├── stg_olist__geolocation.sql
│   │   └── stg_olist__product_category_translation.sql
│   │
│   ├── intermediate/
│   │   ├── _intermediate__models.yml    # Tests + documentation
│   │   ├── int_order_payments_summary.sql
│   │   ├── int_delivery_performance.sql
│   │   └── int_orders_joined.sql
│   │
│   └── marts/
│       ├── core/
│       │   ├── _core__models.yml
│       │   ├── dim_customers.sql
│       │   ├── dim_sellers.sql
│       │   ├── dim_products.sql
│       │   ├── dim_date.sql
│       │   └── fct_orders.sql
│       └── finance/
│           ├── _finance__models.yml
│           └── fct_reviews.sql
│
├── macros/
│   └── generate_schema_name.sql         # Custom schema naming
│
├── snapshots/                           # Phase 6 — SCD Type 2
├── seeds/                               # Phase 6 — Reference data
├── tests/                               # Phase 6 — Singular tests
├── analyses/
├── packages.yml                         # dbt-utils dependency
├── dbt_project.yml
├── .gitignore
└── README.md
```

---

## Data Models

### Staging Layer (9 models)

| Model | Source Table | Key Transformations |
|---|---|---|
| `stg_olist__orders` | ORDERS | Timestamp cast, column rename (_at suffix) |
| `stg_olist__customers` | CUSTOMERS | City uppercase, zip code |
| `stg_olist__order_items` | ORDER_ITEMS | Price + freight as floats |
| `stg_olist__payments` | PAYMENTS | Payment type, installments |
| `stg_olist__products` | PRODUCTS | Physical dimensions |
| `stg_olist__reviews` | REVIEWS | Score, timestamps |
| `stg_olist__sellers` | SELLERS | City, state, zip |
| `stg_olist__geolocation` | GEOLOCATION | Lat/lng coordinates |
| `stg_olist__product_category_translation` | PRODUCT_CATEGORY_TRANSLATION | PT → EN mapping |

### Intermediate Layer (3 models)

| Model | Grain | Purpose | Key Decision |
|---|---|---|---|
| `int_order_payments_summary` | Order | Aggregate payments per order | Resolves fan-out — SUM before JOIN |
| `int_delivery_performance` | Order | SLA + delay calculation | NULL = intentional (undelivered orders) |
| `int_orders_joined` | Order-Item | Wide join of 5 staging models | LEFT JOINs everywhere — no silent row drops |

### Marts Layer (6 models)

| Model | Type | Grain | Key Features |
|---|---|---|---|
| `dim_customers` | Dimension | Unique customer | SCD1, deduplication via ROW_NUMBER |
| `dim_sellers` | Dimension | Seller | SCD1 (SCD2 via snapshot in Phase 6) |
| `dim_products` | Dimension | Product | English category via COALESCE |
| `dim_date` | Dimension | Calendar date | Generated (2016–2020), Power BI time intelligence |
| `fct_orders` | Fact | Order-Item | Star schema center — Finance + Ops + Marketing KPIs |
| `fct_reviews` | Fact | Review | CX domain — late delivery correlation |

---

## Star Schema

```
                    dim_date
                       |
dim_customers ——— fct_orders ——— dim_sellers
                       |
                  dim_products


fct_reviews (separate — different grain)
```

---

## Key Engineering Decisions

### 1. Why Order-Item Grain for fct_orders (not Order grain)?

Each item in an order has its own `product_id`, `seller_id`, `price`, `freight_value`, and `shipping_limit_date`. Order grain would make seller-level and product-level analysis impossible. Order-item grain enables full drill-down.

> For order count: `COUNT(DISTINCT order_id)` — not `COUNT(*)`

### 2. Why Intermediate Layer Exists (not staging → marts directly)?

- `stg_olist__payments` has multiple rows per order (installments, multiple payment types) — direct join to fact table causes **fan-out** (revenue 3x inflated)
- `int_order_payments_summary` aggregates first, then joins — 1:1 relationship guaranteed
- Business logic (delivery delay calculation, SLA flags) isolated in intermediate — single place to update

### 3. Why Surrogate Keys?

Natural keys (customer_unique_id, seller_id) can change if source systems change. Surrogate keys via `dbt_utils.generate_surrogate_key()` are stable, source-independent MD5 hashes — safe for multi-source expansion.

### 4. Why Ephemeral for Intermediate?

Intermediate models are "helper" models — end users never query them directly. Ephemeral = zero Snowflake storage cost, no extra objects. They compile as CTEs inside downstream fact/dim models.

### 5. Why SCD Type 1 for dim_customers (not SCD Type 2)?

Customer city/state historical tracking has no business value for UrbanKart's current analytics use cases. dim_sellers will get SCD Type 2 via snapshot in Phase 6 — seller status changes matter for commission dispute audits (Phase 3 Req #2).

---

## Data Quality

### Tests Implemented

| Test Type | Count | Example |
|---|---|---|
| `not_null` | 12 | order_id, customer_unique_id |
| `unique` | 8 | order_id in staging, customer_key in dim |
| `accepted_values` | 3 | order_status, review_score [1-5] |
| `relationships` | 1 | customer_key FK check |

### Source Freshness

Configured on `ORDERS` table:
- **warn_after:** 24 hours
- **error_after:** 48 hours

Business justification: Logistics Manager's SLA dashboard depends on daily-fresh order data (Phase 3 Req #1).

---

## Business Requirements Traceability

| Req # | Stakeholder | Requirement | Implemented In |
|---|---|---|---|
| #1 | Logistics Manager | Daily-fresh SLA tracking | `int_delivery_performance` + source freshness |
| #2 | Ops Team | Seller status history for audit | Phase 6 — `snp_sellers` snapshot |
| #3 | Finance Lead | Payment type + installment analysis | `int_order_payments_summary` |
| #4 | Finance | Multi-currency support | Phase 6 — seed + macro |
| #5 | CX Lead | Late delivery → bad review correlation | `fct_reviews` |
| #6 | CX | Review score validation [1-5] | `accepted_values` test |
| #7 | Head of Data | Self-serve documentation | dbt docs + column descriptions |
| #8 | Head of Data | Automated data quality gate | dbt tests + CI/CD (Phase 7) |
| #9 | Data Science | Safe downstream consumption | Exposures (Phase 6) |
| #10 | AE Lead | Cost control — no full rebuilds | Incremental models (Phase 6) |
| #11 | Engineering | No bad code in production | Git PR workflow + CI/CD (Phase 7) |

---

## Snowflake Setup

```sql
-- Warehouse (cost-optimized)
CREATE WAREHOUSE DBT_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60        -- 60 seconds idle = auto suspend
  AUTO_RESUME = TRUE;

-- Schemas
CREATE DATABASE AE_PROJECTS;
CREATE SCHEMA AE_PROJECTS.RAW;        -- Raw landing zone
CREATE SCHEMA AE_PROJECTS.STAGING;    -- dbt staging views
CREATE SCHEMA AE_PROJECTS.MARTS;      -- dbt mart tables

-- Dedicated role (not ACCOUNTADMIN for transformations)
CREATE ROLE TRANSFORMER_ROLE;
GRANT ROLE TRANSFORMER_ROLE TO USER <your_user>;
```

> **Why XS warehouse + auto-suspend?**
> Cost governance — warehouse auto-suspends after 60s idle.
> Mentioned to interviewers as evidence of cost-aware engineering.

---

## How to Run This Project

### Prerequisites
- Snowflake account (free trial works)
- Python 3.8+
- dbt-core + dbt-snowflake installed

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/sominathavhad26/urbankart_analytics.git
cd urbankart_analytics

# 2. Install dbt packages
dbt deps

# 3. Configure profiles.yml (~/.dbt/profiles.yml)
urbankart_analytics:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your_account>
      user: <your_user>
      password: <your_password>
      role: TRANSFORMER_ROLE
      warehouse: DBT_WH
      database: AE_PROJECTS
      schema: RAW
      threads: 4

# 4. Test connection
dbt debug

# 5. Run all models
dbt run

# 6. Run tests
dbt test

# 7. Check source freshness
dbt source freshness

# 8. Generate docs
dbt docs generate
dbt docs serve
```

---

## Git Workflow

```
main (protected — stable)
  ↓
feature/<topic> branch
  ↓
PR with description + checklist
  ↓
Review (self or peer)
  ↓
Merge to main
```

### Branch History

| Branch | Purpose | Status |
|---|---|---|
| `feature/staging-layer` | 9 staging models + tests + docs | ✅ Merged |
| `feature/intermediate-layer` | 3 intermediate models | ✅ Merged |
| `feature/marts-layer` | 6 mart models (dim + fct) | ✅ Merged |

### Commit Convention

```
feat:    new model or feature
fix:     bug fix or correction
test:    tests added or updated
docs:    documentation only
chore:   config, setup, non-feature
refactor: code improvement, no behavior change
```

---

## KPIs This Project Enables

| KPI | Definition | Model |
|---|---|---|
| GMV | SUM(price + freight_value) | `fct_orders` |
| AOV | GMV / COUNT(DISTINCT order_id) | `fct_orders` |
| On-time delivery rate | % orders delivered ≤ estimated date | `fct_orders` |
| Avg delivery delay (days) | AVG(delivery_delay_days) | `fct_orders` |
| Seller SLA breach rate | % items shipped after shipping_limit | `fct_orders` |
| Installment usage rate | % payments with installments > 1 | `fct_orders` |
| Avg review score | AVG(review_score) | `fct_reviews` |
| Late delivery → bad review % | % negative reviews with late delivery | `fct_reviews` |
| Repeat customer rate | % customers with > 1 order | `fct_orders` + `dim_customers` |
| Top categories by revenue | SUM(price) by category | `fct_orders` + `dim_products` |

---

## Coming Next (Phases 6-8)

- **Phase 7:** GitHub Actions CI/CD — automated `dbt run + dbt test` on every PR
- **Phase 8:** Power BI dashboard — GMV, delivery SLA, seller scorecard, CX analysis

---

## About

Built by **Sominath Avhad** — Senior Analytics Professional (5 years) transitioning to Analytics Engineering.

**Connect:** [LinkedIn](https://linkedin.com/in/sominathavhad) | [GitHub](https://github.com/sominathavhad26)

> *"This project simulates what I would build on Day 1 as an Analytics Engineer — requirements-first, tested, documented, and version-controlled."*
