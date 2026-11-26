-----------------------------------------------------------------------------------
-- z-score de una columna dentro de cada temporada.
-- Media y desviación se calculan solo con las filas fiables (is_reliable_sample);
-- si la desviación es 0, devuelve null en vez de dividir por cero.
-- (valor − media) / desviación
-----------------------------------------------------------------------------------

{% macro z_score(column_name, partition_by='season_year', reliable_flag='is_reliable_sample') -%}
    (
        {{ column_name }}
        - avg(case when {{ reliable_flag }} then {{ column_name }} end) over (partition by {{ partition_by }})
    )
    / nullif(
        stddev_pop(case when {{ reliable_flag }} then {{ column_name }} end) over (partition by {{ partition_by }}),
        0
    )
{%- endmacro %}