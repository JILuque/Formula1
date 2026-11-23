{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_race',
    on_schema_change='fail'
) }}

with calendar as (
    select * from {{ ref('stg_f1__calendario') }}
    where season_year between {{ var('season_start') }} and {{ var('season_end') }}
    {% if is_incremental() %}
      and season_year >= (select max(season_year) from {{ this }})
    {% endif %}
)

select
      {{ dbt_utils.generate_surrogate_key(['season_year', 'round']) }} as id_race
    , season_year
    , round
    , race_name
    , race_date
    , sprint_date is not null as has_sprint
    , {{ dbt_utils.generate_surrogate_key(['circuit_ref']) }} as id_circuit
    , circuit_ref
from calendar