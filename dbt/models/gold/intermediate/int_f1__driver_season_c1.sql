------------------------------------------------------------------------------
--C1: duelo con el compañero de equipo
--C1 mide el porcentaje de duelos que un piloto gana a su compañero de equipo en una temporada.
--Un duelo es cada sesión (carrera, clasificación o sprint) en la que ambos compañeros compitieron
--y tienen un resultado válido; gana el que queda por delante. Al compartir coche, la comparación aísla el factor piloto.
--Se anula el duelo para los dos si alguno abandona por avería (mechanical) o no sale (not_started),
--y en clasificación si alguno no tiene tiempo de Q1.
--Cada duelo genera dos filas en el CTE duels, una desde cada piloto.
--Va con signo positivo en la puntuación final: más duelos ganados, mejor.
--Incremental (merge): un duelo solo depende de su temporada, así que se recalcula solo desde la última temporada cargada.
-----------------------------------------------------------------------------

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id_driver', 'season_year'],
    on_schema_change='fail'
) }}

with race as (
    select
          id_race, season_year, id_driver, id_constructor
        , position_order as rank_in_session
        , 'race' as session_type
    from {{ ref('slv_f1__results') }}
    where coalesce(status_category, 'unknown') not in ('mechanical', 'not_started')
),

qualifying as (
    select
          id_race, season_year, id_driver, id_constructor
        , position as rank_in_session
        , 'qualifying' as session_type
    from {{ ref('slv_f1__qualifying') }}
    where q1_ms is not null
),

sprint as (
    select
          id_race, season_year, id_driver, id_constructor
        , position_order as rank_in_session
        , 'sprint' as session_type
    from {{ ref('slv_f1__sprint_results') }}
    where coalesce(status_category, 'unknown') not in ('mechanical', 'not_started')
),

sessions_all as (
    select * from race
    union all
    select * from qualifying
    union all
    select * from sprint
),

sessions as (
    select * from sessions_all
    {% if is_incremental() %}
    where season_year >= (select max(season_year) from {{ this }})
    {% endif %}
),

duels as (
    select
          a.season_year
        , a.id_driver
        , a.rank_in_session < b.rank_in_session as win_duel
    from sessions a
    join sessions b
        on  a.id_race        = b.id_race
        and a.session_type   = b.session_type
        and a.id_constructor = b.id_constructor
        and a.id_driver     <> b.id_driver
)

select
      id_driver
    , season_year
    , count(*)                                  as n_duels
    , sum(case when win_duel then 1 else 0 end) as n_wins
    , n_wins / n_duels                          as c1_win_rate
from duels
group by id_driver, season_year