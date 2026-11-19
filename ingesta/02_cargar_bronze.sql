-- =============================================================================
-- 02 · Carga de Bronze desde los CSV del dataset de F1 
-- =============================================================================
-- Simula lo que haría la herramienta de ingesta: deja los datos crudos en
-- DEV_BRONZE_DB. Pasos:
--   1. Ejecuta la parte A (crea schema, stage, formato de fichero y tablas).
--   2. Sube los 8 CSV al stage DEV_BRONZE_DB.public.carga_bronze desde
--      Snowsight: abre el stage CARGA_BRONZE en el explorador de databases y
--      usa el botón para añadir ficheros.
--   3. Ejecuta la parte B (COPY INTO) y la comprobación final.
--
-- _loaded_at: cada tabla tiene una columna con DEFAULT current_timestamp(). El
-- COPY INTO no la menciona, así que Snowflake la rellena con el momento de la
-- carga. dbt la usa como loaded_at_field para el freshness.
--
-- Diferencias con el script de la plantilla (por la naturaleza de esta fuente):
--   - No hay columnas _fivetran_deleted ni _fivetran_synced: los datos vienen
--     de un CSV de Kaggle, no de Fivetran.
--   - El dataset marca los nulos como \N: el formato de fichero los trata como
--     NULL además de la cadena vacía.
--   - Los identificadores y tiempos se cargan como varchar; los tipos
--     definitivos se aplican en staging.
--   - Script sin probar. Si algún nombre de columna (rank, position, time,
--     date, number...) da error, ponlo entre comillas dobles.
-- =============================================================================
-- =============================================================================
-- 02 · Carga de Bronze desde los 3 ficheros planos del proyecto F1
-- =============================================================================
-- Los 3 ficheros (calendario, resultados, clasificacion) los genera el script
-- de /ingesta a partir de los 8 CSV de Kaggle. Simula lo que haria la
-- herramienta de ingesta: deja los datos crudos en DEV_BRONZE_DB. Pasos:
--   0. Limpieza: borra las 8 tablas antiguas de Bronze (si existen).
--   1. Ejecuta la parte A (crea schema, stage, formato de fichero y tablas).
--   2. Sube los 3 CSV al stage DEV_BRONZE_DB.public.carga_bronze desde
--      Snowsight: abre el stage CARGA_BRONZE en el explorador de databases y
--      usa el boton para anadir ficheros.
--   3. Ejecuta la parte B (COPY INTO) y la comprobacion final.
--   4. Vuelve a ejecutar el script 03 (clones de PRE y PRO), porque los clones
--      se crearon con las tablas antiguas.
--
-- _loaded_at: cada tabla tiene una columna con DEFAULT current_timestamp(). El
-- COPY INTO no la menciona, asi que Snowflake la rellena con el momento de la
-- carga.
--
-- Diferencias con el script de la plantilla (por la naturaleza de esta fuente):
--   - No hay columnas _fivetran_deleted ni _fivetran_synced: los datos vienen
--     de ficheros generados por un script, no de Fivetran.
--   - Los ficheros marcan los nulos como \N: el formato de fichero los trata
--     como NULL ademas de la cadena vacia.
--   - Los ficheros no llevan identificadores: las filas se identifican por
--     clave natural (season_year + round, driver_ref, constructor_ref). Los
--     ids se generaran en silver.
--   - Los tiempos se cargan como varchar; fechas y medidas, tipadas. Los tipos
--     definitivos se terminan de aplicar en staging.
--   - Todos los anos (1950-2024): el filtro 2000-2024 se aplica en silver/gold.
-- =============================================================================

use role sysadmin;
use warehouse WH_PROYECTO;

-- ================================ 0. LIMPIEZA ================================
-- Tablas del diseno anterior (8 CSV de Kaggle tal cual). Si no existen, no pasa nada.
drop table if exists DEV_BRONZE_DB.f1.circuits;
drop table if exists DEV_BRONZE_DB.f1.constructors;
drop table if exists DEV_BRONZE_DB.f1.drivers;
drop table if exists DEV_BRONZE_DB.f1.races;
drop table if exists DEV_BRONZE_DB.f1.status;
drop table if exists DEV_BRONZE_DB.f1.qualifying;
drop table if exists DEV_BRONZE_DB.f1.results;
drop table if exists DEV_BRONZE_DB.f1.sprint_results;

-- =================================== PARTE A =================================
create schema if not exists DEV_BRONZE_DB.f1;

create stage if not exists DEV_BRONZE_DB.public.carga_bronze
    comment = 'Ficheros CSV para la carga inicial de Bronze';

create file format if not exists DEV_BRONZE_DB.public.csv_bronze
    type = csv
    skip_header = 1
    field_optionally_enclosed_by = '"'
    null_if = ('', '\\N')
    empty_field_as_null = true;

create or replace table DEV_BRONZE_DB.f1.calendario (
      season_year                    number(4, 0)
    , round                          number(38, 0)
    , race_name                      varchar
    , race_date                      date
    , race_time                      varchar
    , race_url                       varchar
    , fp1_date                       date
    , fp1_time                       varchar
    , fp2_date                       date
    , fp2_time                       varchar
    , fp3_date                       date
    , fp3_time                       varchar
    , quali_date                     date
    , quali_time                     varchar
    , sprint_date                    date
    , sprint_time                    varchar
    , circuit_ref                    varchar
    , circuit_name                   varchar
    , circuit_location               varchar
    , circuit_country                varchar
    , circuit_lat                    number(10, 6)
    , circuit_lng                    number(10, 6)
    , circuit_alt                    number(10, 2)
    , circuit_url                    varchar
    , _loaded_at                     timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.resultados (
      season_year                    number(4, 0)
    , round                          number(38, 0)
    , driver_forename                varchar
    , driver_surname                 varchar
    , driver_dob                     date
    , driver_ref                     varchar
    , driver_number                  varchar
    , driver_code                    varchar
    , driver_nationality             varchar
    , driver_url                     varchar
    , constructor_ref                varchar
    , constructor_name               varchar
    , constructor_nationality        varchar
    , constructor_url                varchar
    , car_number                     varchar
    , grid                           number(38, 0)
    , position                       number(38, 0)
    , position_text                  varchar
    , position_order                 number(38, 0)
    , points                         number(10, 2)
    , laps                           number(38, 0)
    , race_time_text                 varchar
    , race_time_ms                   number(38, 0)
    , fastest_lap                    number(38, 0)
    , fastest_lap_rank               number(38, 0)
    , fastest_lap_time               varchar
    , fastest_lap_speed              number(10, 3)
    , status                         varchar
    , _loaded_at                     timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.clasificacion (
      season_year                    number(4, 0)
    , round                          number(38, 0)
    , driver_forename                varchar
    , driver_surname                 varchar
    , driver_dob                     date
    , driver_ref                     varchar
    , driver_number                  varchar
    , driver_code                    varchar
    , driver_nationality             varchar
    , driver_url                     varchar
    , quali_constructor_ref          varchar
    , quali_constructor_name         varchar
    , quali_constructor_nationality  varchar
    , quali_constructor_url          varchar
    , quali_car_number               varchar
    , quali_position                 number(38, 0)
    , q1                             varchar
    , q2                             varchar
    , q3                             varchar
    , sprint_constructor_ref         varchar
    , sprint_constructor_name        varchar
    , sprint_constructor_nationality varchar
    , sprint_constructor_url         varchar
    , sprint_car_number              varchar
    , sprint_grid                    number(38, 0)
    , sprint_position                number(38, 0)
    , sprint_position_text           varchar
    , sprint_position_order          number(38, 0)
    , sprint_points                  number(10, 2)
    , sprint_laps                    number(38, 0)
    , sprint_time_text               varchar
    , sprint_time_ms                 number(38, 0)
    , sprint_fastest_lap             number(38, 0)
    , sprint_fastest_lap_time        varchar
    , sprint_status                  varchar
    , _loaded_at                     timestamp_ltz default current_timestamp()
);

-- Antes de la parte B: comprueba que los 3 ficheros estan en el stage
list @DEV_BRONZE_DB.public.carga_bronze;

-- =================================== PARTE B =================================
-- La lista de columnas excluye _loaded_at: asi toma su DEFAULT.
copy into DEV_BRONZE_DB.f1.calendario
    (season_year, round, race_name, race_date, race_time, race_url, fp1_date, fp1_time, fp2_date, fp2_time, fp3_date, fp3_time, quali_date, quali_time, sprint_date, sprint_time, circuit_ref, circuit_name, circuit_location, circuit_country, circuit_lat, circuit_lng, circuit_alt, circuit_url)
from @DEV_BRONZE_DB.public.carga_bronze files = ('calendario.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.resultados
    (season_year, round, driver_forename, driver_surname, driver_dob, driver_ref, driver_number, driver_code, driver_nationality, driver_url, constructor_ref, constructor_name, constructor_nationality, constructor_url, car_number, grid, position, position_text, position_order, points, laps, race_time_text, race_time_ms, fastest_lap, fastest_lap_rank, fastest_lap_time, fastest_lap_speed, status)
from @DEV_BRONZE_DB.public.carga_bronze files = ('resultados.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.clasificacion
    (season_year, round, driver_forename, driver_surname, driver_dob, driver_ref, driver_number, driver_code, driver_nationality, driver_url, quali_constructor_ref, quali_constructor_name, quali_constructor_nationality, quali_constructor_url, quali_car_number, quali_position, q1, q2, q3, sprint_constructor_ref, sprint_constructor_name, sprint_constructor_nationality, sprint_constructor_url, sprint_car_number, sprint_grid, sprint_position, sprint_position_text, sprint_position_order, sprint_points, sprint_laps, sprint_time_text, sprint_time_ms, sprint_fastest_lap, sprint_fastest_lap_time, sprint_status)
from @DEV_BRONZE_DB.public.carga_bronze files = ('clasificacion.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

-- ============================== COMPROBACION =================================
-- Resultado esperado: calendario 1125 · resultados 26759 · clasificacion 10494
select 'calendario' as tabla, count(*) as filas from DEV_BRONZE_DB.f1.calendario union all
select 'resultados', count(*) from DEV_BRONZE_DB.f1.resultados union all
select 'clasificacion', count(*) from DEV_BRONZE_DB.f1.clasificacion;
