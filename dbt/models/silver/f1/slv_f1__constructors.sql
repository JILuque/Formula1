{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_constructor'
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
          constructor_ref
        , constructor_name
        , constructor_nationality
        , season_year as last_season_year
        , row_number() over (
            partition by constructor_ref
            order by season_year desc, round desc
          ) as rn
    from results
)

select
      md5(constructor_ref) as id_constructor
    , constructor_ref
    , constructor_name
    , constructor_nationality
    , last_season_year
from latest
where rn = 1