{#
    Keeps one row per key: the most recently loaded version.

    RAW tables are append-only, so the same business key can arrive more than
    once (a re-sent file, or a changed row such as an order moving from
    'shipped' to 'delivered').  Every staging model calls this macro so that
    everything downstream can rely on "one row per key, latest state".

    Arguments
        relation      CTE or relation name to read from
        partition_by  column(s) that identify one business entity
        order_by      what "latest" means (default: load time, then file position)
#}
{% macro deduplicate_latest(relation, partition_by, order_by='_loaded_at desc, _file_row_number desc') -%}
    select *
    from {{ relation }}
    qualify row_number() over (
        partition by {{ partition_by }}
        order by {{ order_by }}
    ) = 1
{%- endmacro %}
