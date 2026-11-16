-- Grain: one row per order.
-- Items are many-per-order.  They are collapsed to order grain here, BEFORE
-- being joined to payments (also many-per-order).  Joining the two detail
-- tables directly would multiply rows and double-count money (a fan-out).

with

order_items as (

    select * from {{ ref('stg_olist__order_items') }}

),

aggregated as (

    select
        order_id,
        count(*) as item_count,
        count(distinct product_id) as distinct_product_count,
        count(distinct seller_id) as distinct_seller_count,
        sum(item_price) as items_amount,
        sum(freight_value) as freight_amount
    from order_items
    group by order_id

)

select * from aggregated
