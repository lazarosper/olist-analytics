-- Data-quality monitor (singular, warn only).
-- What the customer paid should equal items + freight.  The source has a small
-- number of known mismatches (vouchers, rounding of instalments), so this test
-- warns when the count grows instead of blocking the pipeline.

{{ config(severity='warn', warn_if='>300') }}

select
    order_id,
    items_amount + freight_amount as order_value,
    payment_total,
    payment_total - (items_amount + freight_amount) as difference
from {{ ref('fct_orders') }}
where
    is_revenue_order
    and item_count > 0
    and abs(payment_total - (items_amount + freight_amount)) > 1
