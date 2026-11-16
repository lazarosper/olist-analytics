{#
    on-run-end hook.  SELECT on mart tables is handled by the `grants` config in
    dbt_project.yml, but Snowflake also requires USAGE on the schema, which dbt
    does not manage.  This closes the gap for every marts schema built in the run,
    so REPORTER can read the gold layer and nothing else.
#}
{% macro grant_marts_usage(schemas) %}
    {% if execute and flags.WHICH in ('run', 'build') %}
        {% for schema in schemas %}
            {% if (schema | lower | trim).endswith('marts') %}
                {% do run_query('grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role reporter') %}
                {% do log('Granted USAGE on ' ~ target.database ~ '.' ~ schema ~ ' to REPORTER', info=true) %}
            {% endif %}
        {% endfor %}
    {% endif %}
{% endmacro %}
