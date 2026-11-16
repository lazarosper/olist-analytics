-- Grain: one row per order.
-- Order-level view of the business: money, payment, delivery and satisfaction.
-- Every input is already at order grain, so each join is 1:1 and nothing can
-- be double-counted.

with

orders as (

    select * from {{ ref('stg_olist__orders') }}

),

customers as (

    select * from {{ ref('stg_olist__customers') }}

),

order_items as (

    select * from {{ ref('int_order_items__aggregated_to_order') }}

),

order_payments as (

    select * from {{ ref('int_order_payments__aggregated_to_order') }}

),

order_reviews as (

    select * from {{ ref('int_order_reviews__latest_per_order') }}

),

delivery as (

    select * from {{ ref('int_orders__delivery_metrics') }}

),

joined as (

    select
        orders.order_id,
        {{ dbt_utils.generate_surrogate_key(['customers.customer_unique_id_hashed']) }} as customer_key,
        orders.purchased_at::date as order_date,
        orders.order_status,
        {{ is_revenue_order('orders.order_status') }} as is_revenue_order,

        orders.purchased_at,
        orders.approved_at,
        orders.shipped_at,
        orders.delivered_at,
        orders.estimated_delivery_date,

        coalesce(order_items.item_count, 0) as item_count,
        coalesce(order_items.items_amount, 0) as items_amount,
        coalesce(order_items.freight_amount, 0) as freight_amount,

        coalesce(order_payments.payment_total, 0) as payment_total,
        order_payments.primary_payment_type,
        order_payments.max_installments,

        delivery.is_delivered,
        delivery.days_to_deliver,
        delivery.delivery_delay_days,
        delivery.is_late_delivery,
        delivery.delivery_status,

        order_reviews.review_score,
        coalesce(order_reviews.has_review_comment, false) as has_review_comment

    from orders
    left join customers
        on orders.customer_id = customers.customer_id
    left join order_items
        on orders.order_id = order_items.order_id
    left join order_payments
        on orders.order_id = order_payments.order_id
    left join order_reviews
        on orders.order_id = order_reviews.order_id
    left join delivery
        on orders.order_id = delivery.order_id

),

final as (

    select
        *,
        case when is_revenue_order then items_amount else 0 end as net_revenue
    from joined

)

select * from final
