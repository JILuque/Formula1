-------------------------------------------------------------------------
-- Carreras que debe haber en cada temporada (calendario oficial)
-- Devuelve las temporadas cuyo número de carreras en Silver no coincide
-------------------------------------------------------------------------

with reales as (
    select season_year, count(*) as n_races
    from {{ ref('slv_f1__races') }}
    group by season_year
)

select
    season_year
    , n_races
    , case
        when season_year in (2003)                                 then 16
        when season_year in (2000, 2001, 2002, 2007, 2009, 2020)   then 17
        when season_year in (2004, 2006, 2008)                     then 18
        when season_year in (2005, 2010, 2011, 2013, 2014, 2015)   then 19
        when season_year in (2012, 2017)                           then 20
        when season_year in (2016, 2018, 2019)                     then 21
        when season_year in (2021, 2022, 2023)                     then 22
        when season_year in (2024)                                 then 24
      end as n_races_esperadas
from reales
where n_races <> n_races_esperadas
   or n_races_esperadas is null