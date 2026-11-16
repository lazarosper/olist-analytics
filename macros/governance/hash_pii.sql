{#
    Pseudonymises an identifier with a salted SHA-256 hash.

    Deterministic, so the hashed value still works as a join key and for
    counting distinct customers, but the original identifier cannot be read or
    looked up.  NULL stays NULL.

    The salt comes from the environment variable OLIST_PII_SALT (a GitHub
    secret in CI/CD), which stops anyone re-computing the hash from a known id.
      * prod refuses to build without it: no silent fallback to a known value
      * dev and ci fall back to a fixed development salt, so a new developer
        can run the project without any secret
    Changing the salt changes every customer key, so it requires a full refresh.
#}
{% macro pii_salt() %}
    {% set salt = env_var('OLIST_PII_SALT', '') | trim %}
    {% if salt == '' %}
        {% if target.name == 'prod' %}
            {{ exceptions.raise_compiler_error("OLIST_PII_SALT is not set. Production must hash identifiers with the real salt.") }}
        {% endif %}
        {% set salt = 'dev-only-salt' %}
    {% endif %}
    {{ return(salt) }}
{% endmacro %}

{% macro hash_pii(column) -%}
    sha2(concat({{ column }}, '{{ pii_salt() }}'), 256)
{%- endmacro %}
