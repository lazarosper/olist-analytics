# Power BI report: Olist Revenue

A Power BI **project** (PBIP): the semantic model is TMDL text and the report is
PBIR JSON, so both are versioned and reviewed like code.

```
Olist_Revenue.pbip               open this file in Power BI Desktop
Olist_Revenue.SemanticModel/     tables, relationships, measures (TMDL)
Olist_Revenue.Report/            2 pages, 27 visuals (PBIR)
EXPECTED_NUMBERS.md              what every card should show, computed with SQL
```

## What it connects to

| | |
|---|---|
| Source | Snowflake, `ANALYTICS_PROD.MARTS` (the dbt gold layer), nothing else |
| Mode | Import |
| Connector | native Snowflake connector, `Implementation = "2.0"` (ADBC driver) |
| Role | `REPORTER` (read-only, marts only) |
| Warehouse | `REPORTING_WH` |
| Parameters | `SnowflakeServer`, `SnowflakeWarehouse` (Transform data > Edit parameters) |

The committed value of `SnowflakeServer` is a placeholder,
`<your_account>.snowflakecomputing.com`. Set your own account address once under
Transform data > Edit parameters before the first refresh.

Each table is one short Power Query: navigate to the mart table, select the
columns, rename them from `UPPER_SNAKE_CASE` to readable names, set the types.
No joins and no business logic in Power Query.

## Model

Star schema, single-direction filters from dimensions to facts:

| Power BI table | dbt model | Grain | Related to |
|---|---|---|---|
| Order Items | `fct_order_items` | one row per item of an order | Date, Customers, Products, Sellers |
| Orders | `fct_orders` | one row per order | Date, Customers |
| Customers | `dim_customers` | one row per person | |
| Products | `dim_products` | one row per product | |
| Sellers | `dim_sellers` | one row per seller | |
| Date | `dim_date` | one row per day, marked as date table | |

The two facts are **not** related to each other. They share Date and Customers,
so a Year or State slicer filters both. A Category slicer filters Order Items only,
because an order has no single category.

Measures live in the `_Measures` table, in four folders (Revenue, Customers,
Delivery, Satisfaction). The DAX is deliberately thin: the definition of net
revenue, of "late" and of "revenue order" is in dbt, so the report only sums,
counts and divides. Each measure has a one-sentence description (hover over it
in the Data pane).

## First refresh (one time)

The repository contains no data and no credentials, so the report opens empty
with a yellow "Refresh now" banner.

1. Open `Olist_Revenue.pbip` in Power BI Desktop.
2. Click **Refresh now** (or Home > Refresh).
3. In the Snowflake sign-in dialog choose **Key Pair** in the left-hand list:
   - **Username:** `SVC_POWERBI`
   - **Private key:** browse to the `.p8` key file of the service user
     (on the author's PC: `C:\Users\<you>\.snowflake\svc_powerbi_rsa_key.p8`)
   - **Passphrase:** leave empty, the key is not encrypted (the field only
     appears for encrypted keys)
4. Click **Connect**. Six tables load, about 350k rows in total.
5. Compare the cards with [EXPECTED_NUMBERS.md](EXPECTED_NUMBERS.md).

Power BI stores the credential in Windows, not in the project files. To change
it later: File > Options and settings > Data source settings.

### If "Key Pair" is not in the dialog

Microsoft documents Key Pair authentication for the Snowflake connector (it
always uses the ADBC driver), but it arrived in Desktop during 2025, so an older
build may only show "Snowflake" (username + password) and "Microsoft Account".

1. Preferred: update Power BI Desktop to the current version and retry.
2. Alternative: create a programmatic access token for the service user in
   Snowflake (`ALTER USER SVC_POWERBI ADD PROGRAMMATIC ACCESS TOKEN ...`; Snowflake
   may require a network policy for the user first), then choose **Snowflake**
   in the dialog and enter `SVC_POWERBI` as username and the token as password.

A personal username + password does not work: Snowflake enforces MFA for
people, and the connector cannot answer an MFA prompt.

## Why some columns show `***MASKED***`

`Customers[City]` and `Customers[Zip Code Prefix]` carry a Snowflake dynamic
masking policy (`ANALYTICS_PROD.GOVERNANCE.MASK_PII_STRING`). The policy is
evaluated for the role that runs the query. `SVC_POWERBI` only has `REPORTER`,
so Snowflake returns the mask and the real values never leave the warehouse or
enter the Power BI file. `Customers[State]` is not masked (27 values, too coarse
to identify anyone), which is why the regional charts use State.

The same reason explains what you cannot see at all: `REPORTER` has no access to
`RAW`, `STAGING` or `INTERMEDIATE`, so the navigator only lists the `MARTS` schema.

## Pages

**1. Revenue overview**: six KPI cards (net revenue, orders, average order value,
customers, late delivery %, average review score), net revenue by month, top 10
categories, net revenue by customer state. Slicers: Year, Category.

**2. Delivery & satisfaction**: late delivery %, average days to deliver, review
score on time vs late and the gap between them, net revenue delivered late;
average review score by delivery status, late delivery % by month and by state,
orders by review score. Slicers: Year, Customer state.

The finding on page 2: an order delivered late scores about 2.3 stars, an order
delivered on time about 4.3. Late delivery costs roughly two stars.

## Design notes

- **Import, not DirectQuery.** 350k rows load in seconds and every click is
  instant, with no warehouse running per interaction. The trade-off is that the
  report shows the state of the last refresh; press Refresh after a dbt run.
  DirectQuery would be the choice for much larger or near-real-time data.
- **Top 10 without a visual filter.** `Net Revenue (Top 10 Categories)` ranks the
  categories with `RANKX` and returns blank beyond position 10, so the bar chart
  needs no hidden filter and still reacts to the slicers.
- **Orders is counted on Order Items**, not on Orders, so that it also responds
  to Category and Seller. Orders without items (never a sale) are not counted.
- **Auto date/time is off.** Time intelligence uses the `Date` table from dbt.
