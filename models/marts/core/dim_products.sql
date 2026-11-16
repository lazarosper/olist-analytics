-- Grain: one row per product.

with

products as (

    select * from {{ ref('stg_olist__products') }}

),

category_translation as (

    select * from {{ ref('product_category_name_translation') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['products.product_id']) }} as product_key,
        products.product_id,
        -- English name when a translation exists, else the original, else a
        -- clear placeholder so reports never show a blank category
        coalesce(
            initcap(replace(category_translation.product_category_name_english, '_', ' ')),
            initcap(replace(products.category_name, '_', ' ')),
            'Unknown'
        ) as category_name,
        products.category_name as category_name_original,
        products.photo_count,
        products.weight_g,
        products.length_cm * products.height_cm * products.width_cm as volume_cm3
    from products
    left join category_translation
        on products.category_name = category_translation.product_category_name

)

select * from final
