{#
    Drops the snapshot tables of the current target so history starts again.

        dbt run-operation drop_snapshots --args '{confirm: true}'

    Snapshots are the one thing `dbt build --full-refresh` does not rebuild,
    on purpose: they hold history that cannot be recomputed from the source.
    This macro exists only to replay the two-batch demo from a clean state and
    refuses to run without an explicit confirm flag.
#}
{% macro drop_snapshots(confirm=false) %}
    {% if not confirm %}
        {{ exceptions.raise_compiler_error("drop_snapshots deletes history. Re-run with --args '{confirm: true}'.") }}
    {% endif %}
    {% if execute %}
        {% for node in graph.nodes.values() if node.resource_type == 'snapshot' %}
            {% set relation = api.Relation.create(database=node.database, schema=node.schema, identifier=node.alias) %}
            {% do run_query('drop table if exists ' ~ relation) %}
            {% do log('Dropped snapshot ' ~ relation, info=true) %}
        {% endfor %}
    {% endif %}
{% endmacro %}
