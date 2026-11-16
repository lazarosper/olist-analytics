with

source as (

    select * from {{ source('olist', 'order_reviews') }}

),

-- In the source one review_id can be attached to several orders, so the real
-- key of this table is (review_id, order_id), not review_id alone.
deduplicated as (

    {{ deduplicate_latest('source', partition_by='review_id, order_id') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }} as order_review_key,
        review_id,
        order_id,
        try_to_number(review_score) as review_score,
        -- Free text written by customers: it can contain names, phone numbers
        -- or addresses.  Kept in this restricted layer, never exposed in marts.
        review_comment_title,
        review_comment_message,
        try_to_timestamp_ntz(review_creation_date) as review_created_at,
        try_to_timestamp_ntz(review_answer_timestamp) as review_answered_at,
        _loaded_at as loaded_at
    from deduplicated

)

select * from renamed
