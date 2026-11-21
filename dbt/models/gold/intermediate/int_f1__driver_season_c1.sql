select
      id_driver
    , season_year
    , count(*)                                  as n_duels
    , sum(case when win_duel then 1 else 0 end) as n_wins
    , n_wins / n_duels                          as c1_win_rate
from {{ ref('int_f1__teammate_duels') }}
group by id_driver, season_year