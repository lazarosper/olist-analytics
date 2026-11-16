{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='order_item_key',
        on_schema_change='append_new_columns'
    )
}}

-- Grain: one row per item (line) of an order.  The most detailed sales fact:
-- every revenue number in the dashboard is a sum over this table.
--
-- Incremental logic
--   * High-watermark on LOAD time, not on order date.  An order that was
--     purchased months ago but changed status yesterday has a new loaded_at,
--     so it is picked up.  A filter on purchase date would miss it.
--   * MERGE on order_item_key: new items are inserted, items of changed orders
--     are updated in place (their status and revenue flag can change).

with

order_items as (

    select * from {{ ref('stg_olist__order_items') }}

),

orders as (

    select * from {{ ref('stg_olist__orders') }}

),

customers as (

    select * from {{ ref('stg_olist__customers') }}

),

joined as (

    select
        order_items.order_item_key,
        order_items.order_id,
        order_items.order_item_number,

        -- dimension keys
        {{ dbt_utils.generate_surrogate_key(['customers.customer_unique_id_hashed']) }} as customer_key,
        {{ dbt_utils.generate_surrogate_key(['order_items.product_id']) }} as product_key,
        {{ dbt_utils.generate_surrogate_key(['order_items.seller_id']) }} as seller_key,
        orders.purchased_at::date as order_date,

        -- order context
        orders.order_status,
        {{ is_revenue_order('orders.order_status') }} as is_revenue_order,

        -- measures
        order_items.item_price,
        order_items.freight_value,

        -- an item changes when the item row OR its order row is re-loaded
        greatest(order_items.loaded_at, orders.loaded_at) as loaded_at

    from order_items
    inner join orders
        on order_items.order_id = orders.order_id
    left join customers
        on orders.customer_id = customers.customer_id

),

final as (

    select
        order_item_key,
        order_id,
        order_item_number,
        customer_key,
        product_key,
        seller_key,
        order_date,
        order_status,
        is_revenue_order,
        item_price,
        freight_value,
        -- THE metric.  Net revenue = price of the items in orders that became
        -- a sale.  Freight is excluded: it is passed on to the carrier.
        case when is_revenue_order then item_price else 0 end as net_revenue,
        loaded_at
    from joined

)

select * from final

{% if is_incremental() %}

    where loaded_at > (select max(loaded_at) from {{ this }})

{% endif %}
