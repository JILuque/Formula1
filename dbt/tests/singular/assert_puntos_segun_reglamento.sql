-----------------------------------------------------------------------------
-- Los puntos que trae el origen (resultados y sprint) deben coincidir con el
-- reglamento de su época, guardado en la seed points_scoring_system.
-- Es un test de calidad del dato de origen: ningún modelo recalcula los puntos.
--
-- Punto válido = puntos de la seed para esa época y posición clasificada
--                (0 si la posición no puntúa), o ese valor + fastest_lap_bonus
--                (punto extra por vuelta rápida, 2019-2024, solo en carrera).
-- Carreras con reglas especiales, documentadas aquí y no excluidas del test:
--   2009 ronda 2  (Malasia, carrera acortada) -> mitad de puntos
--   2014 ronda 19 (Abu Dabi)                  -> doble de puntos
--   2021 ronda 12 (Spa, carrera casi sin disputar) -> mitad de puntos
-- severity warn: si cambia el reglamento y la seed no se actualiza, avisa
-- pero no rompe el despliegue.
-----------------------------------------------------------------------------

{{ config(severity='warn') }}

with excepciones as (

    select * from (values
          (2009, 2, 0.5)
        , (2014, 19, 2.0)
        , (2021, 12, 0.5)
    ) as t(season_year, round, points_multiplier)

),

sesiones as (

    select 'race' as session_type, season_year, round, id_driver, position, points
    from {{ ref('slv_f1__results') }}
    where position is not null

    union all

    select 'sprint' as session_type, season_year, round, id_driver, position, points
    from {{ ref('slv_f1__sprint_results') }}
    where position is not null

),

comparacion as (

    select
          s.session_type
        , s.season_year
        , s.round
        , s.id_driver
        , s.position
        , s.points
        , coalesce(r.points, 0) * coalesce(e.points_multiplier, 1)    as expected_points
        , coalesce(r.fastest_lap_bonus, 0)                            as fastest_lap_bonus
    from sesiones s
    left join {{ ref('points_scoring_system') }} r
        on  r.session_type = s.session_type
        and s.season_year between r.season_from and r.season_to
        and r.position = s.position
    left join excepciones e
        on  e.season_year = s.season_year
        and e.round = s.round
        and s.session_type = 'race'

)

select *
from comparacion
where round(points, 2) <> round(expected_points, 2)
  and round(points, 2) <> round(expected_points + fastest_lap_bonus, 2)
