with

source as (

    select * from {{ source('olist', 'orders') }}

),

-- RAW is append-only: an order is re-sent every time its status changes.
deduplicated as (

    {{ deduplicate_latest('source', partition_by='order_id') }}

),

renamed as (

    select
        order_id,
        customer_id,
        lower(order_status) as order_status,
        try_to_timestamp_ntz(order_purchase_timestamp) as purchased_at,
        try_to_timestamp_ntz(order_approved_at) as approved_at,
        try_to_timestamp_ntz(order_delivered_carrier_date) as shipped_at,
        try_to_timestamp_ntz(order_delivered_customer_date) as delivered_at,
        try_to_timestamp_ntz(order_estimated_delivery_date)::date as estimated_delivery_date,
        _loaded_at as loaded_at
    from deduplicated

)

select * from renamed
