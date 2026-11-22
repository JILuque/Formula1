--------------------------------------------------------------
-- Silver solo tiene temporadas entre season_start y season_end.
-- Si hay 25 temporadas distintas, no falta ninguna
--------------------------------------------------------------

select count(distinct season_year) as n_temporadas
from {{ ref('slv_f1__races') }}
having count(distinct season_year) <> {{ var('season_end') - var('season_start') + 1 }}