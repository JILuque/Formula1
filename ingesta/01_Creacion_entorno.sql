-- =============================================================================
-- 01 · Entorno Snowflake del proyecto
-- =============================================================================
-- Crea el warehouse, las databases de los tres entornos y un rol de
-- transformación por entorno, siguiendo la convención Cívica:
--   {ENV}_BRONZE_DB / {ENV}_SILVER_DB / {ENV}_GOLD_DB  y  {ENV}_TRANSFORM_ROLE
-- Ejecútalo entero en una worksheet de Snowsight: "Run all".
-- =============================================================================

-- 1. Warehouse: el más pequeño, con suspensión automática a los 60 s para no
--    gastar créditos de la trial mientras no se usa.
use role sysadmin;
create warehouse if not exists WH_PROYECTO
    warehouse_size = 'XSMALL'
    auto_suspend = 60
    auto_resume = true
    initially_suspended = true;

-- 2. Databases. Bronze se crea solo en DEV; PRE y PRO serán clones (script 03).
create database if not exists DEV_BRONZE_DB;
create schema if not exists DEV_BRONZE_DB.f1;

create database if not exists DEV_SILVER_DB;
create database if not exists DEV_GOLD_DB;
create database if not exists PRE_SILVER_DB;
create database if not exists PRE_GOLD_DB;
create database if not exists PRO_SILVER_DB;
create database if not exists PRO_GOLD_DB;

-- 3. Roles de transformación: uno por entorno. dbt usa siempre el del entorno
--    en el que trabaja, y el de DEV no puede escribir en PRE ni en PRO.
use role securityadmin;
create role if not exists DEV_TRANSFORM_ROLE;
create role if not exists PRE_TRANSFORM_ROLE;
create role if not exists PRO_TRANSFORM_ROLE;

-- Rol de lectura para consumidores
create role if not exists REPORTING_ROLE;

-- SYSADMIN hereda los roles funcionales
grant role DEV_TRANSFORM_ROLE to role sysadmin;
grant role PRE_TRANSFORM_ROLE to role sysadmin;
grant role PRO_TRANSFORM_ROLE to role sysadmin;
grant role REPORTING_ROLE to role sysadmin;

-- En la trial, tu usuario hará de desarrollador y de usuario de los jobs.
-- En un proyecto real, los jobs usan un usuario de servicio.
select current_user();
grant role DEV_TRANSFORM_ROLE to user "joig.luque";
grant role PRE_TRANSFORM_ROLE to user "joig.luque";
grant role PRO_TRANSFORM_ROLE to user "joig.luque";

-- 4. Warehouse para los tres roles
grant usage on warehouse WH_PROYECTO to role DEV_TRANSFORM_ROLE;
grant usage on warehouse WH_PROYECTO to role PRE_TRANSFORM_ROLE;
grant usage on warehouse WH_PROYECTO to role PRO_TRANSFORM_ROLE;

-- 5. Cada rol puede crear schemas solo en las databases Silver y Gold de su
--    entorno. Quien crea un schema es su propietario: dbt podrá crear y
--    reemplazar tablas y vistas dentro sin más grants.
grant usage, create schema on database DEV_SILVER_DB to role DEV_TRANSFORM_ROLE;
grant usage, create schema on database DEV_GOLD_DB   to role DEV_TRANSFORM_ROLE;
grant usage, create schema on database PRE_SILVER_DB to role PRE_TRANSFORM_ROLE;
grant usage, create schema on database PRE_GOLD_DB   to role PRE_TRANSFORM_ROLE;
grant usage, create schema on database PRO_SILVER_DB to role PRO_TRANSFORM_ROLE;
grant usage, create schema on database PRO_GOLD_DB   to role PRO_TRANSFORM_ROLE;

-- Comprobación: deben aparecer las 7 databases
use role sysadmin;
show databases like '%_DB';
