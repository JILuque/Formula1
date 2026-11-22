------------------------------------------------------------
-- gold_results__enriched: una fila por piloto y carrera, con la clasificación y el sprint del fin de semana unidos a la carrera.
-- Clasificación y sprint pueden ser nulos: faltan clasificaciones de 2000-2002 y solo hay sprint en 18 carreras.
------------------------------------------------------------

with results as (

    select
        id_race, id_driver, id_constructor, season_year, round,
        car_number, grid, position, position_order, is_classified,
        points, laps, race_time_ms, status, status_category
    from {{ ref('slv_f1__results') }}

),

qualifying as (

    select id_race, id_driver, position, q1_ms, q2_ms, q3_ms
    from {{ ref('slv_f1__qualifying') }}

),

sprint as (

    select id_race, id_driver, grid, position_order, points, status_category
    from {{ ref('slv_f1__sprint_results') }}

)

select
    r.id_race,
    r.id_driver,
    r.id_constructor,
    r.season_year,
    r.round,
    r.car_number,
    q.position       as quali_position,
    q.q1_ms,
    q.q2_ms,
    q.q3_ms,
    r.grid,
    r.position,
    r.position_order,
    r.is_classified,
    r.points,
    r.laps,
    r.race_time_ms,
    r.status,
    r.status_category,
    s.grid           as sprint_grid,
    s.position_order as sprint_position_order,
    s.points         as sprint_points,
    s.status_category as sprint_status_category
from results r
left join qualifying q on r.id_race = q.id_race and r.id_driver = q.id_driver
left join sprint s on r.id_race = s.id_race and r.id_driver = s.id_driver