-- How the headline number of the dashboard is calculated, in plain SQL.
-- Compile with:  dbt compile --select net_revenue_by_month
-- This is the same logic Power BI runs: one fact, two dimensions, a sum.

select
    dim_date.year_month,
    count(distinct fct_order_items.order_id) as orders,
    sum(fct_order_items.net_revenue) as net_revenue,
    sum(fct_order_items.net_revenue) / nullif(count(distinct fct_order_items.order_id), 0) as average_order_value
from {{ ref('fct_order_items') }} as fct_order_items
inner join {{ ref('dim_date') }} as dim_date
    on fct_order_items.order_date = dim_date.date_day
where fct_order_items.is_revenue_order
group by dim_date.year_month
order by dim_date.year_month
