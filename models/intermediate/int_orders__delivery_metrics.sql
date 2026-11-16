-- Grain: one row per order.
-- Business rules about delivery performance live here, in one place, so the
-- fact table and every dashboard agree on what "late" means.

with

orders as (

    select * from {{ ref('stg_olist__orders') }}

),

final as (

    select
        order_id,
        delivered_at is not null as is_delivered,
        datediff('day', purchased_at, delivered_at) as days_to_deliver,
        -- positive = arrived after the promised date, negative = early
        datediff('day', estimated_delivery_date, delivered_at::date) as delivery_delay_days,
        case
            when delivered_at is null then null
            else delivered_at::date > estimated_delivery_date
        end as is_late_delivery,
        case
            when delivered_at is null then 'Not delivered'
            when delivered_at::date > estimated_delivery_date then 'Late'
            else 'On time'
        end as delivery_status
    from orders

)

select * from final
