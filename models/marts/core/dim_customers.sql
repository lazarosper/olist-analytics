{{
    config(
        pre_hook=[
            "create schema if not exists {{ target.database }}.governance",
            "{{ create_masking_policy() }}"
        ],
        post_hook=[
            "{{ apply_masking_policy('zip_code_prefix') }}",
            "{{ apply_masking_policy('city') }}"
        ]
    )
}}

-- Grain: one row per person (customer_unique_id_hashed).
-- The source creates a new customer_id for every order, so the same person
-- appears many times in stg_olist__customers.  This dimension collapses them
-- and keeps the address of the most recent order.

with

customers as (

    select * from {{ ref('stg_olist__customers') }}

),

orders as (

    select * from {{ ref('stg_olist__orders') }}

),

customer_orders as (

    select
        customers.customer_unique_id_hashed,
        customers.zip_code_prefix,
        customers.city,
        customers.state_code,
        orders.order_id,
        orders.purchased_at,
        orders.order_status
    from customers
    inner join orders
        on customers.customer_id = orders.customer_id

),

latest_address as (

    {{ deduplicate_latest(
        'customer_orders',
        partition_by='customer_unique_id_hashed',
        order_by='purchased_at desc, order_id'
    ) }}

),

order_history as (

    select
        customer_unique_id_hashed,
        min(purchased_at) as first_order_at,
        max(purchased_at) as last_order_at,
        count(*) as lifetime_order_count
    from customer_orders
    where {{ is_revenue_order('order_status') }}
    group by customer_unique_id_hashed

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['latest_address.customer_unique_id_hashed']) }} as customer_key,
        latest_address.customer_unique_id_hashed,
        latest_address.zip_code_prefix,
        latest_address.city,
        latest_address.state_code,
        order_history.first_order_at,
        order_history.last_order_at,
        coalesce(order_history.lifetime_order_count, 0) as lifetime_order_count,
        coalesce(order_history.lifetime_order_count, 0) > 1 as is_repeat_customer
    from latest_address
    left join order_history
        on latest_address.customer_unique_id_hashed = order_history.customer_unique_id_hashed

)

select * from final
