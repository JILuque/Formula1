{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_qualifying'
) }}

with qualifying as (
    select * from {{ ref('stg_f1__clasificacion') }}
    where season_year between {{ var('season_start') }} and {{ var('season_end') }}
    {% if is_incremental() %}
      and season_year >= (select max(season_year) from {{ this }})
    {% endif %}
)

select
      md5(concat_ws('|', season_year, round, driver_ref))  as id_qualifying
    , md5(concat_ws('|', season_year, round))              as id_race
    , md5(driver_ref)                                      as id_driver
    , md5(quali_constructor_ref)                           as id_constructor
    , season_year
    , round
    , quali_car_number                                     as car_number
    , quali_position                                       as position
    , {{ time_to_ms('q1') }} as q1_ms
    , {{ time_to_ms('q2') }} as q2_ms
    , {{ time_to_ms('q3') }} as q3_ms
from qualifying