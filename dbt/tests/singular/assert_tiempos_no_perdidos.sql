-----------------------------------------------------------------------------
-- time_to_ms usa try_cast: si un tiempo viene mal formado, devuelve NULL en
-- lugar de romper el build. Este test avisa (warn, no error) si algún tiempo
-- que SÍ existe en staging no se puede convertir a milisegundos
-----------------------------------------------------------------------------

{{ config(warn_if='>0', error_if='>20') }}
select
    season_year
    , round
    , driver_ref
    , q1
    , q2
    , q3
from {{ ref('stg_f1__clasificacion') }}
where season_year between {{ var('season_start') }} and {{ var('season_end') }}
  and (
         (q1 is not null and {{ time_to_ms('q1') }} is null)
      or (q2 is not null and {{ time_to_ms('q2') }} is null)
      or (q3 is not null and {{ time_to_ms('q3') }} is null)
  )
