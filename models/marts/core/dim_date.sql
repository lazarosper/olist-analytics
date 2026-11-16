-- Grain: one row per calendar day.
-- Generated, not loaded: every day exists even if nothing was sold on it,
-- which is what time-intelligence in the BI tool needs.

with

date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('date_spine_start') ~ "' as date)",
        end_date="cast('" ~ var('date_spine_end') ~ "' as date)"
    ) }}

),

final as (

    select
        date_day::date as date_day,
        year(date_day) as year_number,
        quarter(date_day) as quarter_number,
        'Q' || quarter(date_day) as quarter_name,
        month(date_day) as month_number,
        monthname(date_day) as month_name,
        to_char(date_day, 'YYYY-MM') as year_month,
        date_trunc('month', date_day)::date as month_start_date,
        weekiso(date_day) as iso_week_number,
        dayofweekiso(date_day) as day_of_week_number,
        dayname(date_day) as day_name,
        dayofweekiso(date_day) in (6, 7) as is_weekend
    from date_spine

)

select * from final
