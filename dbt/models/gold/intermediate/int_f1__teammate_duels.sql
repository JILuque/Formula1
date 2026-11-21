------------------------------------------------------------------------------
--Duelos entre compañeros de equipo (base de C1)
--Empareja a cada piloto con su compañero en la misma carrera, sesión y equipo, y compara posiciones.
--Cada duelo genera dos filas, una desde cada piloto (win_duel es verdadero para el que gana).
--Excluye averías (mechanical) y no salidas (not_started) en carrera y sprint,
--y los pilotos sin tiempo de Q1 en clasificación.
-----------------------------------------------------------------------------

{{ config(materialized='ephemeral') }}

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

sessions as (
    select * from race
    union all
    select * from qualifying
    union all
    select * from sprint
)

select
      a.id_race
    , a.season_year
    , a.session_type
    , a.id_constructor
    , a.id_driver
    , b.id_driver as id_rival
    , a.rank_in_session < b.rank_in_session as win_duel
from sessions a
join sessions b
    on  a.id_race        = b.id_race
    and a.session_type   = b.session_type
    and a.id_constructor = b.id_constructor
    and a.id_driver     <> b.id_driver