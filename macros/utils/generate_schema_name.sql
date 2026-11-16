{#
    Decides which schema a model is built in.

    prod   -> the layer name alone                 ANALYTICS_PROD.MARTS
    dev/ci -> prefixed with the target schema      ANALYTICS_DEV.DBT_LAZAROS_MARTS
                                                   ANALYTICS_CI.PR_12_MARTS

    The prefix is what isolates developers and pull requests from each other
    while production keeps clean, stable names for BI tools.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema | trim }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema | trim }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
