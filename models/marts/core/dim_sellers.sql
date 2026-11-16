-- Grain: one row per seller.
-- Sellers are businesses, so city and state are not personal data.

with

sellers as (

    select * from {{ ref('stg_olist__sellers') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['seller_id']) }} as seller_key,
        seller_id,
        city,
        state_code
    from sellers

)

select * from final
