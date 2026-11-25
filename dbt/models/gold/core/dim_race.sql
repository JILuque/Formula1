------------------------------------------------------------
-- dim_race: una fila por carrera (2000-2024) con los datos del circuito ya incluidos.
------------------------------------------------------------

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='id_race',
    on_schema_change='fail'
) }}

with races as (

    select id_race, season_year, round, race_name, race_date, has_sprint, id_circuit
    from {{ ref('slv_f1__races') }}

),

circuits as (

    select id_circuit, circuit_name, circuit_location, circuit_country, circuit_lat, circuit_lng, circuit_altitude_m
    from {{ ref('slv_f1__circuits') }}

)

select
    r.id_race,
    r.season_year,
    r.round,
    r.race_name,
    r.race_date,
    r.has_sprint,
    c.circuit_name,
    c.circuit_location,
    c.circuit_country,
    c.circuit_lat,
    c.circuit_lng,
    c.circuit_altitude_m
from races r
left join circuits c on r.id_circuit = c.id_circuit