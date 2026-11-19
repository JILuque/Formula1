-- =============================================================================
-- 03 · Bronze de PRO con zero-copy clone (proyecto con dos entornos: DEV y PRO)
-- =============================================================================
-- El clon comparte los datos con DEV_BRONZE_DB: al crearse no ocupa espacio.
-- Desde ese momento, cada database evoluciona por separado.
--
-- Los grants de la database original NO pasan al clon: hay que concederlos otra
-- vez. Si recargas Bronze en DEV (script 02), vuelve a ejecutar este script para
-- que PRO tenga las mismas tablas.
--
-- No hay entorno PRE: es un proyecto en solitario. Las databases PRE creadas por
-- el script 01 existen pero no se usan, y este script no las toca.
--
-- Script reconstruido a partir del extracto del curso; sin probar en Snowflake.
-- =============================================================================

use role sysadmin;
use warehouse WH_PROYECTO;

create or replace database PRO_BRONZE_DB clone DEV_BRONZE_DB;

use role securityadmin;
grant usage on database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;
grant usage on all schemas in database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;
grant select on all tables in database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;

-- ============================== COMPROBACION =================================
-- Resultado esperado: calendario 1125 · resultados 26759 · clasificacion 10494
-- en las dos databases.
use role sysadmin;
select 'DEV' as entorno, 'calendario' as tabla, count(*) as filas from DEV_BRONZE_DB.f1.calendario union all
select 'DEV', 'resultados', count(*) from DEV_BRONZE_DB.f1.resultados union all
select 'DEV', 'clasificacion', count(*) from DEV_BRONZE_DB.f1.clasificacion union all
select 'PRO', 'calendario', count(*) from PRO_BRONZE_DB.f1.calendario union all
select 'PRO', 'resultados', count(*) from PRO_BRONZE_DB.f1.resultados union all
select 'PRO', 'clasificacion', count(*) from PRO_BRONZE_DB.f1.clasificacion;