# Architecture

## 1. End-to-end flow

```mermaid
flowchart LR
    subgraph Source
        CSV[Olist extracts<br/>CSV batches]
    end

    subgraph Snowflake
        subgraph RAW["RAW.OLIST  (bronze)"]
            R[7 append-only tables<br/>all VARCHAR + audit columns]
        end
        subgraph ANALYTICS["ANALYTICS_PROD  (silver + gold)"]
            S[STAGING<br/>7 views: cast, rename,<br/>deduplicate, hash PII]
            I[INTERMEDIATE<br/>4 views: one row per order]
            M[MARTS<br/>star schema: 2 facts, 4 dims<br/>masking policy on PII]
            H[SNAPSHOTS<br/>order history, SCD2]
        end
    end

    subgraph BI
        P[Power BI<br/>role REPORTER]
    end

    CSV -- "ingestion/load_raw.py<br/>PUT + COPY INTO (role LOADER)" --> R
    R -- "dbt (role TRANSFORMER)" --> S --> I --> M
    S --> H
    M --> P
```

| Layer | Medallion | Where | Materialisation | Rule |
|---|---|---|---|---|
| Raw | Bronze | `RAW.OLIST` | tables, append-only | Never modified. Every column `VARCHAR`. |
| Staging | Silver | `ANALYTICS_*.STAGING` | views | One model per source table. Only place that reads `source()`. |
| Intermediate | Silver | `ANALYTICS_*.INTERMEDIATE` | views | Change grain, apply business rules. Not for BI. |
| Marts | Gold | `ANALYTICS_*.MARTS` | tables (item fact: incremental) | Kimball star schema. Only layer BI can read. |

## 2. Star schema (gold layer)

```mermaid
erDiagram
    dim_date      ||--o{ fct_order_items : "order_date"
    dim_customers ||--o{ fct_order_items : "customer_key"
    dim_products  ||--o{ fct_order_items : "product_key"
    dim_sellers   ||--o{ fct_order_items : "seller_key"
    dim_date      ||--o{ fct_orders      : "order_date"
    dim_customers ||--o{ fct_orders      : "customer_key"
    fct_orders    ||--o{ fct_order_items : "order_id"

    fct_order_items {
        varchar order_item_key PK
        varchar order_id
        varchar customer_key FK
        varchar product_key FK
        varchar seller_key FK
        date    order_date FK
        varchar order_status
        boolean is_revenue_order
        number  item_price
        number  freight_value
        number  net_revenue
        timestamp loaded_at
    }
    fct_orders {
        varchar order_id PK
        varchar customer_key FK
        date    order_date FK
        varchar order_status
        boolean is_revenue_order
        number  net_revenue
        number  payment_total
        varchar primary_payment_type
        number  days_to_deliver
        boolean is_late_delivery
        varchar delivery_status
        number  review_score
    }
    dim_customers {
        varchar customer_key PK
        varchar customer_unique_id_hashed "hashed"
        varchar zip_code_prefix "masked"
        varchar city "masked"
        varchar state_code
        number  lifetime_order_count
        boolean is_repeat_customer
    }
    dim_products {
        varchar product_key PK
        varchar product_id
        varchar category_name
        number  weight_g
    }
    dim_sellers {
        varchar seller_key PK
        varchar seller_id
        varchar city
        varchar state_code
    }
    dim_date {
        date    date_day PK
        varchar year_month
        number  year_number
        varchar month_name
        boolean is_weekend
    }
```

Two facts at two grains, sharing conformed dimensions:

- `fct_order_items`: one row per **item**. Answers "what was sold" (product, seller, category).
- `fct_orders`: one row per **order**. Answers "how did the order go" (payment, delivery, review).

Payments and reviews exist per order, not per item, so they cannot sit on the
item fact without being repeated on every item row and double-counted.

## 3. Environments

| Target | Database | Schemas | Who writes | Trigger |
|---|---|---|---|---|
| `dev` | `ANALYTICS_DEV` | `DBT_LAZAROS_<LAYER>` | developer | manual `dbt build` |
| `ci` | `ANALYTICS_CI` | `PR_<number>_<LAYER>` | GitHub Actions | every pull request, dropped afterwards |
| `prod` | `ANALYTICS_PROD` | `<LAYER>` | GitHub Actions | merge to `main`, daily schedule |

All three read the same `RAW` database. The schema naming is one macro:
`macros/utils/generate_schema_name.sql`.

## 4. Access control

```mermaid
flowchart TB
    ACCOUNTADMIN --> SYSADMIN
    SYSADMIN --> LOADER
    SYSADMIN --> TRANSFORMER
    SYSADMIN --> PII_READER
    PII_READER --> REPORTER
```

| Role | Warehouse | Can do | Cannot do |
|---|---|---|---|
| `LOADER` | `LOADING_WH` | write `RAW.OLIST` | read analytics |
| `TRANSFORMER` | `TRANSFORMING_WH` | read `RAW`, own `ANALYTICS_*` | — |
| `REPORTER` | `REPORTING_WH` | read `ANALYTICS_PROD.MARTS`, PII masked | read raw, staging, intermediate |
| `PII_READER` | `REPORTING_WH` | same as `REPORTER`, PII unmasked | — |

Three layers of protection for personal data:

1. **Hashing** (`macros/governance/hash_pii.sql`): the person identifier is replaced by a salted SHA-256 in staging.
2. **Dynamic masking** (`macros/governance/masking_policies.sql`): postcode prefix and city in `dim_customers` are shown only to `PII_READER`.
3. **Minimisation + RBAC**: free-text review comments stay in staging; `REPORTER` has no access to that schema.
