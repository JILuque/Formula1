-- =============================================================================
-- 02 · Carga de Bronze desde los CSV del dataset de F1 (Kaggle)
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

use role sysadmin;
use warehouse WH_PROYECTO;

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

create or replace table DEV_BRONZE_DB.f1.circuits (
      circuitId           varchar
    , circuitRef          varchar
    , name                varchar
    , location            varchar
    , country             varchar
    , lat                 number(10, 6)
    , lng                 number(10, 6)
    , alt                 number(10, 2)
    , url                 varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.constructors (
      constructorId       varchar
    , constructorRef      varchar
    , name                varchar
    , nationality         varchar
    , url                 varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.drivers (
      driverId            varchar
    , driverRef           varchar
    , number              varchar
    , code                varchar
    , forename            varchar
    , surname             varchar
    , dob                 date
    , nationality         varchar
    , url                 varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.races (
      raceId              varchar
    , year                number(4, 0)
    , round               number(38, 0)
    , circuitId           varchar
    , name                varchar
    , date                date
    , time                varchar
    , url                 varchar
    , fp1_date            date
    , fp1_time            varchar
    , fp2_date            date
    , fp2_time            varchar
    , fp3_date            date
    , fp3_time            varchar
    , quali_date          date
    , quali_time          varchar
    , sprint_date         date
    , sprint_time         varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.status (
      statusId            varchar
    , status              varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.qualifying (
      qualifyId           varchar
    , raceId              varchar
    , driverId            varchar
    , constructorId       varchar
    , number              varchar
    , position            number(38, 0)
    , q1                  varchar
    , q2                  varchar
    , q3                  varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.results (
      resultId            varchar
    , raceId              varchar
    , driverId            varchar
    , constructorId       varchar
    , number              varchar
    , grid                number(38, 0)
    , position            number(38, 0)
    , positionText        varchar
    , positionOrder       number(38, 0)
    , points              number(10, 2)
    , laps                number(38, 0)
    , time                varchar
    , milliseconds        number(38, 0)
    , fastestLap          number(38, 0)
    , rank                number(38, 0)
    , fastestLapTime      varchar
    , fastestLapSpeed     number(10, 3)
    , statusId            varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

create or replace table DEV_BRONZE_DB.f1.sprint_results (
      resultId            varchar
    , raceId              varchar
    , driverId            varchar
    , constructorId       varchar
    , number              varchar
    , grid                number(38, 0)
    , position            number(38, 0)
    , positionText        varchar
    , positionOrder       number(38, 0)
    , points              number(10, 2)
    , laps                number(38, 0)
    , time                varchar
    , milliseconds        number(38, 0)
    , fastestLap          number(38, 0)
    , fastestLapTime      varchar
    , statusId            varchar
    , _loaded_at          timestamp_ltz default current_timestamp()
);

-- Antes de la parte B: comprueba que los 8 ficheros estan en el stage
list @DEV_BRONZE_DB.public.carga_bronze;

-- =================================== PARTE B =================================
-- La lista de columnas excluye _loaded_at: asi toma su DEFAULT.
copy into DEV_BRONZE_DB.f1.circuits
    (circuitId, circuitRef, name, location, country, lat, lng, alt, url)
from @DEV_BRONZE_DB.public.carga_bronze files = ('circuits.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.constructors
    (constructorId, constructorRef, name, nationality, url)
from @DEV_BRONZE_DB.public.carga_bronze files = ('constructors.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.drivers
    (driverId, driverRef, number, code, forename, surname, dob, nationality, url)
from @DEV_BRONZE_DB.public.carga_bronze files = ('drivers.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.races
    (raceId, year, round, circuitId, name, date, time, url, fp1_date, fp1_time, fp2_date, fp2_time, fp3_date, fp3_time, quali_date, quali_time, sprint_date, sprint_time)
from @DEV_BRONZE_DB.public.carga_bronze files = ('races.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.status
    (statusId, status)
from @DEV_BRONZE_DB.public.carga_bronze files = ('status.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.qualifying
    (qualifyId, raceId, driverId, constructorId, number, position, q1, q2, q3)
from @DEV_BRONZE_DB.public.carga_bronze files = ('qualifying.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.results
    (resultId, raceId, driverId, constructorId, number, grid, position, positionText, positionOrder, points, laps, time, milliseconds, fastestLap, rank, fastestLapTime, fastestLapSpeed, statusId)
from @DEV_BRONZE_DB.public.carga_bronze files = ('results.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

copy into DEV_BRONZE_DB.f1.sprint_results
    (resultId, raceId, driverId, constructorId, number, grid, position, positionText, positionOrder, points, laps, time, milliseconds, fastestLap, fastestLapTime, statusId)
from @DEV_BRONZE_DB.public.carga_bronze files = ('sprint_results.csv')
file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze');

-- ============================== COMPROBACION =================================
-- Resultado esperado: circuits 77 · constructors 212 · drivers 861 · races 1125 · status 139 · qualifying 10494 · results 26759 · sprint_results 360
select 'circuits' as tabla, count(*) as filas from DEV_BRONZE_DB.f1.circuits union all
select 'constructors', count(*) from DEV_BRONZE_DB.f1.constructors union all
select 'drivers', count(*) from DEV_BRONZE_DB.f1.drivers union all
select 'races', count(*) from DEV_BRONZE_DB.f1.races union all
select 'status', count(*) from DEV_BRONZE_DB.f1.status union all
select 'qualifying', count(*) from DEV_BRONZE_DB.f1.qualifying union all
select 'results', count(*) from DEV_BRONZE_DB.f1.results union all
select 'sprint_results', count(*) from DEV_BRONZE_DB.f1.sprint_results;
