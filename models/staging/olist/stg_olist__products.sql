with

source as (

    select * from {{ source('olist', 'products') }}

),

deduplicated as (

    {{ deduplicate_latest('source', partition_by='product_id') }}

),

renamed as (

    select
        product_id,
        product_category_name as category_name,
        -- the source column names contain typos ("lenght"); fixed here once
        try_to_number(product_name_lenght) as name_length,
        try_to_number(product_description_lenght) as description_length,
        try_to_number(product_photos_qty) as photo_count,
        try_to_number(product_weight_g) as weight_g,
        try_to_number(product_length_cm) as length_cm,
        try_to_number(product_height_cm) as height_cm,
        try_to_number(product_width_cm) as width_cm,
        _loaded_at as loaded_at
    from deduplicated

)

select * from renamed
