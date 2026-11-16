with

source as (

    select * from {{ source('olist', 'order_items') }}

),

deduplicated as (

    {{ deduplicate_latest('source', partition_by='order_id, order_item_id') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }} as order_item_key,
        order_id,
        try_to_number(order_item_id) as order_item_number,
        product_id,
        seller_id,
        try_to_timestamp_ntz(shipping_limit_date) as shipping_limit_at,
        try_to_decimal(price, 18, 2) as item_price,
        try_to_decimal(freight_value, 18, 2) as freight_value,
        _loaded_at as loaded_at
    from deduplicated

)

select * from renamed
