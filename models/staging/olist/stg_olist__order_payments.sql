with

source as (

    select * from {{ source('olist', 'order_payments') }}

),

deduplicated as (

    {{ deduplicate_latest('source', partition_by='order_id, payment_sequential') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }} as order_payment_key,
        order_id,
        try_to_number(payment_sequential) as payment_sequence,
        lower(payment_type) as payment_type,
        try_to_number(payment_installments) as payment_installments,
        try_to_decimal(payment_value, 18, 2) as payment_value,
        _loaded_at as loaded_at
    from deduplicated

)

select * from renamed
