{#
    Custom generic test: fails for every row where the column is below zero.
    Usage in YAML:   data_tests: [not_negative]
#}
{% test not_negative(model, column_name) %}
    select {{ column_name }}
    from {{ model }}
    where {{ column_name }} < 0
{% endtest %}
