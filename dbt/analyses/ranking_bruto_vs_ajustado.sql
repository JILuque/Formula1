-----------------------------------------------------------------------------
-- Contraste: ranking en bruto (victorias) frente al ranking ajustado (score).
-- Mismos pilotos que ranking.sql: score en temporadas fiables y mínimo de 100 carreras.
-- puesto_bruto: orden por victorias (desempate por podios); los empatados comparten puesto (rank).
-- puesto_ajustado: orden por score.
-- diferencia = puesto_bruto - puesto_ajustado
--     positivo -> el ajuste lo sube (su coche no reflejaba lo que hizo)
--     negativo -> el ajuste lo baja (el coche le ayudó más de lo que parece)
-- No lleva limit: el IDE de dbt añade el suyo.
-----------------------------------------------------------------------------

with ajustado as (
    select
        id_driver,
        sum(score * n_races) / sum(n_races) as score
    from {{ ref('fct_driver_season') }}
    where score is not null
    group by id_driver
    having sum(n_races) >= 100
),

ranking as (
    select
        d.driver_full_name,
        d.n_races,
        d.n_wins,
        d.n_podiums,
        round(100.0 * d.n_wins / d.n_races, 1) as pct_victorias,
        round(a.score, 2) as score,
        rank() over (order by d.n_wins desc, d.n_podiums desc) as puesto_bruto,
        rank() over (order by a.score desc) as puesto_ajustado
    from ajustado a
    join {{ ref('dim_driver') }} d on a.id_driver = d.id_driver
)

select
    driver_full_name,
    n_races,
    n_wins,
    n_podiums,
    pct_victorias,
    score,
    puesto_bruto,
    puesto_ajustado,
    puesto_bruto - puesto_ajustado as diferencia
from ranking
order by puesto_ajustado