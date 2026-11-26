-----------------------------------------------------------------------------
-- Ninguna medida numérica de Silver (puntos, parrilla, vueltas, tiempos en
-- milisegundos) puede ser negativa. Devuelve las filas con algún valor < 0.
-- Las posiciones ya las vigilan los accepted_range (mínimo 1) de los .yml.
-- grid = 0 es válido (salida desde el pit lane), por eso el límite es 0.
-----------------------------------------------------------------------------

select 'slv_f1__results' as tabla, id_result as id
from {{ ref('slv_f1__results') }}
where least(coalesce(points, 0), coalesce(grid, 0), coalesce(laps, 0), coalesce(race_time_ms, 0)) < 0

union all

select 'slv_f1__sprint_results' as tabla, id_sprint_result as id
from {{ ref('slv_f1__sprint_results') }}
where least(coalesce(points, 0), coalesce(grid, 0), coalesce(laps, 0), coalesce(sprint_time_ms, 0)) < 0

union all

select 'slv_f1__qualifying' as tabla, id_qualifying as id
from {{ ref('slv_f1__qualifying') }}
where least(coalesce(q1_ms, 0), coalesce(q2_ms, 0), coalesce(q3_ms, 0)) < 0
