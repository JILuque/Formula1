{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_race'
) }}

with calendar as (
    select * from {{ ref('stg_f1__calendario') }}
    where season_year between {{ var('season_start') }} and {{ var('season_end') }}
    {% if is_incremental() %}
      and season_year >= (select max(season_year) from {{ this }})
    {% endif %}
)

select
      md5(concat_ws('|', season_year, round)) as id_race
    , season_year
    , round
    , race_name
    , race_date
    , sprint_date is not null as has_sprint
    , md5(circuit_ref) as id_circuit
    , circuit_ref
from calendar