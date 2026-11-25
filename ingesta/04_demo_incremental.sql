-- =============================================================================
-- 04_demo_incremental.sql  ·  Procedimientos para la DEMO del incremental (solo DEV)
-- =============================================================================
-- Que hace: crea dos procedimientos en DEV_BRONZE_DB.public que dbt llama desde
-- macros (dbt run-operation):
--   sp_demo_cargar()  -> borra los datos de prueba si estaban y carga
--                        calendario_test.csv y resultados_test.csv con COPY INTO.
--   sp_demo_limpiar() -> borra los datos de prueba de Bronze.
-- Y dos tasks sin horario (task_demo_cargar y task_demo_limpiar) que solo llaman a
-- esos procedimientos. Los macros insertar_incremental y limpiar_incremental las
-- lanzan con `execute task`, asi que son la pieza que une dbt con Snowflake.
--
-- execute as owner: se ejecutan con los permisos de SYSADMIN (propietario de las
-- tablas), asi que DEV_TRANSFORM_ROLE solo necesita USAGE sobre ellos y Bronze
-- sigue siendo de solo lectura para dbt.
--
-- Antes de ejecutarlo: subir calendario_test.csv y resultados_test.csv al stage
-- DEV_BRONZE_DB.public.carga_bronze (Snowsight, igual que en el script 02).
-- =============================================================================

use role sysadmin;
use warehouse WH_PROYECTO;

create or replace procedure DEV_BRONZE_DB.public.sp_demo_cargar()
returns varchar
language sql
execute as owner
as
$$
begin
    -- idempotente: si habia datos de prueba, se quitan antes de cargar
    delete from DEV_BRONZE_DB.f1.calendario where season_year = 2025 and round = 99;
    delete from DEV_BRONZE_DB.f1.resultados where season_year = 2025 and round = 99;

    copy into DEV_BRONZE_DB.f1.calendario
        (season_year, round, race_name, race_date, race_time, race_url, fp1_date, fp1_time, fp2_date, fp2_time, fp3_date, fp3_time, quali_date, quali_time, sprint_date, sprint_time, circuit_ref, circuit_name, circuit_location, circuit_country, circuit_lat, circuit_lng, circuit_alt, circuit_url)
    from @DEV_BRONZE_DB.public.carga_bronze files = ('calendario_test.csv')
    file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze')
    force = true;

    copy into DEV_BRONZE_DB.f1.resultados
        (season_year, round, driver_forename, driver_surname, driver_dob, driver_ref, driver_number, driver_code, driver_nationality, driver_url, constructor_ref, constructor_name, constructor_nationality, constructor_url, car_number, grid, position, position_text, position_order, points, laps, race_time_text, race_time_ms, fastest_lap, fastest_lap_rank, fastest_lap_time, fastest_lap_speed, status)
    from @DEV_BRONZE_DB.public.carga_bronze files = ('resultados_test.csv')
    file_format = (format_name = 'DEV_BRONZE_DB.public.csv_bronze')
    force = true;

    return 'Cargados en Bronze: calendario_test.csv y resultados_test.csv';
end;
$$;

create or replace procedure DEV_BRONZE_DB.public.sp_demo_limpiar()
returns varchar
language sql
execute as owner
as
$$
begin
    delete from DEV_BRONZE_DB.f1.calendario where season_year = 2025 and round = 99;
    delete from DEV_BRONZE_DB.f1.resultados where season_year = 2025 and round = 99;
    return 'Borrados de Bronze los datos de prueba (2025, ronda 99)';
end;
$$;

-- Permiso para que dbt (DEV_TRANSFORM_ROLE) pueda llamarlos
grant usage on schema DEV_BRONZE_DB.public to role DEV_TRANSFORM_ROLE;
grant usage on procedure DEV_BRONZE_DB.public.sp_demo_cargar()   to role DEV_TRANSFORM_ROLE;
grant usage on procedure DEV_BRONZE_DB.public.sp_demo_limpiar()  to role DEV_TRANSFORM_ROLE;

-- -----------------------------------------------------------------------------
-- Tasks que usan los macros de dbt (sin SCHEDULE: solo se lanzan a mano con EXECUTE TASK)
-- -----------------------------------------------------------------------------
create or replace task DEV_BRONZE_DB.public.task_demo_cargar
    warehouse = WH_PROYECTO
    comment = 'Demo incremental: carga los datos de prueba en Bronze (la lanza el macro insertar_incremental)'
as
    call DEV_BRONZE_DB.public.sp_demo_cargar();

create or replace task DEV_BRONZE_DB.public.task_demo_limpiar
    warehouse = WH_PROYECTO
    comment = 'Demo incremental: borra los datos de prueba de Bronze (la lanza el macro limpiar_incremental)'
as
    call DEV_BRONZE_DB.public.sp_demo_limpiar();

-- Para lanzar una task con EXECUTE TASK hacen falta dos cosas:
--   1) que el rol propietario de la task (SYSADMIN) tenga el privilegio global EXECUTE TASK
--      (solo lo puede conceder ACCOUNTADMIN; se hace una vez por cuenta)
--   2) que el rol que ejecuta (DEV_TRANSFORM_ROLE, el de dbt) tenga OPERATE sobre la task
use role accountadmin;
grant execute task on account to role sysadmin;

use role sysadmin;
grant operate on task DEV_BRONZE_DB.public.task_demo_cargar  to role DEV_TRANSFORM_ROLE;
grant operate on task DEV_BRONZE_DB.public.task_demo_limpiar to role DEV_TRANSFORM_ROLE;

-- Comprobacion rapida (como SYSADMIN): deben salir las dos tasks
show tasks in schema DEV_BRONZE_DB.public;
