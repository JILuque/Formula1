{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_driver'
) }}

with results as (
    select * from {{ ref('stg_f1__resultados') }}
    where season_year between {{ var('season_start') }} and {{ var('season_end') }}
    {% if is_incremental() %}
      and season_year >= (select max(last_season_year) from {{ this }})
    {% endif %}
),

latest as (
    select
          driver_ref
        , driver_forename
        , driver_surname
        , driver_dob
        , driver_code
        , driver_nationality
        , season_year as last_season_year
        , row_number() over (
            partition by driver_ref
            order by season_year desc, round desc
          ) as rn
    from results
)

select
      {{ dbt_utils.generate_surrogate_key(['driver_ref']) }} as id_driver
    , driver_ref
    , driver_forename
    , driver_surname
    , driver_forename || ' ' || driver_surname as driver_full_name
    , driver_dob
    , driver_code
    , driver_nationality
    , last_season_year
from latest
where rn = 1