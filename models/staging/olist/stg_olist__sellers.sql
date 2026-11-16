with

source as (

    select * from {{ source('olist', 'sellers') }}

),

deduplicated as (

    {{ deduplicate_latest('source', partition_by='seller_id') }}

),

renamed as (

    select
        seller_id,
        seller_zip_code_prefix as zip_code_prefix,
        initcap(seller_city) as city,
        upper(seller_state) as state_code,
        _loaded_at as loaded_at
    from deduplicated

)

select * from renamed
