-- =============================================================================
-- 03 · Bronze para PRE y PRO (zero-copy clone) y permisos de lectura
-- =============================================================================
-- Un clon no duplica el almacenamiento al crearse: comparte los datos con el
-- original y solo ocupa espacio lo que cambie después. Es la forma más barata
-- de tener la misma Bronze en los tres entornos.
-- Los permisos sobre la database original no pasan al clon: se conceden aquí
-- para los tres entornos.
-- =============================================================================

use role sysadmin;
create or replace database PRE_BRONZE_DB clone DEV_BRONZE_DB;
create or replace database PRO_BRONZE_DB clone DEV_BRONZE_DB;

-- Lectura de Bronze: cada rol, solo la de su entorno
use role securityadmin;
grant usage on database DEV_BRONZE_DB to role DEV_TRANSFORM_ROLE;
grant usage on all schemas in database DEV_BRONZE_DB to role DEV_TRANSFORM_ROLE;
grant select on all tables in database DEV_BRONZE_DB to role DEV_TRANSFORM_ROLE;

grant usage on database PRE_BRONZE_DB to role PRE_TRANSFORM_ROLE;
grant usage on all schemas in database PRE_BRONZE_DB to role PRE_TRANSFORM_ROLE;
grant select on all tables in database PRE_BRONZE_DB to role PRE_TRANSFORM_ROLE;

grant usage on database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;
grant usage on all schemas in database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;
grant select on all tables in database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;

-- Comprobación con el rol de desarrollo: debe devolver 26759
use role DEV_TRANSFORM_ROLE;
use warehouse WH_PROYECTO;
select count(*) from DEV_BRONZE_DB.f1.results;
