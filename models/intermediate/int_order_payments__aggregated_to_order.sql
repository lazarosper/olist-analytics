-- Grain: one row per order.
-- An order can be paid with several methods (for example a voucher plus a
-- credit card), each one a row in the source.  Collapsed to order grain here.

with

payments as (

    select * from {{ ref('stg_olist__order_payments') }}

),

aggregated as (

    select
        order_id,
        count(*) as payment_count,
        sum(payment_value) as payment_total,
        max(payment_installments) as max_installments,
        -- the method that paid the largest share of the order
        max_by(payment_type, payment_value) as primary_payment_type
    from payments
    group by order_id

)

select * from aggregated
