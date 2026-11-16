with

source as (

    select * from {{ source('olist', 'customers') }}

),

deduplicated as (

    {{ deduplicate_latest('source', partition_by='customer_id') }}

),

renamed as (

    select
        -- customer_id is generated per ORDER by the source system.
        customer_id,
        -- customer_unique_id identifies the PERSON.  It is pseudonymised here,
        -- at the first layer dbt controls, so the raw identifier never reaches
        -- intermediate or mart models.
        {{ hash_pii('customer_unique_id') }} as customer_unique_id_hashed,
        customer_zip_code_prefix as zip_code_prefix,
        initcap(customer_city) as city,
        upper(customer_state) as state_code,
        _loaded_at as loaded_at
    from deduplicated

)

select * from renamed
