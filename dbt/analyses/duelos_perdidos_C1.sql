select
      ra.season_year
    , ra.round
    , ra.race_name
    , c.constructor_name
    , da.driver_full_name  as piloto_a
    , a.status             as estado_a
    , a.status_category    as categoria_a
    , db.driver_full_name  as piloto_b
    , b.status             as estado_b
    , b.status_category    as categoria_b
from {{ ref('slv_f1__results') }} a
join {{ ref('slv_f1__results') }} b
    on  a.id_race        = b.id_race
    and a.id_constructor = b.id_constructor
    and a.id_driver      < b.id_driver
join {{ ref('slv_f1__races') }}        ra on ra.id_race        = a.id_race
join {{ ref('slv_f1__constructors') }} c  on c.id_constructor  = a.id_constructor
join {{ ref('slv_f1__drivers') }}      da on da.id_driver      = a.id_driver
join {{ ref('slv_f1__drivers') }}      db on db.id_driver      = b.id_driver
where a.status_category in ('mechanical', 'not_started')
   or b.status_category in ('mechanical', 'not_started')
order by ra.season_year, ra.round


select
      ra.season_year
    , ra.round
    , ra.race_name
    , c.constructor_name
    , da.driver_full_name as piloto_a
    , a.q1_ms             as q1_a
    , db.driver_full_name as piloto_b
    , b.q1_ms             as q1_b
from {{ ref('slv_f1__qualifying') }} a
join {{ ref('slv_f1__qualifying') }} b
    on  a.id_race        = b.id_race
    and a.id_constructor = b.id_constructor
    and a.id_driver      < b.id_driver
join {{ ref('slv_f1__races') }}        ra on ra.id_race       = a.id_race
join {{ ref('slv_f1__constructors') }} c  on c.id_constructor = a.id_constructor
join {{ ref('slv_f1__drivers') }}      da on da.id_driver     = a.id_driver
join {{ ref('slv_f1__drivers') }}      db on db.id_driver     = b.id_driver
where a.q1_ms is null or b.q1_ms is null
order by ra.season_year, ra.round


select status, count(*) as pilotos
from {{ ref('slv_f1__results') }}
where status_category = 'mechanical'
group by 1
order by 2 desc