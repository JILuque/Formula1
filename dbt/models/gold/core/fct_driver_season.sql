------------------------------------------------------------
-- fct_driver_season: score compuesto por piloto y temporada (1 fila por piloto y temporada).
-- score = (z_c1 - z_c2 + z_c3) / 3  -> pesos exactos de 1/3; C2 resta porque es una tasa de incidentes (peor cuanto mayor).
-- Los z-scores se calculan dentro de cada temporada y solo con muestras fiables (is_reliable_sample),
-- para que un piloto con 1 carrera no distorsione la media ni la desviación. Si no es fiable, el score es null.
-- Incremental (merge): los z-scores se calculan dentro de cada temporada, así que solo se recalcula desde la última temporada cargada.
-- Limitación asumida: hereda la de C3 (el C3 de temporadas anteriores no se actualiza hasta un --full-refresh periódico).
------------------------------------------------------------

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_driver_season',
    on_schema_change='fail'
) }}

with c1 as (
    select id_driver, season_year, n_duels, c1_win_rate
    from {{ ref('int_f1__driver_season_c1') }}
),

c2 as (
    select id_driver, season_year, n_races, n_incidents, c2_incident_rate
    from {{ ref('int_f1__driver_season_c2') }}
    {% if is_incremental() %}
    where season_year >= (select max(season_year) from {{ this }})
    {% endif %}
),

c3 as (
    select id_driver, season_year, n_races as n_races_valid, c3_positions_vs_car
    from {{ ref('int_f1__driver_season_c3') }}
),

-- C2 es la base: tiene una fila por cada piloto que tomó la salida en la temporada
joined as (

    select
        c2.id_driver,
        c2.season_year,
        c2.n_races,
        c1.n_duels,
        c3.n_races_valid,
        c1.c1_win_rate,
        c2.c2_incident_rate,
        c3.c3_positions_vs_car,
        coalesce(c3.n_races_valid >= {{ var('min_valid_races') }} and c1.n_duels >= {{ var('min_duels') }}, false) as is_reliable_sample
    from c2
    left join c1 on c2.id_driver = c1.id_driver and c2.season_year = c1.season_year
    left join c3 on c2.id_driver = c3.id_driver and c2.season_year = c3.season_year

),

z_scores as (

    select
        *,
        {{ z_score('c1_win_rate') }} as z_c1,
        {{ z_score('c2_incident_rate') }} as z_c2,
        {{ z_score('c3_positions_vs_car') }} as z_c3
    from joined

)

select
    {{ dbt_utils.generate_surrogate_key(['id_driver', 'season_year']) }} as id_driver_season,
    id_driver,
    season_year,
    n_races,
    n_duels,
    n_races_valid,
    is_reliable_sample,
    c1_win_rate,
    c2_incident_rate,
    c3_positions_vs_car,
    z_c1,
    z_c2,
    z_c3,
    case when is_reliable_sample then (z_c1 - z_c2 + z_c3) / 3 end as score
from z_scores
