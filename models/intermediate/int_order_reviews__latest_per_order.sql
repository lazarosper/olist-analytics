-- Grain: one row per order.
-- A customer can answer the satisfaction survey more than once for the same
-- order.  The most recent answer is the one that counts.

with

reviews as (

    select * from {{ ref('stg_olist__order_reviews') }}

),

review_counts as (

    select
        order_id,
        count(*) as review_count
    from reviews
    group by order_id

),

latest_review as (

    {{ deduplicate_latest(
        'reviews',
        partition_by='order_id',
        order_by='review_answered_at desc, review_created_at desc, review_id'
    ) }}

),

final as (

    select
        latest_review.order_id,
        latest_review.review_score,
        latest_review.review_created_at,
        latest_review.review_answered_at,
        -- only the fact that a comment exists leaves this layer, not the text
        latest_review.review_comment_message is not null as has_review_comment,
        review_counts.review_count
    from latest_review
    inner join review_counts
        on latest_review.order_id = review_counts.order_id

)

select * from final
