{% macro time_to_ms(column_name) %}
    round(
        ( try_cast(split_part({{ column_name }}, ':', 1) as int) * 60
        + try_cast(split_part({{ column_name }}, ':', 2) as number(8, 3))
        ) * 1000
    )::int
{% endmacro %}