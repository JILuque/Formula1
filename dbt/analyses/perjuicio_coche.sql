-----------------------------------------------------------------------------
-- Perjuicio del coche: ¿qué equipo ha perjudicado más a cada piloto en su carrera?
-- Segunda lectura del caso de uso: el ranking ajustado sube a los pilotos cuyo coche no
-- reflejaba lo que hacían; aquí se ve qué equipo explica esa diferencia.
--
-- Método (la misma idea que C3):
--   1. Nivel del coche = puesto del constructor en el campeonato de esa temporada
--      (puntos de carrera + sprint, desempate por victorias; empatados comparten puesto).
--   2. Puesto esperado de cada nivel = media de puesto final de los coches de ese puesto,
--      en todas las temporadas 2000-2024 y sin contar averías ni no salidas.
--   3. Perjuicio de una carrera = puesto esperado de su coche - puesto esperado del coche
--      campeón (puesto 1). Son los puestos que le cuesta no tener el mejor coche.
--   4. Se agrupa por piloto y constructor. El equipo que más le perjudica es el de mayor
--      media de puestos perdidos por carrera, no el de mayor total: el total premiaría a los
--      equipos con los que más años estuvo, aunque ganase con ellos.
-- Solo salen los pilotos del top top_n_ranking del ranking (el mismo cálculo que ranking.sql, con
-- sus mínimos de carreras) y solo cuentan los constructores con min_stint_races carreras (más
-- de una temporada). Quien solo ha corrido en un equipo sale con ese equipo; la columna
-- por_carrera dice cuánto le perjudicó (cerca de 1 = tuvo un coche casi campeón).
--
-- Limitación: los constructores renombrados (Toro Rosso, AlphaTauri, RB) cuentan como equipos
-- distintos, porque el origen los trata como constructores distintos. Mejora futura: una seed
-- con el linaje de cada equipo.
--
-- Lee solo modelos públicos de Gold. Para ver todos los equipos de un piloto, quita el filtro
-- rn = 1 y filtra por driver_full_name. No lleva limit: el IDE de dbt añade el suyo.
-----------------------------------------------------------------------------

-- Top del ranking: la misma consulta que ranking.sql (media del score ponderada por carreras)
with ranking as (
    select
        d.id_driver,
        d.driver_full_name,
        round(sum(f.score * f.n_races) / sum(f.n_races), 2) as score,
        row_number() over (
            order by round(sum(f.score * f.n_races) / sum(f.n_races), 2) desc, d.id_driver
        ) as posicion
    from {{ ref('fct_driver_season') }} f
    join {{ ref('dim_driver') }} d on f.id_driver = d.id_driver
    where f.score is not null
    group by d.id_driver, d.driver_full_name
    having sum(f.n_races) >= {{ var('min_career_races') }}
),

top_ranking as (
    select *
    from ranking
    where posicion <= {{ var('top_n_ranking', 15) }}
),

carreras as (
    select
        id_driver,
        id_constructor,
        season_year,
        position_order,
        status_category,
        total_points
    from {{ ref('fct_driver_race') }}
),

-- Puntos y victorias de cada constructor por temporada (carrera + sprint)
puntos_constructor as (
    select
        season_year,
        id_constructor,
        sum(total_points) as points,
        sum(case when position_order = 1 then 1 else 0 end) as wins
    from carreras
    group by season_year, id_constructor
),

puesto_constructor as (
    select
        season_year,
        id_constructor,
        rank() over (
            partition by season_year
            order by points desc, wins desc
        ) as constructor_rank
    from puntos_constructor
),

carreras_validas as (
    select
        c.id_driver,
        c.id_constructor,
        c.position_order,
        p.constructor_rank
    from carreras c
    join puesto_constructor p
        on c.season_year = p.season_year
        and c.id_constructor = p.id_constructor
    where coalesce(c.status_category, 'unknown') not in ('mechanical', 'not_started')
),

puesto_esperado as (
    select
        constructor_rank,
        avg(position_order) as expected_position
    from carreras_validas
    group by constructor_rank
),

-- Referencia: puesto esperado del coche campeón
campeon as (
    select expected_position
    from puesto_esperado
    where constructor_rank = 1
),

perjuicio as (
    select
        v.id_driver,
        k.constructor_name,
        count(*) as n_races,
        sum(e.expected_position - c.expected_position) as puestos_perdidos
    from carreras_validas v
    join puesto_esperado e on v.constructor_rank = e.constructor_rank
    cross join campeon c
    join {{ ref('dim_constructor') }} k on v.id_constructor = k.id_constructor
    group by v.id_driver, k.constructor_name
    having count(*) >= {{ var('min_stint_races', 30) }}
),

peor_equipo as (
    select
        *,
        row_number() over (partition by id_driver order by puestos_perdidos / n_races desc) as rn
    from perjuicio
)

select
    r.posicion as posicion_ranking,
    r.driver_full_name,
    r.score,
    p.constructor_name as equipo_que_mas_le_perjudica,
    p.n_races as carreras_con_el_equipo,
    round(p.puestos_perdidos) as puestos_perdidos,
    round(p.puestos_perdidos / p.n_races, 1) as por_carrera
from top_ranking r
join peor_equipo p on r.id_driver = p.id_driver
where p.rn = 1
order by r.posicion
