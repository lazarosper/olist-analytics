{#
    Dynamic data masking, managed as code.  Both macros only return one SQL
    statement.  dim_customers runs them as hooks:

        pre-hook    create_masking_policy()         the policy exists
        post-hook   apply_masking_policy('city')    the policy is on the column

    The policy is evaluated at query time against the role of whoever is
    querying: PII_READER (or a role that inherits it) sees the real value,
    everyone else, including the BI role REPORTER, sees a fixed mask.
    The data is stored once; no masked copy has to be maintained.
#}
{% macro create_masking_policy() -%}
    create masking policy if not exists {{ target.database }}.governance.mask_pii_string
    as (val string) returns string ->
        case
            when is_role_in_session('PII_READER') then val
            else '***MASKED***'
        end
{%- endmacro %}

{% macro apply_masking_policy(column, policy='mask_pii_string') -%}
    alter table {{ this }} modify column {{ column }}
        set masking policy {{ target.database }}.governance.{{ policy }} force
{%- endmacro %}
