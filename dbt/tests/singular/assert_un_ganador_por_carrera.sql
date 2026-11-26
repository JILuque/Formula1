-----------------------------------------------------------------------------
-- Cada carrera y cada sprint tiene exactamente un ganador (posición 1).
-- Devuelve las sesiones con cero ganadores o con más de uno.
-- Un fallo aquí significa que el origen está corrupto o que se perdió una fila
-- en Silver: hay que mirarlo, por eso es un error y no un aviso.
-----------------------------------------------------------------------------

with sesiones as (

    select 'race' as session_type, season_year, round, position
    from {{ ref('slv_f1__results') }}

    union all

    select 'sprint' as session_type, season_year, round, position
    from {{ ref('slv_f1__sprint_results') }}

)

select
      session_type
    , season_year
    , round
    , count(*)                                       as n_pilotos
    , sum(case when position = 1 then 1 else 0 end)  as n_ganadores
from sesiones
group by session_type, season_year, round
having sum(case when position = 1 then 1 else 0 end) <> 1
