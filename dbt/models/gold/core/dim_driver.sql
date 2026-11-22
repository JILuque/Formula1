------------------------------------------------------------
-- dim_driver: una fila por piloto (2000-2024) con sus datos y un resumen de su carrera en el periodo.
-- Las métricas de carrera (carreras, victorias, podios) se calculan solo con carreras en las que tomó la salida.
------------------------------------------------------------

with drivers as (

    select
        id_driver,
        driver_ref,
        driver_full_name,
        driver_dob,
        driver_code,
        driver_nationality,
        last_season_year
    from {{ ref('slv_f1__drivers') }}

),

results as (

    select id_driver, season_year, position_order, status_category
    from {{ ref('slv_f1__results') }}
    where coalesce(status_category, 'unknown') <> 'not_started'

),

career as (

    select
        id_driver,
        min(season_year) as first_season_year,
        count(distinct season_year) as n_seasons,
        count(*) as n_races,
        sum(case when position_order = 1 then 1 else 0 end) as n_wins,
        sum(case when position_order <= 3 then 1 else 0 end) as n_podiums
    from results
    group by id_driver

)

select
    d.id_driver,
    d.driver_ref,
    d.driver_full_name,
    d.driver_dob,
    d.driver_code,
    d.driver_nationality,
    c.first_season_year,
    d.last_season_year,
    coalesce(c.n_seasons, 0) as n_seasons,
    coalesce(c.n_races, 0) as n_races,
    coalesce(c.n_wins, 0) as n_wins,
    coalesce(c.n_podiums, 0) as n_podiums
from drivers d
left join career c on d.id_driver = c.id_driver