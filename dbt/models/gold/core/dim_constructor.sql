------------------------------------------------------------
-- dim_constructor: una fila por constructor (2000-2024) con sus datos y un resumen de su participación.
-- Las victorias son victorias de carrera de cualquiera de sus pilotos (solo cuentan carreras con salida).
------------------------------------------------------------

with constructors as (

    select
        id_constructor,
        constructor_ref,
        constructor_name,
        constructor_nationality,
        last_season_year
    from {{ ref('slv_f1__constructors') }}

),

results as (

    select id_constructor, season_year, position_order
    from {{ ref('slv_f1__results') }}
    where coalesce(status_category, 'unknown') <> 'not_started'

),

history as (

    select
        id_constructor,
        min(season_year) as first_season_year,
        count(distinct season_year) as n_seasons,
        sum(case when position_order = 1 then 1 else 0 end) as n_wins
    from results
    group by id_constructor

)

select
    c.id_constructor,
    c.constructor_ref,
    c.constructor_name,
    c.constructor_nationality,
    h.first_season_year,
    c.last_season_year,
    coalesce(h.n_seasons, 0) as n_seasons,
    coalesce(h.n_wins, 0) as n_wins
from constructors c
left join history h on c.id_constructor = h.id_constructor