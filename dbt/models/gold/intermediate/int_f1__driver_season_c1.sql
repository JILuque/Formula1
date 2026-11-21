------------------------------------------------------------------------------
--C1: duelo con el compañero de equipo
--C1 mide el porcentaje de duelos que un piloto gana a su compañero de equipo en una temporada.
--Un duelo es cada sesión (carrera, clasificación o sprint) en la que ambos compañeros compitieron
--y tienen un resultado válido; gana el que queda por delante. Al compartir coche, la comparación aísla el factor piloto.
--Se anula el duelo para los dos si alguno abandona por avería (mechanical) o no sale (not_started),
--y en clasificación si alguno no tiene tiempo de Q1.
--Va con signo positivo en la puntuación final: más duelos ganados, mejor.
-----------------------------------------------------------------------------

select
      id_driver
    , season_year
    , count(*)                                  as n_duels
    , sum(case when win_duel then 1 else 0 end) as n_wins
    , n_wins / n_duels                          as c1_win_rate
from {{ ref('int_f1__teammate_duels') }}
group by id_driver, season_year