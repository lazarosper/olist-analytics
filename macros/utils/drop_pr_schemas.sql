{#
    Housekeeping for CI:  dbt run-operation drop_pr_schemas --args '{prefix: PR_12}'
    Drops every schema in the target database that starts with the prefix, so a
    merged or closed pull request leaves nothing behind in ANALYTICS_CI.
#}
{% macro drop_pr_schemas(prefix) %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error('drop_pr_schemas may only run against the ci target, not ' ~ target.name) }}
    {% endif %}
    {% set find_schemas %}
        select schema_name
        from {{ target.database }}.information_schema.schemata
        where startswith(schema_name, upper('{{ prefix }}_'))
    {% endset %}
    {% set results = run_query(find_schemas) %}
    {% for row in results %}
        {% do run_query('drop schema if exists ' ~ target.database ~ '.' ~ row[0] ~ ' cascade') %}
        {% do log('Dropped ' ~ target.database ~ '.' ~ row[0], info=true) %}
    {% endfor %}
{% endmacro %}
