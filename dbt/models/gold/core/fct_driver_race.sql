------------------------------------------------------------
-- fct_driver_race: tabla de hechos, una fila por piloto y carrera.
-- Claves hacia dim_driver, dim_constructor y dim_race, más las medidas de carrera, clasificación y sprint.
-- Incremental (merge): solo reprocesa desde la última temporada ya cargada.
------------------------------------------------------------

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_driver_race',
    on_schema_change='fail'
) }}

with enriched as (

    select * from {{ ref('gold_results__enriched') }}
    {% if is_incremental() %}
    where season_year >= (select max(season_year) from {{ this }})
    {% endif %}

)

select
    {{ dbt_utils.generate_surrogate_key(['id_race', 'id_driver']) }} as id_driver_race,
    id_race,
    id_driver,
    id_constructor,
    season_year,
    round,
    quali_position,
    q1_ms,
    q2_ms,
    q3_ms,
    grid,
    position_order,
    is_classified,
    status_category,
    laps,
    race_time_ms,
    points,
    coalesce(sprint_points, 0) as sprint_points,
    points + coalesce(sprint_points, 0) as total_points,
    sprint_position_order
from enriched