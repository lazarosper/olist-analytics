{#
    The one definition of "this order counts as a sale".

    An order earns revenue unless its status is in the project variable
    `non_revenue_order_statuses` (canceled, unavailable).  Every model that
    needs the rule calls this macro, so changing the business definition is a
    one-line change in dbt_project.yml.

    Renders to:   <status_column> not in ('canceled', 'unavailable')
#}
{% macro is_revenue_order(status_column) -%}
    {{ status_column }} not in (
        {%- for status in var('non_revenue_order_statuses') -%}
            '{{ status }}'{{ ", " if not loop.last }}
        {%- endfor -%}
    )
{%- endmacro %}
