------------------------------------------------------------
-- C3: Rendimiento del piloto frente al nivel de su coche.
-- Nivel del coche = puesto del constructor en el campeonato de esa temporada (se calcula una vez por temporada).
-- Puntos del constructor = carreras + sprint (reproduce el campeonato oficial de constructores).
-- Los constructores empatados a puntos y victorias comparten puesto (rank), sin orden arbitrario.
-- Puesto esperado = media de puesto final de los coches de ese puesto de constructor (todas las temporadas 2000-2024).
-- c3_positions_vs_car = media de (puesto esperado - puesto final): positivo = rinde por encima de su coche.
-- Opción A: se excluyen carreras con estado mechanical (y not_started). Granularidad: 1 fila por piloto y temporada.
-- Incremental (merge): el puesto esperado se calcula con TODO el histórico (se lee entero, es pequeño), pero solo se escriben
-- las filas desde la última temporada cargada. Limitación asumida: al entrar una temporada nueva, la media cambia y el C3 de las
-- temporadas anteriores no se actualiza hasta lanzar un --full-refresh (se haría de forma periódica).
------------------------------------------------------------

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id_driver', 'season_year'],
    on_schema_change='fail'
) }}

with results as (

    select id_driver, id_constructor, season_year, position_order, points, status_category
    from {{ ref('slv_f1__results') }}

),

sprint as (

    select id_constructor, season_year, points
    from {{ ref('slv_f1__sprint_results') }}

),

-- Puntos de carrera + sprint por constructor y temporada. Desempate: victorias; si siguen empatados comparten puesto (rank)
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
        rank() over (
            partition by season_year
            order by points desc, wins desc
        ) as constructor_rank
    from constructor_points

),

valid_races as (

    select
        r.id_driver,
        r.season_year,
        r.position_order,
        avg(r.position_order) over (partition by c.constructor_rank) as expected_position -- media de las posiciones por posicion en la clasificacion de constructores
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
    avg(expected_position - position_order) as c3_positions_vs_car
from valid_races
{% if is_incremental() %}
where season_year >= (select max(season_year) from {{ this }})
{% endif %}
group by id_driver, season_year