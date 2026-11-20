{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_circuit'
) }}

with calendar as (
    select * from {{ ref('stg_f1__calendario') }}
    where season_year between {{ var('season_start') }} and {{ var('season_end') }}
    {% if is_incremental() %}
      and season_year >= (select max(last_season_year) from {{ this }})
    {% endif %}
),

latest as (
    select
          circuit_ref
        , circuit_name
        , circuit_location
        , circuit_country
        , circuit_lat
        , circuit_lng
        , circuit_altitude_m
        , season_year as last_season_year
        , row_number() over (
            partition by circuit_ref
            order by season_year desc, round desc
          ) as rn
    from calendar
)

select
      md5(circuit_ref) as id_circuit
    , circuit_ref
    , circuit_name
    , circuit_location
    , circuit_country
    , circuit_lat
    , circuit_lng
    , circuit_altitude_m
    , last_season_year
from latest
where rn = 1