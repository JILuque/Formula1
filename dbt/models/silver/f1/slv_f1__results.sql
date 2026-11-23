{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_result',
    on_schema_change='fail'
) }}

with results as (
    select * from {{ ref('stg_f1__resultados') }}
    where season_year between {{ var('season_start') }} and {{ var('season_end') }}
    {% if is_incremental() %}
      and season_year >= (select max(season_year) from {{ this }})
    {% endif %}
),

status as (
    select * from {{ ref('status_classification') }}
)

select
      {{ dbt_utils.generate_surrogate_key(['r.season_year', 'r.round', 'r.driver_ref']) }} as id_result
    , {{ dbt_utils.generate_surrogate_key(['r.season_year', 'r.round']) }} as id_race
    , {{ dbt_utils.generate_surrogate_key(['r.driver_ref']) }} as id_driver
    , {{ dbt_utils.generate_surrogate_key(['r.constructor_ref']) }} as id_constructor
    , r.season_year
    , r.round
    , r.car_number
    , r.grid
    , r.position
    , r.position_order
    , r.position is not null                                     as is_classified
    , r.points
    , r.laps
    , r.race_time_ms
    , r.status
    , s.status_category
from results r
left join status s
    on r.status = s.status