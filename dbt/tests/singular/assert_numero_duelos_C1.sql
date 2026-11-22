---------------------------------------------------------------------------------
-- Cada duelo genera dos filas (una desde cada piloto): una gana y otra pierde.
-- Por tanto, en cada temporada, las victorias suman la mitad de los duelos.
-- Si no cuadra, algún duelo se ha contado en un solo sentido
---------------------------------------------------------------------------------

select
    season_year
    , sum(n_wins) as total_wins
    , sum(n_duels) as total_duels
from {{ ref('int_f1__driver_season_c1') }}
group by season_year
having sum(n_wins) * 2 <> sum(n_duels)
