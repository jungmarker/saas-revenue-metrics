{# Generic test: no duplicate rows for the given column combination (dependency-free version of dbt_utils.unique_combination_of_columns). #}
{% test dbt_utils_unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count(*) as n
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
