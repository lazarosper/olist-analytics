{#
    Dynamic data masking, managed as code.

    create_masking_policies()  runs on-run-start: makes sure the GOVERNANCE
                               schema and the policy exist in the target database.
    apply_masking_policy()     post-hook on a model: attaches the policy to a column.

    The policy is evaluated at query time against the role of whoever is
    querying: PII_READER (or a role that inherits it) sees the real value,
    everyone else, including the BI role REPORTER, sees a fixed mask.
    The data is stored once; no masked copy has to be maintained.
#}
{% macro governance_schema() -%}
    {{ target.database }}.governance
{%- endmacro %}

{% macro create_masking_policies() %}
    {% if execute and flags.WHICH in ('run', 'build') %}
        {% do run_query('create schema if not exists ' ~ governance_schema()) %}
        {% set policy_sql %}
            create masking policy if not exists {{ governance_schema() }}.mask_pii_string
            as (val string) returns string ->
                case
                    when is_role_in_session('PII_READER') then val
                    else '***MASKED***'
                end
            comment = 'Shows the value to PII_READER only. Managed by dbt (macros/governance).'
        {% endset %}
        {% do run_query(policy_sql) %}
        {% do log('Masking policy ready: ' ~ governance_schema() ~ '.mask_pii_string', info=true) %}
    {% endif %}
{% endmacro %}

{% macro apply_masking_policy(column, policy='mask_pii_string') -%}
    alter table {{ this }} modify column {{ column }}
        set masking policy {{ governance_schema() }}.{{ policy }} force
{%- endmacro %}
