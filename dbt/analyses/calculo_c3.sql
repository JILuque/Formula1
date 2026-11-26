-- Puesto esperado de C3 por puesto en el campeonato de constructores (2000-2024).
-- Es la misma media que calcula int_f1__driver_season_c3, pero agrupada y visible:
-- media de la posicion final en carrera de los coches de los equipos que acabaron N-esimos.
-- Se ejecuta con Preview en el IDE de dbt (usa ref()).

with results as (

    select id_constructor, season_year, position_order, status_category
    from {{ ref('slv_f1__results') }}

),

sprint as (

    select id_constructor, season_year, points
    from {{ ref('slv_f1__sprint_results') }}

),

constructor_points as (

    select season_year, id_constructor, sum(points) as points, sum(wins) as wins
    from (
        select season_year, id_constructor, points,
               case when position_order = 1 then 1 else 0 end as wins
        from {{ ref('slv_f1__results') }}
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
        rank() over (partition by season_year order by points desc, wins desc) as constructor_rank
    from constructor_points

)

select
    c.constructor_rank                  as puesto_constructor,
    count(*)                            as resultados_considerados,
    count(distinct r.season_year)       as temporadas,
    round(avg(r.position_order), 2)     as puesto_esperado
from results r
join constructor_rank c
    on r.season_year = c.season_year
    and r.id_constructor = c.id_constructor
where coalesce(r.status_category, 'unknown') not in ('mechanical', 'not_started')
group by c.constructor_rank
order by c.constructor_rank