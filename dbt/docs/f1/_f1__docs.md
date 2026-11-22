{% docs season_year %}
Año de la temporada de Formula 1. El proyecto trabaja con 2000-2024 (variables `season_start` y `season_end`); staging conserva todos los años disponibles en el origen.
{% enddocs %}

{% docs round %}
Numero de ronda dentro de la temporada: 1 es la primera carrera del año. Junto con `season_year` identifica un gran premio.
{% enddocs %}

{% docs grid %}
Posicion de salida en la parrilla. El valor 0 indica que el piloto salio desde el pit lane (no tiene puesto de parrilla).
{% enddocs %}

{% docs laps %}
Vueltas completadas por el piloto en la sesion.
{% enddocs %}

{% docs race_time_ms %}
Tiempo total de carrera en milisegundos. Solo lo tienen los pilotos que terminaron en la vuelta del ganador o cerca de ella; es nulo en el resto.
{% enddocs %}

{% docs status_category %}
Categoria del estado final del piloto en la sesion (carrera o sprint). Se obtiene uniendo el estado original con el seed `status_classification`.

| status_category | Significado | Uso en el score |
|---|---|---|
| finished | Termino la carrera, incluidas las vueltas de retraso | Entra en C1, C2 y C3 |
| mechanical | Fallo del coche o causa ajena al piloto (incluye neumaticos y residuos en pista) | Se excluye de C1 y C3; cuenta como carrera disputada en C2 |
| driver_incident | Accidente, colision o salida de pista atribuible al piloto | Cuenta como incidente en C2 |
| other_not_finished | Causa administrativa, medica o no clara (por ejemplo Retired) | Entra en C1 y C3; no es incidente en C2 |
| not_started | Nunca llego a tomar la salida | Se excluye de todo |
{% enddocs %}
