# Bitácora del proyecto final: mejor piloto de F1 2000-2024

Cuaderno de trabajo. Se añade una entrada por sesión, la más reciente arriba.
Fecha de entrega: 25 de noviembre de 2026.

## Plantilla de entrada

```
### AAAA-MM-DD: título corto
**Qué hice:**
**Por qué lo hice así (y qué alternativa descarté):**
**Problemas encontrados y cómo los resolví:**
**Pendiente / siguiente paso:**
```

---

## Entradas

### 2026-11-22: dimensiones, gold_results__enriched y fct_driver_race
**Qué hice:** completé el modelo dimensional de Gold. En `models/gold/core/` creé las
tres dimensiones (`dim_driver`, `dim_constructor`, `dim_race`) y la segunda tabla de
hechos, `fct_driver_race`; en `models/gold/intermediate/` creé `gold_results__enriched`,
el modelo ancho que alimenta a `fct_driver_race`. `dbt build` pasa y las cifras cuadran
con los CSV: 126 pilotos (10.071 carreras con salida y 479 victorias), 38 constructores,
479 carreras con su circuito, y 10.079 filas en `gold_results__enriched` y
`fct_driver_race` (9.098 con clasificación y 360 con sprint; 37.069 puntos de carrera,
558 de sprint y 37.627 en total). Documenté todos los modelos con un `.yml` por carpeta, 
con la descripción de cada modelo y de cada columna: `_staging_f1__models.yml` en
`models/staging/f1/`, `_silver_f1__models.yml` en `models/silver/f1/`,
`_intermediate__models.yml` en `models/gold/intermediate/` y `_core__models.yml` en
`models/gold/core/`. `dbt parse` pasa sin errores. Cada columna 
documentada existe en el SQL de su modelo (comprobado).
 
**Por qué lo hice así (y qué alternativa descarté):**
- **Dimensiones con resumen de carrera, no copias de Silver.** `dim_driver` y
  `dim_constructor` unen la entidad de Silver con un resumen calculado desde
  `slv_f1__results` (primera temporada, temporadas, victorias; en pilotos también carreras
  y podios). Es desnormalizar: datos y historial en una sola fila. Las medidas de carrera
  dentro de una dimensión no son lo más purista (irían en una tabla agregada), pero son
  atributos de carrera del piloto y el contraste en bruto del ranking las necesita.
- **`dim_race` con el circuito incluido** (nombre, país, coordenadas, altitud), en lugar de
  una `dim_circuit` aparte: quien consulta una carrera no necesita un segundo `join`.
  Mismo caso que `dim_users` con `dim_addresses` en el ejercicio del curso.
- **`gold_results__enriched` une carrera, clasificación y sprint del mismo fin de semana**,
  no los datos del piloto, el equipo y la carrera: esos ya viven en las dimensiones y
  repetirlos duplicaría información. Hace de las tres tablas de Silver, que se dejaron
  separadas a propósito, una fila por piloto y carrera.
- **`left join` desde `results`** en el `enriched`: la carrera manda y la clasificación y el
  sprint pueden faltar (981 filas sin clasificación, la mayoría por los fines de semana de
  2000-2002 sin ella; el sprint solo existe en 18 carreras). Con `inner join` se perderían.
  Se comprobó que ninguna fila de clasificación ni de sprint se queda sin pareja.
- **Si el equipo cambia entre clasificación y carrera** (10 filas), manda el de la carrera.
- **`fct_driver_race` toma del `enriched` solo las claves y las medidas**, como
  `fct_orders` toma de `gold_orders__enriched` en el curso. `total_points` suma carrera y
  sprint, con `coalesce(sprint_points, 0)`: sin él, `null + número` borraría el total en las
  carreras sin sprint.
- **Dos tablas de hechos** (`fct_driver_season` y `fct_driver_race`) con dimensiones
  compartidas, como se decidió. El score del caso de uso sale de la primera; la segunda es
  el detalle por carrera para Power BI y para el contraste en bruto.
- **El `ranking` pasa a leer de `dim_driver`** en vez de Silver: la capa de consumo lee solo
  de Gold.
  - **Un `.yml` por carpeta, no uno por modelo.** Reúne los modelos de una misma capa y
  evita decenas de archivos; es la convención del curso (el `.sql` más su `.yml` con
  descripción, configuración y columnas). El nombre empieza por `_` para que quede arriba
  en la carpeta.
- **Las descripciones indican los nulos y las ausencias reales del origen** (por ejemplo,
  clasificaciones que faltan en 2000-2002, sprint solo en 18 carreras): es lo que
  preguntaría quien consulte la tabla sin conocer los datos. Sin tests por ahora: se añaden
  juntos en el día 3. El modelo `ephemeral` de duelos se documenta, pero no admite tests.

**Problemas encontrados y cómo los resolví:**
- El linaje de dbt mostraba sueltas las tablas de Silver de circuitos, carreras, pilotos y
  constructores: hasta crear las dimensiones no las leía ningún modelo. Tras `dbt compile`
  quedaron conectadas.
**Pendiente / siguiente paso:** tests del día 3 (`unique` y `not_null` en los `id_*`, 
`relationships` entre los hechos y las tres dimensiones, `not_null` en `status_category`, 
cobertura 2000-2024, tiempos perdidos de clasificación).
 

### 2026-11-22: fct_driver_season y ranking
**Qué hice:** creé `fct_driver_season` en `models/gold/core/` (tabla, una fila por
piloto y temporada) y la consulta `analyses/ranking.sql`. La tabla reúne C1, C2 y
C3: parte de C2 (una fila por piloto que tomó la salida, 598) y le une C1 y C3
con `left join`. Calcula los z-scores de cada componente dentro de cada
temporada y el score final, `(z_c1 - z_c2 + z_c3) / 3`. `dbt build` pasa y las
cifras cuadran: 598 filas, 498 de ellas con muestra fiable y score.
El ranking agrega esas temporadas por piloto con una media ponderada por
carreras y exige un mínimo de 100 carreras. Resultado (top 10): Alonso 0,85,
Max Verstappen 0,82, Hamilton 0,53, Vettel 0,50, Gasly 0,47, Russell 0,46,
Norris 0,41, Rosberg 0,39, Button 0,34 y Ricciardo 0,32.

**Por qué lo hice así (y qué alternativa descarté):**
- **z-score dentro de cada temporada.** C1 es un porcentaje, C2 una tasa
  pequeña y C3 son posiciones: no se pueden sumar tal cual, y C3 se comería a las
  otras dos. Restar la media y dividir por la desviación de la temporada las
  pone en la misma unidad ("pasos típicos sobre la media de su año"), de modo
  que cada componente pesa de verdad un tercio. Descarté sumar los valores
  brutos. Coste asumido: el z-score es relativo, no dice que un piloto sea
  objetivamente bueno, solo que destaca frente a los de su temporada.
- **C2 resta en el score.** Es una tasa de incidentes: más es peor. El z-score
  de C2 no se invierte en su cálculo, el signo se aplica en la fórmula final.
- **Muestra fiable: al menos 8 carreras válidas y al menos 10 duelos**
  (`is_reliable_sample`). Los z-scores se calculan solo con esas filas; sin
  esto, un piloto con una carrera distorsiona la media y la desviación de la
  temporada. Los umbrales son una decisión mía (aproximadamente el mínimo para
  que una media por temporada diga algo) y se cambian en una sola línea. Quedan
  498 de 598 filas con score; el resto tiene `score` nulo, no cero.
- **C2 como base y `left join` de C1 y C3.** Hay 598 pilotos-temporada en C2,
  597 en C1 y 594 en C3. Los que faltan tienen una o dos carreras (en C3,
  todas por avería; en C1, ningún duelo válido) y nunca llegan a ser fiables.
- **Pesos exactos de 1/3**, como se decidió; los pesos con `vars` siguen siendo
  una mejora opcional.
- **El ranking es una consulta, no una tabla.** Lo que se pide es un top 5/10
  con un filtro de mínimo, y eso es una `select ... order by ... limit`. Ni
  `fct_` (no es un hecho) ni `dim_` (no describe una entidad). Una tabla
  `agg_driver_career` (una fila por piloto con el score medio, las carreras y un
  indicador de mínimo) encajaría en Gold y quedaría como mejora opcional.
- **Media ponderada por carreras** y no media simple de temporadas: una
  temporada de 20 carreras debe pesar más que una de 8.
- **Mínimo de 100 carreras (unas cinco temporadas) en vez de 36.** Con 36
  ("temporada y media") entraba Albers, con dos temporadas fiables y 37 carreras,
  en el tercer puesto por delante de Hamilton. Es un efecto de muestra pequeña
  (compañeros flojos y un coche de la cola donde unas pocas buenas carreras
  suman mucho). Con 100 desaparece. El mínimo de 36 se conserva como análisis
  de sensibilidad.

**Problemas encontrados y cómo los resolví:**
- **Primera versión de C3 con sesgo.** El puesto esperado era `2 * puesto - 0,5`.
  Con esa fórmula, los pilotos de equipos de la cola salían inflados (casi todo
  el que termina queda por delante de 19,5) y los de coches de arriba no podían
  destacar (el máximo era +0,5). Aparecían Pic, Albers y Nasr arriba y Hamilton
  y Vettel fuera del top 10. Lo sustituí por la media real de puesto final de
  los coches de ese puesto de constructor (por ejemplo, el 1.º acaba de media
  en el 3,73 y el 4.º en el 8,39). Después comprobé que el C3 medio por nivel
  de coche queda en torno a 0 (entre -0,12 y +0,07).
- **Empates en el campeonato de constructores.** Con `row_number()` y desempate
  por `id_constructor`, los equipos empatados a 0 puntos y 0 victorias quedaban
  ordenados de forma arbitraria. Lo vi al contrastar mi `fct` con una
  reproducción independiente del cálculo con los CSV: un piloto (Albers) salía con
  scores distintos. Al revisarlo, hay 8 temporadas con equipos empatados a 0
  puntos (2000, 2006, 2008, 2010, 2011, 2012, 2013 y 2014) además de otros
  empates (2000, 2002 y 2022). Pasé a `rank()` con orden por puntos y
  victorias: los empatados comparten puesto y el resultado ya no depende de un
  orden inventado. `dense_rank()` lo descarté porque junta niveles de coche
  distintos. Antes de este cambio, mi comprobación de empates solo había mirado
  los de más de 0 puntos.

**Limitaciones conocidas (para la defensa):**
- **C1 no pondera la calidad del compañero.** Ganar un duelo a un compañero
  flojo vale lo mismo que ganárselo a un campeón. Ejemplo: Norris en 2021 y 2022
  contra Ricciardo en su peor etapa. La solución (un modelo de ratings que conecte
  a todos los pilotos, tipo Elo o Bradley-Terry) queda como trabajo futuro; una
  versión más sencilla, ponderar cada duelo por el C3 del rival, añadiría una
  cadena `int -> int` y unos pesos arbitrarios, y no la he hecho.
- **Los coches de arriba tienen un techo bajo en C3.** En 2024 McLaren fue el
  primero del campeonato y Norris sale con un C3 negativo.
- **La ventana 2000-2024 recorta carreras.** Michael Schumacher solo suma 180
  carreras (incluida su vuelta a Mercedes) y sale 13.º con 0,25.
- **El score mide rendimiento relativo a su coche y su compañero**, no el mejor
  piloto de la historia. El top 2 (Alonso y Max Verstappen) es estable ante
  cualquier tratamiento de los empates; a partir del tercero el orden depende
  de las decisiones de diseño. Gasly sube por tres temporadas con AlphaTauri
  (2020-2022) con C3 entre +1,6 y +2,7.

**Pendiente / siguiente paso:** tests (día 3) de Silver y Gold; dimensiones
(`dim_driver`, `dim_constructor`...) y la tabla de hechos piloto-carrera
(`fct_driver_race`), con un `gold_results__enriched` como modelo ancho previo;
contraste entre el ranking en bruto y el ajustado por coche; modelos físicos
de cada capa; pull request de DEV a main y despliegue en PRO. Opcional:
`agg_driver_career`, Power BI.

---

### 2026-11-21: Gold intermedio (duelos, C1, C2 y C3)
**Qué hice:** creé la capa Gold intermedia en `models/gold/intermediate/` con
cuatro modelos y añadí el bloque `gold` a `dbt_project.yml` (base de datos
`DBT_GOLD_DB`; `intermediate` como vista en el schema `intermediate` y `core`
como tabla en el schema `core`):
- `int_f1__teammate_duels`: duelos entre compañeros, apilados. Es `ephemeral`.
- `int_f1__driver_season_c1`: porcentaje de duelos ganados por piloto y temporada.
- `int_f1__driver_season_c2`: tasa de incidentes del piloto por carrera disputada.
- `int_f1__driver_season_c3`: rendimiento frente al nivel del coche.
Cifras contrastadas con los CSV: 16.978 filas de duelos (8.489 duelos, cada uno
con una fila desde cada piloto: 3.896 de carrera, 4.417 de clasificación y 176
de sprint); C1 con 597 filas; C2 con 598 filas (10.071 carreras y 865 incidentes);
C3 con 594 filas (8.773 carreras válidas).

**Por qué lo hice así (y qué alternativa descarté):**
- **Duelos con un `join` del modelo consigo mismo.** Para cada sesión, se une
  cada piloto con los demás del mismo equipo en la misma carrera (`a.id_driver <>
  b.id_driver`), y `win_duel` es verdadero si el piloto A queda por delante.
  Cada duelo genera dos filas. Está separado de C1 porque la misma tabla de duelos
  sirve para cualquier análisis de compañeros, y C1 solo agrega.
- **`int_f1__teammate_duels` es `ephemeral`**, a sugerencia del profesorado, que
  considera poco limpio que un `int` lea de otro `int`. No crea objeto en
  Snowflake; sigue apareciendo en el linaje; no se puede testear por separado.
  La alternativa, juntar duelos y C1 en un solo modelo, la descarté porque
  mezcla dos responsabilidades.
- **Los duelos reúnen carrera, clasificación y sprint** (cada sesión disputada
  vale un duelo). Decisión confirmada: el peso de cada sesión sale de cuántas
  veces se disputa, sin inventar pesos. Consecuencia asumida: la clasificación pesa
  algo más que la carrera (4.417 duelos frente a 3.896). Descarté pesos por
  sesión, que serían arbitrarios.
- **Opción A en los duelos.** Se excluyen los duelos en los que alguno de los dos
  tiene estado `mechanical` o `not_started` (carrera y sprint), y los de
  clasificación sin tiempo de Q1. Se pierden 1.141 filas de duelo de carrera
  (1.136 por avería y 5 por no salir) y 120 de clasificación.
- **C2 cuenta los incidentes sobre todas las carreras que el piloto tomó la
  salida**, incluidas las que acabó por avería: la avería no es incidente, pero
  sí una carrera disputada (el denominador es la exposición). Solo se excluye
  `not_started`. Así, la opción A se aplica a C1 y C3, no a C2, que ya separa
  los abandonos por avería de los que son culpa del piloto.
- **C3: nivel del coche = puesto del constructor en el campeonato de esa
  temporada**, calculado una vez por temporada. El puesto se obtiene sumando
  puntos de carrera y de sprint de `results` y `sprint_results`, que reproduce
  el campeonato real: sin sprint, McLaren y Aston Martin empataban a 266 puntos
  en 2023; con él, McLaren es 4.º. En total cambian 6 puestos (2022 y 2023).
  Descarté medir el nivel del coche carrera a carrera (más complejo) y usar las
  posiciones de parrilla.
- **El puesto del constructor es una CTE dentro de C3**, no una tabla de Silver.
  Se barajó una tabla `slv_f1__constructor_standings` (une dos tablas de
  Silver y daría una rama más al linaje) y un modelo ancho `gold_results__enriched`
  que lo calculase; ambas descartadas porque hoy solo lo usa C3 y no aportaban
  más que linaje. El `enriched` queda para alimentar a `fct_driver_race`, como
  en el ejercicio del curso, sin el puesto del constructor para no duplicar
  el cálculo.
- **C3 lee directamente de Silver**, para no encadenar un `int` tras otro.
- **Puesto esperado y desempates**: véase la entrada del 2026-11-22.
- **Opción A en C3:** se excluyen las carreras con estado `mechanical` o
  `not_started`; se mantienen `driver_incident` y `other_not_finished`.

**Problemas encontrados y cómo los resolví:**
- Al lanzar la consulta de comprobación con `ref()` en Snowsight dio error de sintaxis:
  `ref()` solo se renderiza en dbt. Se ejecuta con Preview en el IDE o desde
  `analyses/`.
- `Object ... does not exist or not authorized` sobre C3: no era un problema de
  permisos, el modelo aún no se había construido. Hay que ejecutar `dbt build`
  del modelo antes de consultarlo.
- Dudaba de que 1.141 duelos anulados fuera correcto: eran 1.136 por avería y 5
  por no salir, sin doble recuento.

**Cosas que aprendí de los datos:**
- Hay 80 pilotos-temporada con menos de 10 duelos (C1) y 47 con menos de 5
  carreras (C2): son muestras pequeñas, que se tratan en el `fct` con el
  indicador de muestra fiable.
- Hay un piloto-temporada (Zonta 2001) que está en C2 y C3 pero no en C1, y 4
  que están en C1 y C2 pero no en C3 (todas sus carreras fueron por avería).
- Entre 2000 y 2002 la clasificación está incompleta (44 fines de semana sin
  ella), así que C1 usa solo carrera en esos años.

**Pendiente / siguiente paso:** `fct_driver_season` y el ranking.

---

### 2026-11-20: demostración de la incrementalidad con tasks de Snowflake y macros
**Qué hice:** para enseñar en la defensa que Silver es incremental y no duplica,
preparé dos CSV de prueba (`calendario_test.csv`, con una carrera de 2025, ronda
99, "TEST Incremental Grand Prix", y `resultados_test.csv`, con dos resultados de
pilotos de prueba), subidos al stage interno `carga_bronze`. En Snowflake creé dos
tasks sin programación (`task_demo_cargar`, que hace los `COPY INTO` a Bronze, y
`task_demo_limpiar`, que borra las filas de 2025 ronda 99) y en dbt tres macros:
- `insertar_incremental`: lanza la task de carga, espera 10 segundos y comprueba
  que hay 3 registros de 2025 en Bronze.
- `ver_2025`: lista lo que hay de 2025 en Silver (esperado: 7 filas, 1 carrera,
  1 circuito, 2 pilotos, 1 constructor y 2 resultados).
- `limpiar_incremental`: lanza la task de limpieza y comprueba que no queda nada
  de 2025 en Bronze.
Flujo de la demo: `dbt run-operation insertar_incremental`, `dbt run --select
silver`, `dbt run-operation ver_2025` y, al terminar, `dbt run-operation
limpiar_incremental`. La incrementalidad funciona: se añaden las filas de 2025
sin duplicar nada.

**Por qué lo hice así (y qué alternativa descarté):**
- **CSV de prueba y no una macro que inserte una fila a mano:** simula una carga
  real (fichero, `COPY INTO`, dbt) y no toca el código de los modelos.
- **Tasks de Snowflake y no procedimientos:** son lo visto en clase. Cada task
  se ejecuta a mano con `execute task`, sin programación.
- **Sin job en PRO:** es una demo, no debe ejecutarse sola.
- **Cargar y limpiar son dos macros separadas**, y no una que borre antes de
  insertar: si la carga borrase siempre lo anterior, nunca se vería un duplicado
  aunque el modelo fallase.
- **Comprobación previa en `insertar_incremental`:** si ya hay registros de 2025,
  la macro se detiene antes de cargar. Sin ella, ejecutarla dos veces duplicaba
  las filas en Bronze.
- **Código lo más simple posible:** simplifiqué una primera versión que esperaba a
  la task con un bucle, porque no se entendía; ahora espera 10 segundos y cuenta.

**Problemas encontrados y cómo los resolví:**
- La task falló por permisos: se ejecuta con los privilegios del propietario
  (SYSADMIN) y el stage era de ACCOUNTADMIN. Se resolvió dando lectura y escritura
  sobre el stage y uso del formato de fichero a SYSADMIN, y `operate` sobre las
  tasks al rol de dbt. Los errores de una task no se ven en Snowsight: hay que
  consultar `information_schema.task_history`.
- El `COPY INTO` ignora ficheros ya cargados: la task usa `force = true`.
- Al ejecutar dos veces la macro, Bronze quedaba con 6 registros y no 3: se
  añadió la comprobación previa.
- La macro usaba `bd` antes de definirla: la definición debe ir primero.
- Los registros de prueba **siguen en Silver tras limpiar Bronze**, porque el
  `merge` no borra: para eliminarlos hay que ejecutar `dbt run --select silver
  --full-refresh`.

**Pendiente / siguiente paso:** ninguno propio; la demo queda lista para la defensa.

---

### 2026-11-20: Silver (7 modelos incrementales)
**Qué hice:** creé la capa Silver en `models/silver/f1/` con 7 modelos
incrementales (`merge`): 4 entidades (`slv_f1__circuits`, `slv_f1__races`,
`slv_f1__drivers`, `slv_f1__constructors`) y 3 tablas de hechos
(`slv_f1__results`, `slv_f1__qualifying`, `slv_f1__sprint_results`). Añadí la macro
`time_to_ms` y, en `dbt_project.yml`, las `vars` `season_start: 2000` y
`season_end: 2024`. `dbt build --select silver` pasa.
Recuentos contrastados con los CSV de origen: 38 circuitos, 479 carreras,
126 pilotos, 38 constructores, 10.079 resultados, 9.098 filas de clasificación
(435 carreras) y 360 de sprint (18 carreras). Segunda ejecución sin
duplicados.
 
**Por qué lo hice así (y qué alternativas descarté):**
- **Silver filtra 2000-2024 (y no solo Gold).** Antes de 2000 faltan por
  completo la vuelta rápida, las horas de sesión y Q2/Q3 (100 % nulos), y la
  clasificación solo existe desde 1994. Prioricé la calidad del dato sobre la
  reutilización: mi caso de uso es el periodo moderno y no voy a usar años
  anteriores. Descarté dejar todos los años en Silver y filtrar en Gold (más
  reutilizable): quedan fuera 16.680 de 26.759 filas de resultados (62 %), y es
  una renuncia consciente. Un matiz que comprobé: los nulos **no** son el motivo,
  porque las columnas que usa mi método (parrilla, posición, estado, puntos,
  vueltas) están completas en todas las épocas.
- **El periodo vive en `vars`** y ningún modelo lleva el año escrito a mano.
  Ampliar es cambiar un número.
- **Incremental con `merge` y `unique_key`.** Los datos son estáticos, pero así
  puedo añadir temporadas sin recalcular todo si me sobra tiempo, y es la
  estrategia vista en clase. El filtro incremental usa `>=` y no `>`: reprocesa
  la última temporada ya cargada por si hubiera correcciones, y el `merge`
  actualiza en lugar de duplicar. En las entidades añadí `last_season_year`,
  porque no tienen temporada propia y el modelo necesita saber hasta dónde está
  cargado.
- **Claves sustitutas `id_*` con `md5(concat_ws('|', ...))`.** Son
  deterministas (el mismo dato da siempre la misma clave) y se calculan igual en
  todos los modelos, así que se unen sin tablas de correspondencia. El separador
  `|` evita choques al concatenar. Descarté secuencias o `uuid`, que cambiarían
  entre ejecuciones.
- **Entidades = una fila por piloto/constructor/circuito** con `row_number()`
  (la fila más reciente) y no con `group by`: así la fila es real y completa, y no
  una mezcla de valores de filas distintas.
- **`drivers` y `constructors` salen solo de `results`.** Primero pensé en unir
  resultados y clasificación; lo comprobé con los datos y la clasificación no
  aporta ningún piloto (los 124 están dentro de los 126) ni ningún constructor
  (38 en ambas) que no estén ya en resultados.
- **Sin modelo de `status`.** La seed ya está limpia y es única por `status`; se
  une directamente con `ref()`. Un modelo que solo la copiase no aportaría nada.
- **`left join` y no `inner join` entre `results` y la seed de estados.**
  Hoy dan el mismo resultado (los 139 estados casan y salen 10.079 filas), así que
  la diferencia está en **cómo falla**. Con `inner join`, si algún día aparece un
  estado nuevo o con otra ortografía, esas filas desaparecen de `results` sin
  error ni aviso, y con ellas sus puntos y sus duelos (C1) y abandonos (C2): el
  ranking cambiaría sin que nadie lo notase. Con `left join` la fila se conserva
  con `status_category` nulo y un test `not_null` sobre esa columna (día 3) lo
  detecta. Es la misma idea que `try_cast`: no perder datos en silencio, y
  señalar el problema con un test. Lo mismo vale para `sprint_results`.
- **`status_category` se calcula en Silver**, no en Gold: es normalización de
  negocio que reutilizan C1, C2 y C3.
- **`is_classified = position is not null`.** Es la posición oficial: solo la
  tiene quien se clasifica. Coincide con el criterio de `positionText` numérico
  salvo 2 filas de 2005 (ronda 1, Button y Sato); me quedo con `position`.
- **`qualifying` y `sprint_results` son tablas separadas.** El sprint es otro
  evento (más corto, otra escala de puntos, solo 18 fines de semana desde 2021) y
  mezclarlo con la carrera falsearía puntos y vueltas. Ninguna fila de la
  clasificación contiene solo sprint, así que separarlo no pierde nada.
- **Tiempos de clasificación a milisegundos** (`q1_ms`, `q2_ms`, `q3_ms`) para
  poder comparar y restar tiempos de compañeros. La conversión está en una
  macro (`time_to_ms`) con `try_cast`: si un valor viene mal formado se convierte
  en `NULL` en lugar de romper todo el `build`, y un test de calidad avisará si un
  tiempo existente se pierde. Descarté el cast directo (`::int`), que falla con
  vacío, `\N` o formato sin minutos y bloquea todos los modelos dependientes por
  un solo valor.
- **Silver más estrecho que staging:** sin columnas `*_url`, sin fechas y horas
  de entrenamientos libres, sin vuelta rápida ni hora de sesiones. No intervienen
  en ninguna métrica y siguen accesibles en staging.
- **No relleno huecos.** Los nulos de Q2/Q3 y los 44 fines de semana sin
  clasificación (2000-2002) son ausencias reales del origen; se documentan.
**Cosas que aprendí de los datos:**
- La clasificación de 2000-2024 cubre 435 de las 479 carreras. Faltan 4 de 17
  en 2000, 1 de 17 en 2001 y 2 de 17 en 2002; desde 2003 está completa.
- Hasta 2005 la clasificación era de una sola sesión: Q2 y Q3 son nulos. Desde
  2006 hay tres rondas y Q3 solo lo disputan 10 pilotos (en torno a un 45-50 % de
  nulos).
- En 2000-2024 (temporada, ronda, piloto) es único en `results`, `qualifying` y
  `sprint_results`: los duplicados que vi eran todos anteriores a 1979.
- En `results`: `grid` 0 en 93 filas (salida desde el pit lane), `position` nulo
  en 2.141 (no clasificados) y `race_time_ms` nulo en 5.376.
- Los estados de `results` en 2000-2024 son 7.750 `finished`, 1.298 `mechanical`,
  865 `driver_incident`, 158 `other_not_finished` y 8 `not_started`.
- En cada `constructor_ref` hay un único nombre: Toro Rosso, AlphaTauri y RB son
  constructores distintos, no el mismo con nombres cambiantes.
- Los sprint: 360 filas en 18 carreras (3 en 2021, 3 en 2022, 6 en 2023, 6 en
  2024), con 8 estados distintos y todos en la seed.
- Al cambiar las columnas de un modelo incremental ya creado hay que ejecutar
  `--full-refresh`: dbt no elimina columnas por sí solo.
**Problemas encontrados y cómo los resolví:**
- Mi primera idea para `drivers` y `constructors` (unir resultados y
  clasificación) era innecesaria; la simplifiqué tras comprobar los datos.

**Pendiente / siguiente paso:** tests (día 3): `unique` y `not_null` en los `id_*`,
`relationships` entre hechos y entidades, `not_null` en `status_category`,
cobertura 2000-2024 y el test de tiempos perdidos de `qualifying`. Después, Gold:
tabla `int_` con los duelos entre compañeros apilados, C1, C2, C3, tabla de
hechos por piloto y temporada, y el ranking. Por confirmar: que C1 cuente
carrera, clasificación y sprint juntos (cada sesión disputada vale un duelo).
 
### 2026-11-20: staging (3 modelos)
**Qué hice:** creé `stg_f1__calendario`, `stg_f1__resultados` y
`stg_f1__clasificacion` en `models/staging/f1/`, como vistas en
`DEV_SILVER_DB`, schema `f1`. Cada una lee su tabla de Bronze con `source()` y
la expone renombrada y con los tipos correctos. `dbt build --select staging`
pasa. [Pendiente: `_staging_f1__models.yml` con descripciones y tests, que va con el
día 3.]
 
**Por qué lo hice así (y qué alternativas descarté):**
- **Staging 1:1 con Bronze**, solo renombrar y castear (patrón `source` /
  `renamed`). La lógica de negocio va después, en Silver.
- **`source()` solo en staging y `ref()` en el resto.** Así solo staging conoce
  dónde está Bronze y, si cambia, se toca un único sitio.
- **Vistas y no tablas:** staging no transforma el dato, no tiene sentido
  guardarlo dos veces.
- **Sin filtro de años en staging:** es 1:1; la ventana 2000-2024 la aplica
  Silver.
- **`try_to_time` y `try_cast`** para las horas y los números de coche: un valor
  mal formado se convierte en `NULL` en lugar de romper el `build`. Descarté el
  cast directo. Los nulos del origen ya llegan como `NULL` porque el
  file format convierte `\N` y vacío.
- **Unidades en el nombre** (`circuit_altitude_m`, `fastest_lap_speed_kmh`) y
  `_loaded_at` renombrado a `date_load`, como en la guía.
- **Sin tests todavía:** los tests son el tema del día 3 y los pondré todos
  juntos en ese momento.
**Problemas encontrados y cómo los resolví:** la vista previa del IDE daba
"syntax error unexpected 'limit'": dbt v1 añade su propio `limit` a la vista
previa, así que no hay que escribirlo.
 
**Pendiente / siguiente paso:** Silver.

### 2026-11-19: cambio del origen a 3 ficheros planos
**Qué hice:** sustituí los 8 CSV originales por tres ficheros planos
(`calendario`, `resultados`, `clasificacion`) con todos los años (1950-2024).
Rehice el script 02 (carga de Bronze: 3 tablas en `DEV_BRONZE_DB.f1`, con
limpieza de las 8 antiguas) y el script 03, que ahora clona solo PRO. Rehice las
sources (3 tablas, todas las columnas documentadas) y ajusté el seed.
Recuentos en Bronze: calendario 1125, resultados 26759, clasificacion 10494
(iguales en DEV y PRO). `dbt parse`, `dbt seed`, `dbt test` (6 tests) y
`dbt build` pasan.

**Origen de los datos:** los ficheros son datos de F1 publicados en Kaggle,
derivados del dataset *Formula 1 World Championship (1950-2020)* de Rohan Rao.


**Por qué lo hice así (y qué alternativas descarté):**
- **Ficheros planos desnormalizados** en lugar de las 8 tablas relacionales:
  el profesorado pidió datos desnormalizados y que el linaje no sea lineal. Con
  Bronze plano, Silver tiene que "desgranar" las entidades (pilotos, equipos,
  circuitos, carreras), y ahí aparecen uniones, claves nuevas y ramas reales.
  Descarté mantener las 8 tablas porque ya vienen normalizadas y el linaje
  saldría casi lineal.
- **Bronze conserva todos los años** (1950-2024) y el filtro 2000-2024 se
  aplica después, en Silver o Gold: Bronze es el dato crudo y la ventana
  del caso de uso es una regla de negocio.
- **Sin ids en Bronze:** las filas se identifican por clave natural
  (`season_year` + `round`, `driver_ref`, `constructor_ref`). Los ids se
  generan en Silver como claves sustitutas.
- **El seed se une por `status` (texto) y no por `status_id`:** los ids
  originales ya no viajan en Bronze. Comprobé que el texto es único en los 139
  estados y que los 137 estados de `resultados` y los 8 del sprint están todos en
  el seed. Se añadió `not_null` al texto, que ahora es la clave de unión.
- **Script 03 solo con PRO:** sin entorno PRE. Las databases PRE existen pero no
  se usan.

**Cosas que aprendí de los datos:**
- Los sprint vienen dentro de `clasificacion`, al final de cada fila de
  clasificación. Los 360 sprint originales están todos, así que no se perdió
  ninguno. En Silver hay que separarlos otra vez.
- `resultados` tiene 85 combinaciones repetidas de (temporada, ronda, piloto),
  todas anteriores a 1979 (coches compartidos). En 2000-2024 no hay ninguna, así
  que el test de unicidad debe aplicarse después del filtro del periodo.
- Los nulos vienen marcados como `\N`; el formato de fichero de Snowflake los
  convierte a NULL.

**Problemas encontrados:** ninguno.

**Pendiente / siguiente paso:** modelos de staging (`stg_f1__*`) y su
configuración en `dbt_project.yml`; después, Silver.

### 2026-11-17: sources de Bronze y ajuste del tipo del seed
**Qué hice:** creé `models/staging/f1/_f1__sources.yml` con las 8 tablas de
`DEV_BRONZE_DB.f1` (circuits, constructors, drivers, races, status, qualifying,
results, sprint_results) y todas sus columnas, incluida `_loaded_at`, cada una
con su descripción. La database se resuelve con `env_var('DBT_BRONZE_DB')`.
Ajusté el seed `status_classification` para que `status_id` sea `integer` y
lo recreé con `dbt seed --full-refresh`. [`dbt parse` OK / preview de
`source('f1', 'status')` devuelve filas].

**Por qué lo hice así (y qué alternativas descarté):**
- **Sin freshness.** Bronze se cargó una vez, a mano, desde un dataset
  histórico y estático; el umbral de 24/48 h de la guía fallaría siempre.
  Mis profesores sugirieron usarlo para verificar que los datos llegan hasta
  2024; lo valoré (apuntando `loaded_at_field` a `races.date`), pero compara
  contra la fecha de hoy y los umbrales se desplazarían cada día, así que no
  comprueba exactamente "hasta 2024". Se activaría si amplío con más
  temporadas o datos en directo; `_loaded_at` se mantiene en Bronze por la
  convención de la plantilla. La cobertura 2000-2024 la comprobaré con un test
  cuando veamos los tests en el curso.
- **Todas las columnas documentadas** (no solo las clave): sigue el ejercicio
  de la guía y deja el catálogo completo en `dbt docs`.
- **`status_id` como `integer` en el seed:** el join se hará contra los `stg_*`,
  donde los ids ya serán enteros. Regla general: Bronze guarda los ids como
  `varchar` tal como llegan y staging los convierte al tipo real.
- **Tests de sources aplazados** hasta el tema de tests del curso. Mi
  inclinación es ponerlos en staging.

**Cosas que aprendí de los datos:**
- `drivers.number` es el número permanente elegido por el piloto (sistema
  desde 2014); solo 59 de los 861 pilotos lo tienen. No es el dorsal de cada
  carrera, ese está en `results.number`.
- `results.position` solo existe para pilotos clasificados (≥ 90 % de las
  vueltas del ganador); `positionOrder` siempre tiene valor y ordena
  detrás a los no clasificados por vueltas. En 2000-2024 son idénticos
  cuando `position` está informada (las únicas 13 filas que difieren son de
  Brasil 1983). `positionText` indica si la posición es real (número) o
  administrativa (letra).
- `grid = 0` cuando no hay posición de parrilla.

**Problemas encontrados:** ninguno.

**Pendiente / siguiente paso:** Siguiente tema de la guía (staging, Día 2).

### 2026-11-16: configuración del seed y entorno de dbt
**Qué hice:** creé `seeds/status_classification.csv` (139 filas) y `seeds/_seed.yml`
con descripciones y 5 tests. Configuré el seed en `dbt_project.yml` (destino en
Silver mediante `DBT_SILVER_DB`, schema `seeds` y tipos fijados con
`+column_types`). Renombré el proyecto a `f1`. `dbt parse`, `dbt seed` y
`dbt test` pasaron. Recuento en Snowflake: [139].

**Decisiones de entorno:**
- Dos entornos (DEV y PRO), sin PRE: proyecto en solitario, sin otro equipo
  que valide. Las databases PRE existen en Snowflake por la plantilla, pero no
  se usan.
- Trabajo en la rama `DEV` con pull request a `main`.
- Versión de dbt: v1 (latest). En producción usaré la misma.

**Problemas encontrados:** ninguno.

**Siguiente paso:** declarar las sources de Bronze (`DEV_BRONZE_DB.f1`) con
freshness sobre `_loaded_at`, y después los modelos `stg_*`.

### 2026-11-15: seed de clasificación de estados (status_classification)
**Qué hice:** revisé la guía del Día 1 (seeds y sources) y decidí qué aplicar a
mi proyecto. Definí la clasificación de los 139 estados de `status` en cinco
categorías y generé el CSV `status_classification.csv`, que será un seed en
Silver. Dentro de `/dbt` (subdirectorio configurado en dbt Platform), el seed irá
en `seeds/`. [Pendiente: configurarlo y ejecutar `dbt seed`.]

**Por qué un seed (y qué alternativas descarté):**
- La clasificación no existe en origen: `status` solo trae `statusId` y el texto.
  Es una regla de negocio mía, así que no va a Bronze, que debe conservar el
  dato tal como llega de la fuente.
- Alternativa descartada: un `CASE` en un modelo de Silver. Es válida, pero
  deja 139 estados enterrados en SQL, sin descripción ni tests propios. La guía
  del curso recomienda los seeds para listas cortas y estables que no existen
  en origen, como un mapeo de categorías.
- `status` se queda intacta en Bronze, y el seed se une a ella por `status_id`.

**Categorías y criterios:**
- `finished` (34): terminó, incluidas las vueltas de retraso.
- `mechanical` (81): fallo del coche o causa ajena al piloto. Incluye neumáticos
  y `Debris`, `Handling`, `Out of fuel` y `Launch control`.
- `driver_incident` (4): solo `Accident`, `Collision`, `Spun off` y
  `Collision damage`. Regla: únicamente lo que el propio estado describe como
  un error o incidente en pista.
- `other_not_finished` (17): causas administrativas, médicas, de seguridad o sin
  causa clara. Incluye `Retired`, `Withdrew`, `Not restarted`, `Not classified`,
  `Stalled`, lesiones, enfermedad y exclusiones.
- `not_started` (3): solo quien nunca estuvo en parrilla (`Did not qualify`,
  `Did not prequalify`, `107% Rule`).

**Decisiones concretas y su porqué:**
- `Retired` (76 filas, 0,75 % de 10.079 en 2000-2024) va a `other_not_finished`.
  El estado no indica causa. Revisé una muestra de 6: 5 fueron fallos del coche
  y 1 es ambiguo, lo que descarta `driver_incident` pero no basta para asumir
  `mechanical` en las 76.
- Neumáticos y `Debris` quedan en `mechanical` ampliando su definición a "causa
  ajena al piloto". Revisé casos como Vettel (Bélgica 2015, clasificado 12º con
  un reventón) y un reventón atribuido a residuos metálicos en pista.
- `Withdrew`, `Not restarted` y `Not classified` entran en `other_not_finished`: los datos
  muestran que algunos sí corrieron vueltas.
- `Stalled` es ambiguo (fallo del coche o error del piloto), así que va a
  `other_not_finished`, el mismo criterio que `Retired`.
- Lesiones, enfermedad y seguridad (13 filas) van a `other_not_finished`: no dicen
  nada sobre cómo conduce el piloto.
- **Clasificado ≠ terminó la carrera.** Un piloto está clasificado si completa al
  menos el 90 % de las vueltas del ganador (`positionText` numérico). De las
  1.299 filas mecánicas en 2000-2024, 120 (9 %) están clasificadas.
- **Opción A elegida:** se excluye de C1 y C3 toda fila `mechanical`, esté
  clasificada o no. Motivo: se explica en una frase y no depende del umbral del
  90 %. La opción B (excluir solo las no clasificadas) queda como análisis de
  sensibilidad.

**Problemas encontrados y cómo los resolví:** ninguno.

**Pendiente / siguiente paso:** configurar el seed en `dbt_project.yml` (destino en
Silver, `status_id` como `varchar` con `+column_types`), crear `seeds/_seeds.yml`
con descripciones y tests (`unique` en `status_id`, `accepted_values` en la
categoría), ejecutar `dbt seed` y comprobar que hay 139 filas.

### 2026-11-11: conexión de Snowflake con dbt Platform mediante clave RSA
**Qué hice:** añadí un script de Python (Snowpark) que genera un par de claves
RSA de 2048 bits: la clave privada cifrada en formato PKCS#8 con una passphrase
aleatoria, y la sentencia `alter user ... set rsa_public_key` con la clave
pública. Ejecuté el `alter user` con SECURITYADMIN y configuré la conexión en dbt
Platform con mi usuario, la clave privada y la passphrase, usando el rol
DEV_TRANSFORM_ROLE, el warehouse WH_PROYECTO y DEV_SILVER_DB.

**Por qué lo hice así (y qué alternativa descarté):**
- Autenticación por clave en lugar de usuario y contraseña: no se guarda ninguna
  contraseña en la configuración de dbt y porque mi cuenta exige MFA.

**Problemas encontrados y cómo los resolví:** ninguno.

**Pendiente / siguiente paso:** borrar la salida del worksheet con la clave y la
passphrase, comprobar la conexión con `dbt debug` o el botón de test, y crear
las sources y los modelos stg_*.

### 2026-11-09: entorno Snowflake y carga de bronze (scripts 01, 02 y 03)
**Qué hice:** ejecuté los tres scripts de la plantilla del curso, adaptados al
proyecto:
- 01: warehouse WH_PROYECTO, databases bronze/silver/gold para DEV, PRE y PRO,
  roles de transformación por entorno y REPORTING_ROLE.
- 02: carga de los 8 CSV de F1 en DEV_BRONZE_DB.f1 (stage carga_bronze,
  file format csv_bronze y COPY INTO).
- 03: clones PRE_BRONZE_DB y PRO_BRONZE_DB a partir de DEV_BRONZE_DB, y permisos
  de lectura sobre bronze para cada rol de su entorno.
Comprobé los recuentos (results 26759, etc.) y que DEV_TRANSFORM_ROLE puede leer
bronze.

**Por qué lo hice así (y qué alternativa descarté):**
- Sigo la plantilla del curso y solo cambio lo propio de mi fuente.
- Schema f1 en lugar de kaggle_f1: nos dijeron que el schema no suele llevar el
  nombre de la fuente; f1 describe el contenido.
- Sin columnas _fivetran_*: mis datos vienen de un CSV de Kaggle, no de Fivetran.
  Mantengo _loaded_at (DEFAULT current_timestamp()) para poder usar el freshness
  de dbt.
- Nulos: el dataset marca los nulos como \N; el file format los trata como NULL,
  además de la cadena vacía.
- Ids y tiempos como varchar en bronze, como en la plantilla; los tipos
  definitivos se aplican en staging. Medidas numéricas y fechas sí llevan tipo.
- No uso Fivetran: la fuente es una descarga estática y no necesita
  sincronización recurrente, así que simulo la ingesta con una carga manual a un
  stage, como en el curso.
- Los CSV también se guardan en el repo (carpeta de datos) solo para que el
  proyecto sea reproducible; no se carga desde GitHub porque COPY INTO lee de
  stages, no de repositorios.

**Problemas encontrados y cómo los resolví:** ninguno.

**Pendiente / siguiente paso:** crear el proyecto dbt (profiles.yml, sources
apuntando a DEV_BRONZE_DB.f1 y los 8 modelos stg_*). Aviso para el futuro: si
recargo bronze con el script 02 (usa create or replace table), hay que repetir
el 03 para recrear los clones y los permisos.

### 2026-11-06: criterio de mínimo de carreras y script de carga bronze
**Qué hice:** fijé un mínimo de 36 carreras para entrar en el top del ranking y preparé el script SQL de carga de las 8 tablas en el esquema `RAW`.
**Por qué lo hice así (y qué alternativa descarté):** el mínimo evita que un piloto con una sola temporada brillante se cuele en el top 5. Elegí 36 (temporada y media) frente a no poner filtro, 5 o 24 carreras. El ranking se calcula completo y se marca con una columna `cumple_minimo_carreras`, en lugar de excluir pilotos del modelo, para poder mostrar el efecto del filtro. En bronze los tiempos se dejan como texto y los nulos `\N` se convierten a `NULL`; los tipos se tratarán en staging.
**Problemas encontrados y cómo los resolví:** tres pesos de 0,33 suman 0,99; usaré 1/3 exacto para que el test de pesos pase.
**Pendiente / siguiente paso:** cargar los datos y verificar recuentos (circuits 77, constructors 212, drivers 861, races 1125, status 139, qualifying 10494, results 26759, sprint_results 360).

### 2026-11-05: definición del caso de uso, método y arquitectura
**Qué hice:** definí el caso de uso (¿quién es el mejor piloto 2000-2024, independientemente del coche?) y diseñé el método, la arquitectura Medallion y el plan de trabajo.
**Por qué lo hice así (y qué alternativa descarté):**
- Un único caso de uso grande, con un contrapunto (ranking en bruto frente a ajustado), en lugar de dos casos medianos.
- Score compuesto de tres componentes (C1 duelo con el compañero, C2 abandonos atribuibles al piloto con signo negativo, C3 carrera relativa a la parrilla), en lugar de solo el duelo con el compañero o un ELO.
- Pesos fijos iguales; los pesos configurables con `vars` quedan como mejora opcional.
- La clasificación de los 139 estados de `status` va en un seed, no en un `CASE` dentro del SQL.
- Bronze son las tablas `RAW` declaradas como sources, no modelos dbt, para evitar un linaje lineal sin valor.
- Solo cargo 8 CSV; el resto de información (clasificaciones) se deriva con dbt.
**Problemas encontrados y cómo los resolví:** ninguno.
**Pendiente / siguiente paso:** carga bronze y configuración del proyecto dbt.

---

## Registro de decisiones (resumen vivo)

| Decisión | Alternativa descartada | Justificación |
| --- | --- | --- |
| Un caso de uso grande con contrapunto | Dos casos medianos | Profundidad en un solo problema |
| Score compuesto C1, C2, C3 | Solo compañero; ELO | Cada componente ataca un aspecto distinto del efecto coche |
| Seed para clasificar `status` | `CASE` en el SQL | Revisable y discutible sin tocar código |
| Pesos fijos de 1/3 | `vars` con sensibilidad | Punto de partida neutro; `vars` si hay tiempo |
| Mínimo de carreras para entrar en el ranking: 100 (36 en el diseño inicial, como sensibilidad) | Sin filtro; 36 | Con 36 entraba un piloto de dos temporadas en un equipo de la cola (Albers, 3.º); con 100 (unas cinco temporadas) desaparece |
| Carga manual a stage interno | Cargar desde GitHub | Datos estáticos; sin integraciones innecesarias |
| Periodo 2000-2024 | Otro rango | Antes de 2000 faltan datos de sesión y la clasificación empieza en 1994 (véase "Silver filtra 2000-2024") |
| Schema de bronze llamado f1 | kaggle_f1 (nombre de la fuente) | Describe el contenido, no el origen |
| Sin columnas _fivetran_*; _loaded_at sí | Copiar las columnas de la plantilla | La fuente es un CSV de Kaggle; _loaded_at permite el freshness |
| Ids y tiempos en varchar en bronze | Tipar todo en bronze | Convención de la plantilla; tipos definitivos en staging |
| No usar Fivetran | Montar un conector | Fuente estática, sin sincronización recurrente |
| Clasificación de estados como seed (no CASE ni tabla en Bronze) | CASE en un modelo de Silver; CSV cargado en Bronze | Es regla de negocio que no existe en origen; versionada en Git, documentada y testeada aparte |
| `driver_incident` solo para accidentes y colisiones | Incluir también neumáticos o `Retired` | Solo lo que el estado describe como error en pista, para no penalizar al piloto sin evidencia |
| `Retired` y `Stalled` en `other_not_finished` | `mechanical` o `driver_incident` | El estado no indica causa; la muestra revisada no basta para generalizar |
| Opción A: excluir todo `mechanical` de C1 y C3 | Excluir solo los no clasificados (B) | Regla simple y no depende del umbral del 90 %; B se prueba en la sensibilidad |
| Dos entornos (DEV y PRO), sin PRE | Los tres entornos del curso | Proyecto en solitario: PRE sería un paso intermedio sin otro equipo que valide; las databases PRE existen en Snowflake por la plantilla pero no se usan |
| Rama de trabajo DEV, PR a main | Una rama por tarea | Un solo desarrollador; se conserva el pull request como punto de revisión antes de producción |
| Seed con `status_id` como `integer` | `varchar` (el tipo de Bronze) | El join se hace contra los `stg_*`, donde los ids ya son enteros; el seed lleva el tipo final. Corregido tras la primera versión |
| Staging 1:1 con Bronze, como vista | Poner lógica de negocio en staging | Staging solo renombra y castea; la lógica va en Silver |
| `source()` solo en staging, `ref()` en el resto | `source()` repartido por varias capas | Un único punto que conoce Bronze |
| `try_to_time` / `try_cast` en staging y en la macro `time_to_ms` | Cast directo (`::int`) | Un valor mal formado no rompe el `build`; un test de calidad avisa si se pierde un dato |
| Silver filtra 2000-2024 | Silver con todos los años y filtro en Gold | Antes de 2000 faltan por completo vuelta rápida, horas de sesión y Q2/Q3 y la clasificación empieza en 1994. Calidad sobre reutilización: el caso de uso es el periodo moderno. Coste asumido: 62 % de las filas de resultados (16.680 de 26.759) |
| Periodo 2000-2024 en `vars` | Años escritos en cada modelo | Un único punto de cambio; ampliar el periodo es cambiar un número |
| Silver incremental con `merge` y `unique_key` | Tablas completas en cada ejecución | Permite añadir temporadas sin recalcular todo; estrategia vista en clase |
| Filtro incremental con `>=` la última temporada | `>` | Reprocesa la última temporada por si hay correcciones; el `merge` actualiza y no duplica |
| Claves `id_*` con `md5(concat_ws('\|', ...))` | Claves naturales, secuencias o `uuid` | Deterministas y homogéneas: se calculan igual en todos los modelos y se unen sin tablas de correspondencia |
| Entidades con `row_number()` (fila más reciente) | `group by` con agregaciones | Devuelve una fila real y completa, sin mezclar valores de filas distintas |
| `drivers` y `constructors` solo desde `results` | Unir resultados y clasificación | Verificado: clasificación y sprint no aportan ningún piloto ni constructor nuevo |
| Sin modelo Silver de `status` | Modelo que copie la seed | La seed ya está limpia y es única; se une con `ref()` |
| `left join` entre `results` y la seed de estados | `inner join` | Con `inner`, un estado nuevo o mal escrito haría desaparecer filas (puntos, duelos, abandonos) sin ningún aviso. Con `left` se conserva la fila con categoría nula y un test `not_null` lo detecta |
| `status_category` calculada en Silver | Calcularla en Gold | Es normalización de negocio que reutilizan C1, C2 y C3 |
| `is_classified = position is not null` | `positionText` numérico | Es la posición oficial; coincide salvo 2 filas de 2005 |
| `qualifying` y `sprint_results` como tablas separadas | Una sola tabla de sesiones | El sprint es otro evento con otra escala de puntos; mezclarlo falsearía puntos y vueltas |
| Tiempos de clasificación en milisegundos | Dejar el texto `m:ss.mmm` | El texto no se puede comparar ni restar; los milisegundos permiten calcular diferencias entre compañeros |
| `try_cast` con test que avise | Que el `build` falle | Un valor ilegible no debe bloquear todos los modelos; el test lo señala para investigarlo |
| Silver sin columnas `*_url`, sin entrenamientos libres ni vuelta rápida | Arrastrar todas las columnas | No intervienen en ninguna métrica; siguen en staging, así que no se pierde información |
| No imputar huecos (44 carreras de 2000-2002 sin clasificación, Q2/Q3) | Rellenar con estimaciones | Son ausencias reales del origen; se documentan y se mide la cobertura en un test |
| Staging sin tests hasta el día 3 | Tests desde el principio | Seguir la guía del curso; se añadirán todos juntos |
| C1 cuenta duelos de carrera, clasificación y sprint juntos | Solo carrera; pesos por sesión | Cada duelo vale 1 y el peso de cada sesión sale de su frecuencia, sin inventar pesos. La clasificación pesa algo más (4.417 duelos frente a 3.896 de carrera) |
| Demo del incremental con tasks de Snowflake y macros | Job de dbt en PRO; procedimientos; una macro que borre y cargue | Son lo visto en clase; no se ejecuta sola; limpiar va aparte para que un duplicado se vea |
| Duelos entre compañeros en un modelo aparte, `ephemeral` | Duelos y C1 en un solo modelo; dos `int` consecutivos materializados | El profesorado desaconseja un `int` leyendo otro `int`; el ephemeral no crea objeto, aunque sigue en el linaje y no se puede testear |
| Los duelos incluyen carrera, clasificación y sprint | Solo carrera; pesos por sesión | Cada duelo vale 1, sin pesos inventados |
| C2 usa todas las carreras con salida (solo excluye `not_started`) | Excluir también `mechanical` (opción A) | La avería no es incidente, pero sí carrera disputada: es el denominador de la tasa |
| Nivel del coche = puesto del constructor con puntos de carrera + sprint | Solo carreras; nivel carrera a carrera | Reproduce el campeonato real (2023: McLaren 4.º) y se calcula una vez por temporada |
| Puesto esperado = media real de puesto final de ese nivel de coche | `2 * puesto - 0,5` | La fórmula fija inflaba a los equipos de la cola y no dejaba destacar a los de arriba; la media real deja el C3 medio en torno a 0 |
| `rank()` para el puesto del constructor | `row_number()` con desempate por id; `dense_rank()` | Los equipos empatados comparten puesto, sin orden arbitrario; `dense_rank` junta niveles distintos |
| Puesto del constructor como CTE dentro de C3 | Tabla en Silver; `gold_results__enriched` | Solo lo usa C3; evita un `int -> int` y un cálculo duplicado |
| z-score por temporada para C1, C2 y C3 | Sumar los valores brutos | Pone las tres en la misma unidad; el peso de 1/3 es real |
| C2 resta en la fórmula del score | Invertir el z-score de C2 al calcularlo | Es una tasa de incidentes: más es peor |
| Muestra fiable: 8 carreras válidas y 10 duelos | Todas las filas | Evita que un piloto con una carrera distorsione la media y la desviación; umbrales ajustables |
| `fct_driver_season` con C2 como base y `left join` | `full outer join`; `inner join` | C2 tiene una fila por piloto que tomó la salida; los que faltan en C1 o C3 no son fiables |
| Ranking como consulta (`analyses`), media ponderada por carreras | Tabla `ranking`; media simple | El top es un filtro; una temporada larga debe pesar más que una corta |
| C1 sin ponderar por la calidad del compañero | Ponderar por el C3 del rival; ratings tipo Elo | Fuera del alcance en el plazo; se documenta como limitación y trabajo futuro |
| `dim_driver` y `dim_constructor` con resumen de carrera | Copiar la entidad de Silver tal cual | Es desnormalizar; el contraste en bruto necesita victorias y podios por piloto. Las medidas en una dimensión no son lo más purista: se defienden como atributos de carrera |
| `dim_race` con el circuito incluido | `dim_race` y `dim_circuit` separadas | Una fila por carrera sin segundo `join`; mismo caso que `dim_users` con `dim_addresses` |
| `gold_results__enriched` une carrera, clasificación y sprint | Unir también piloto, equipo y carrera | Esos datos ya están en las dimensiones; las tres sesiones están separadas en Silver a propósito |
| `left join` desde `results` en el `enriched` | `inner join` | Faltan clasificaciones (981 filas) y el sprint solo existe en 18 carreras; con `inner` se perderían filas |
| `fct_driver_race` con `total_points` y `coalesce(sprint_points, 0)` | Sumar sin `coalesce` | `null + número` da `null`: se perdería el total en carreras sin sprint |
| Un `.yml` por carpeta con descripción de modelos y columnas, sin tests hasta el día 3 | Un `.yml` por modelo; tests desde el principio | Menos archivos y misma convención en todas las capas; los tests se añaden juntos al ver cómo los pide el curso |


## Errores y soluciones (rellenar según aparezcan)

| Fecha | Error | Causa | Solución |
| --- | --- | --- | --- |