------------------------------------------------------------
-- C3: Rendimiento del piloto frente al nivel de su coche.
-- Nivel del coche = puesto del constructor en el campeonato de esa temporada (se calcula una vez por temporada).
-- Puntos del constructor = carreras + sprint (reproduce el campeonato oficial de constructores).
-- Puesto esperado = 2 * puesto_constructor - 0.5 (cada equipo tiene 2 coches: el 1.º espera acabar 1.º-2.º, el 2.º 3.º-4.º...).
-- c3_positions_vs_car = media de (puesto esperado - puesto final): positivo = rinde por encima de su coche.
-- Opción A: se excluyen carreras con estado mechanical (y not_started). Granularidad: 1 fila por piloto y temporada.
------------------------------------------------------------

with results as (

    select id_driver, id_constructor, season_year, position_order, points, status_category
    from {{ ref('slv_f1__results') }}

),

sprint as (

    select id_constructor, season_year, points
    from {{ ref('slv_f1__sprint_results') }}

),

-- Puntos de carrera + sprint por constructor y temporada. Desempate: victorias y, por último, el id para que el orden sea siempre el mismo
constructor_points as (

    select
        season_year,
        id_constructor,
        sum(points) as points,
        sum(wins) as wins
    from (
        select season_year, id_constructor, points,
               case when position_order = 1 then 1 else 0 end as wins
        from results
        union all
        select season_year, id_constructor, points, 0 as wins
        from sprint
    )
    group by season_year, id_constructor

),

constructor_rank as (

    select
        season_year,
        id_constructor,
        row_number() over (
            partition by season_year
            order by points desc, wins desc, id_constructor
        ) as constructor_rank
    from constructor_points

),

valid_races as (

    select r.id_driver, r.season_year, c.constructor_rank, r.position_order
    from results r
    join constructor_rank c
        on r.season_year = c.season_year
        and r.id_constructor = c.id_constructor
    where coalesce(r.status_category, 'unknown') not in ('mechanical', 'not_started')

)

select
    id_driver,
    season_year,
    count(*) as n_races,
    avg((2 * constructor_rank - 0.5) - position_order) as c3_positions_vs_car
from valid_races
group by id_driver, season_year