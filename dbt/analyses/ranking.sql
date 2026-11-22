select
    d.driver_full_name,
    sum(f.n_races) as carreras,
    count(*) as temporadas,
    round(sum(f.score * f.n_races) / sum(f.n_races), 2) as score
from {{ ref('fct_driver_season') }} f
join {{ ref('slv_f1__drivers') }} d on f.id_driver = d.id_driver
where f.score is not null
group by d.driver_full_name
having sum(f.n_races) >= 100
order by score desc