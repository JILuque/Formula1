{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_sprint_result'
) }}

with sprint as (
    select * from {{ ref('stg_f1__clasificacion') }}
    where season_year between {{ var('season_start') }} and {{ var('season_end') }}
      and sprint_constructor_ref is not null
    {% if is_incremental() %}
      and season_year >= (select max(season_year) from {{ this }})
    {% endif %}
),

status as (
    select * from {{ ref('status_classification') }}
)

select
      md5(concat_ws('|', sp.season_year, sp.round, sp.driver_ref)) as id_sprint_result
    , md5(concat_ws('|', sp.season_year, sp.round))                as id_race
    , md5(sp.driver_ref)                                           as id_driver
    , md5(sp.sprint_constructor_ref)                               as id_constructor
    , sp.season_year
    , sp.round
    , sp.sprint_car_number                                         as car_number
    , sp.sprint_grid                                               as grid
    , sp.sprint_position                                           as position
    , sp.sprint_position_order                                     as position_order
    , sp.sprint_position is not null                               as is_classified
    , sp.sprint_points                                             as points
    , sp.sprint_laps                                               as laps
    , sp.sprint_time_ms
    , sp.sprint_status                                             as status
    , st.status_category
from sprint sp
left join status st
    on sp.sprint_status = st.status