------------------------------------------------------------------------------
--C2: abandonos atribuibles al piloto
--C2 mide con qué frecuencia un piloto termina su carrera por un error o incidente suyo en pista 
--(driver_incident: Collision, Accident, Spun off y Collision damage). 
--Va con signo negativo en la puntuación final: más incidentes, peor.
--Incremental (merge): solo depende de su temporada, así que se recalcula desde la última temporada cargada.
-----------------------------------------------------------------------------

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id_driver', 'season_year'],
    on_schema_change='fail'
) }}

select
      id_driver
    , season_year
    , count(*)                                                       as n_races
    , sum(case when status_category = 'driver_incident' then 1 else 0 end) as n_incidents
    , n_incidents / n_races                                          as c2_incident_rate
from {{ ref('slv_f1__results') }}
where coalesce(status_category, 'unknown') <> 'not_started'
{% if is_incremental() %}
  and season_year >= (select max(season_year) from {{ this }})
{% endif %}
group by id_driver, season_year