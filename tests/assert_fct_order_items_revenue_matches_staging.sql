-- Reconciliation test (singular).
-- The item fact joins items to orders and customers.  If any of those joins
-- ever multiplied or dropped rows, the money in the fact would stop matching
-- the money in staging.  Returns a row (= fails) when the totals differ.

with

staging as (

    select
        count(*) as row_count,
        sum(item_price) as total_item_price
    from {{ ref('stg_olist__order_items') }}

),

fact as (

    select
        count(*) as row_count,
        sum(item_price) as total_item_price
    from {{ ref('fct_order_items') }}

)

select
    staging.row_count as staging_rows,
    fact.row_count as fact_rows,
    staging.total_item_price as staging_total,
    fact.total_item_price as fact_total
from staging
cross join fact
where
    staging.row_count != fact.row_count
    or staging.total_item_price != fact.total_item_price
