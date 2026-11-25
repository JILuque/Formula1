# Bitácora del proyecto final: mejor piloto de F1 2000-2024
 
Cuaderno de trabajo. Se añade una entrada por sesión, la más reciente arriba.
Fecha de entrega: 26 de noviembre de 2026.
 
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
 
### 2026-11-25: incrementalidad en todo Gold (la cadena incremental llega hasta el ranking)
**Qué hice:** el profesor avisó de que un error grave es hacer incremental en Silver y no
pasarlo a Gold, porque el ahorro se pierde en el eslabón más débil. Convertí en incrementales
(`merge`, `unique_key`, `on_schema_change='fail'` y ventana desde la última temporada con `>=`,
igual que Silver) los nueve modelos de Gold: `gold_results__enriched`,
`int_f1__driver_season_c1`, `int_f1__driver_season_c2`, `int_f1__driver_season_c3`,
`fct_driver_race`, `fct_driver_season`, `dim_race`, `dim_driver` y `dim_constructor`.
Cada modelo lleva un comentario con la razón. Amplié la macro `ver_2025`: además de las 7 filas
de Silver, cuenta las filas de 2025 en cada modelo de Gold (esperado: 16 en total
[Confirmar: el 16 sale de mi cálculo, 2+2+2+2+2+2+1+2+1]).
Flujo de la demo: `dbt run-operation insertar_incremental`, `dbt run --select silver gold
--vars '{season_end: 2025}'`, `dbt run-operation ver_2025` y, al terminar, `dbt run-operation
limpiar_incremental` seguido de `dbt run --select silver gold --full-refresh` (sin `--vars`).
Probado en DEV: `ver_2025` devuelve las 7 filas esperadas en Silver [Completar: recuentos de Gold
y comprobar que, tras limpiar, el ranking es idéntico al de antes y `dbt build` completo en verde].
 
**Por qué lo hice así (y qué alternativa descarté):**
- **Todo Gold incremental, con la misma estrategia que Silver.** Alternativa: dejar Gold en full
  refresh por ser pequeño. La descarté porque el incremental es una cadena: si un eslabón relee
  todo, el ahorro se pierde. Así, el día que lleguen 2025 y 2026, solo se procesa lo nuevo, y hay
  una sola estrategia que explicar.
- **`dim_driver` y `dim_constructor` por claves afectadas.** Son totales de toda la carrera, así
  que un filtro por temporada daría totales incorrectos. Se reprocesan solo los pilotos y
  constructores que aparecen desde la última temporada, pero con todo su historial.
- **C3 lee todo el histórico y solo escribe la última temporada.** El puesto esperado es la media
  de todas las temporadas para cada puesto de constructor. Si filtrara también la entrada, la media
  saldría solo con la última temporada y el C3 nuevo sería incorrecto.
- **`fct_driver_season` filtra la entrada a la última temporada.** Los z-scores se calculan dentro
  de cada temporada (`partition by season_year`), así que una temporada nueva no cambia los de
  las demás.
- **Limpiar la demo con `--full-refresh` de Silver y Gold.** Alternativa: borrar filas a mano con
  `delete`. El `merge` no borra; recrear las tablas desde Bronze limpio es reproducible y deja
  el ranking como estaba.
- **Limitación asumida:** al entrar una temporada nueva, la media de C3 cambia un poco y el C3
  (y el score) de las temporadas anteriores no se actualiza con el incremental. Se corrige con un
  `--full-refresh` de C3 y `fct_driver_season` de forma periódica, por ejemplo al cerrar cada
  temporada. La diferencia esperada es pequeña: una temporada nueva pesa poco frente a 25.
  Primero había pensado dejar C3 y `fct_driver_season` en full refresh; lo cambié para que la
  cadena sea incremental de punta a punta.
**Problemas encontrados y cómo los resolví:**
- La demo no veía los datos de 2025: `season_end` está en 2024 y Silver filtra con `between
  season_start and season_end`. Se resuelve ejecutando el run de la demo con
  `--vars '{season_end: 2025}'`; la limpieza va sin `--vars`.
- Una afirmación mía anterior era falsa: que una carrera nueva solo afecta a su temporada. Vale para
  C1 y C2, no para C3 (usa una media de todas las temporadas); de ahí el diseño de C3.
**Pendiente / siguiente paso:** completar las marcas de arriba, `dbt build` completo en DEV, PR
a `main` y job de PRO. La primera ejecución en PRO convierte las vistas de `intermediate` y
las tablas de `core` en incrementales. No usar `--full-refresh` en el job de PRO.
 
---
 
### 2026-11-23: día 8 (groups, access, grants, exposure y contrato)
**Qué hice:**
- **Grupo `analitica_f1`** en `models/_groups.yml`, con un único propietario. Asignado a todo
  Gold con `+group` en `dbt_project.yml`.
- **`+access: private` en `gold/intermediate` y `+access: public` en `gold/core`.** Staging y
  Silver se quedan en `protected` (por defecto).
- **Grants declarativos:** `+grants: select: ['REPORTING_ROLE']` en `gold/core`. Compruebo con
  `show grants on table …DIM_DRIVER`. `REPORTING_ROLE` aparece con `SELECT`.
- **Permisos de lectura para `REPORTING_ROLE` en PRO** (rol dado a mi usuario, uso del warehouse,
  de `PRO_GOLD_DB` y de sus schemas, también los futuros) con `SECURITYADMIN`. Ejecutado, 
  y consulta de `FCT_DRIVER_SEASON` con `REPORTING_ROLE` en PRO.
- **Exposure `ranking_mejor_piloto`** de tipo `analysis`, que depende de `fct_driver_season` y
  `dim_driver`. Fichero creado y `dbt build --select +exposure:ranking_mejor_piloto`
  en verde.
- **Contrato en `fct_driver_season`:** `contract: enforced: true`, con el `data_type` de las 14
  columnas sacado de `describe table` y `not_null` como constraint en las seis columnas que ya
  tenían ese test. `dbt test --select test_type:unit` en verde y ranking sin cambios (Alonso
  0,85, Max Verstappen 0,82, Hamilton 0,53, Vettel 0,50).
**Por qué lo hice así (y qué alternativa descarté):**
- **Un solo grupo.** Solo hay un equipo. `private` en los `int` no restringe a nadie dentro del
  proyecto, pero deja escrita la intención: los `int` no son para consumir desde fuera, y lo que
  se consume está en `core`. Conservo `meta.owner` del día 4 como catálogo.
- **Los grants van declarados y no con `run-operation`.** Se aplican en cada construcción, también
  cuando `table` recrea las tablas. `REPORTING_ROLE` necesitaba además uso del warehouse y de la
  base y los schemas, que el script 01 no le daba; los concedo una vez con `SECURITYADMIN`.
- **Exposure de tipo `analysis` y no `dashboard`.** No he hecho el Power BI: no me sentía
  confiado con lo explicado en clase, y Power BI Desktop solo funciona en Windows. Declarar un
  dashboard que no existe sería deshonesto. Si lo hago, cambio una palabra.
- **El contrato solo en `fct_driver_season`.** Es la tabla que consume el ranking y la que
  merece una garantía de forma. Los demás modelos de `core` suman unas 40 columnas más y no tienen
  consumidores externos; el beneficio no compensa el trabajo ni el riesgo de errores de tipos.
  Los tests siguen: de las constraints solo `not_null` la aplica Snowflake, la unicidad la
  garantizan los tests.
- **Versiones de modelo: no.** No hay consumidores a los que dar tiempo para migrar, y una
  `deprecation_date` en un proyecto con un solo propietario sería de adorno.
- **CI con `state:modified+`.Requiere la integración nativa de GitHub, 
   una ejecución previa del job de PRO como estado de
  comparación y un job en DEV con target `ci`. Mantuve la salvaguarda de CI en
  `generate_schema_name`, así que estaría lista.
**Cosas que aprendí:**
- Un test singular que lee un modelo `private` falla en el `parse`: tiene que pertenecer al grupo
  del modelo. La solución es asignarle el grupo con `{{ config(group='analitica_f1') }}`, no
  abrir el acceso.
- `_groups.yml` tiene que estar dentro de `models/`; en la raíz del proyecto dbt no lo lee y da
  "Invalid group … expected one of...".
- En un contrato, `varchar` sin longitud no coincide con `varchar(32)`: hay que copiar el tipo
  exacto del `describe table`.
**Problemas encontrados y cómo los resolví:**
- `Parsing Error … attempted to reference node … int_f1__driver_season_c1 … private to the
  'analitica_f1' group` en `assert_numero_duelos_C1`: añadí `{{ config(group='analitica_f1') }}`
  al test.
- `Invalid group 'analitica_f1', expected one of []`: había creado `_groups.yml` en la raíz del
  proyecto en lugar de en `models/`. Lo moví.
**Pendiente / siguiente paso:** pull request a `main`, ejecutar el job de PRO, comprobar la
lectura con `REPORTING_ROLE`, decidir si hago el CI, y cerrar la bitácora con los resultados
marcados.
 
---
 
### 2026-11-23: duelos de compañeros dentro de C1 (un solo modelo)
**Qué hice:**
- **Uní `int_f1__teammate_duels` en `int_f1__driver_season_c1`.** Los duelos pasan a ser dos
  CTE de C1 (`sessions` y `duels`) y el modelo agrega al final. Borré el fichero
  `int_f1__teammate_duels.sql` y su bloque de `_intermediate__models.yml`; la descripción de
  C1 ahora explica cómo se calculan los duelos. No hay nada que borrar en Snowflake, porque el
  modelo era `ephemeral` y no creaba ningún objeto.
- **Comprobación:** `dbt parse` sin errores, `sum(n_duels)` igual antes y después
  del cambio, `dbt build --select int_f1__driver_season_c1+` en verde (con
  `assert_numero_duelos_C1` y los dos unit tests) y ranking sin cambios (Alonso 0,85,
  Max Verstappen 0,82, Hamilton 0,53, Vettel 0,50).
**Por qué lo hice así (y qué alternativa descarté):**
- **Un solo modelo en lugar de dos.** Comenté con otra profesora el diseño de los dos `int`
  consecutivos. Ya había dejado el de duelos como `ephemeral` por la primera sugerencia del
  profesorado (un `int` que lee de otro `int` es poco limpio). Ella lo ve bien, pero opina
  que, si solo se necesita en un sitio, es mejor un solo `int`. Los duelos solo los lee C1.
- **Es el mismo SQL.** Un modelo `ephemeral` se inyecta como CTE en el modelo que lo usa, así
  que unirlos compila a la misma consulta y los datos no cambian. Tampoco se pierde
  testabilidad: un `ephemeral` ya no se podía testear por separado.
- **La razón del 21 de noviembre ya no se sostiene.** Entonces descarté unirlos porque
  "mezcla dos responsabilidades" y porque la tabla de duelos podría servir a otros análisis.
  Hoy ningún otro modelo la usa; los duelos son un paso interno de C1, y la responsabilidad del
  modelo es "C1 por piloto y temporada". Si algún día otro criterio necesita los duelos, se
  vuelve a separar (esta decisión sustituye a la anterior, que sigue en la bitácora con su fecha).
- **`duels` solo conserva `season_year`, `id_driver` y `win_duel`.** Son las únicas columnas
  que C1 usa después; `id_race`, `session_type`, `id_constructor` e `id_rival` solo hacían
  falta para el emparejamiento.
- **Lo que no toqué:** `gold_results__enriched`, que alimenta a `fct_driver_race`, es un `int`
  que lo lee un modelo de `core`, no dos `int` seguidos.
**Cosas que aprendí:** un modelo `ephemeral` es una forma de separar el código sin crear un
objeto, pero si solo lo lee otro modelo, separarlo en dos ficheros añade un nodo al linaje sin
ganar nada.
 
**Problemas encontrados y cómo los resolví:** ninguno.
 
**Pendiente / siguiente paso:** confirmar la comprobación de arriba; después, día 8 (groups y
access, grants para `REPORTING_ROLE`, exposure y contrato en `fct_driver_season`).
 
---
 
### 2026-11-23: día 7 (entornos DEV y PRO, jobs y camino a PRO)
**Qué hice:**
- **Entornos de despliegue `DEV` (General) y `PRO` (Production)** en dbt Platform, ambos leyendo
  la rama `main`, con credenciales de par de claves, `DEV_TRANSFORM_ROLE` y `PRO_TRANSFORM_ROLE`,
  el warehouse `WH_PROYECTO` y el schema `dbt_jobs`. Variables `DBT_BRONZE_DB`, `DBT_SILVER_DB` y
  `DBT_GOLD_DB` con valores `DEV_*` en DEV y `PRO_*` en PRO. Conexión probada en los
  dos entornos y versión de dbt igual en ambos.
- **Comprobé los permisos de `PRO_TRANSFORM_ROLE` en Snowflake:** uso de `PRO_BRONZE_DB` y de sus
  schemas, `select` en las tres tablas, creación de schemas en `PRO_SILVER_DB` y `PRO_GOLD_DB`
  y uso del warehouse. Recuentos de `PRO_BRONZE_DB` (calendario 1125, resultados 26759,
  clasificación 10494).
- **Job de PRO con `dbt build`**, creado con un compañero de clase. Target name `pro`,
  freshness desactivado, "generate docs" activado y aviso por correo si falla.
  El job de DEV y encadenamiento, si lo creo; resultado de la ejecución de PRO
  (`show schemas in database PRO_GOLD_DB` debe dar `CORE` e `INTERMEDIATE`) y ranking en PRO igual
  que en el IDE.
**Por qué lo hice así (y qué alternativa descarté):**
- **Dos entornos y no tres.** Es un proyecto en solitario, así que no hay PRE. Las bases `PRE_*`
  existen por el script 01, pero no se usan. DEV y PRO se separan por base de datos y por rol:
  el rol de DEV no puede escribir en PRO.
- **Un solo `dbt build` por job, con el snapshot dentro.** Había pensado un selector aparte para
  ejecutar el snapshot en otro job. Lo descarté porque `dbt build` ya incluye los snapshots y el
  DAG ejecuta primero la seed y después el snapshot, que depende de ella; si la seed no cambia, el
  snapshot no crea versiones nuevas. Un job aparte añadía complejidad sin motivo.
- **Sin freshness.** Bronze se cargó una vez y es estático, así que el paso de freshness del job
  no aporta nada. Es la misma decisión que ya constaba en la bitácora.
- **Sin cron.** No hay nada que recargar a diario. Si el job de PRO va detrás del de DEV, la
  promoción es por cadena: si DEV falla, PRO no se toca.
- **A PRO solo se llega por merge a `main` y jobs.** No ejecuto `dbt run` contra PRO desde el IDE:
  un job deja log, artefactos y quién lo lanzó, usa credenciales de servicio y lo que llega ha
  pasado por un pull request. En este proyecto, mi usuario hace de desarrollador y de usuario de
  los jobs porque es una cuenta de prueba; en un proyecto real serían usuarios de servicio.
- **No implementé la `run-operation` de permisos.** Los permisos con `grant select on all tables`
  se pierden cuando `table` recrea las tablas, así que habría que relanzarla después de cada
  build. El día 8 trae los grants declarativos, que se aplican solos.
- **Qué descarté del día 7:** PRE, el paso de freshness, la orquestación según el estado (la
  diapositiva dice que es solo para conocerla) y la demo de `dbt retry` con un permiso revocado.
**Cosas que aprendí:**
- El nombre del target de cada job decide qué rama de `generate_schema_name` se usa; con `default`
  los modelos de PRO acabarían como `DBT_JOBS_CORE` en lugar de `CORE`.
- Los entornos de despliegue leen `main`, no mi rama `DEV`: hasta que el pull request está
  fusionado, los jobs no ven mis cambios.
- Las variables de entorno por entorno solo se pueden rellenar cuando los entornos ya existen.
**Problemas encontrados y cómo los resolví:** ninguno.
 
**Pendiente / siguiente paso:** ejecutar el job de PRO con todo fusionado en `main` y comprobar
schemas, ranking y lectura con `REPORTING_ROLE`.
 
---
 
### 2026-11-23: día 6 (variables, generate_schema_name del curso, tags y selectors)
**Qué hice:**
- **Variables del score en `dbt_project.yml`:** `min_valid_races: 8`, `min_duels: 10` y
  `min_career_races: 100`, junto a `season_start` y `season_end`. Ahora `is_reliable_sample`
  de `fct_driver_season` usa `var('min_valid_races')` y `var('min_duels')`, y los dos
  `analyses` del ranking usan `var('min_career_races')`. Los dos unit tests de
  `fct_driver_season` fijan `min_valid_races` y `min_duels` con `overrides: vars:`.
- **`generate_schema_name` del curso**, que sustituye a la del día 4: con `target.name` en
  `dev` o `pro` (y fuera de CI) usa el schema tal cual (`CORE`); en el resto, el IDE incluido,
  usa `target.schema` + `_` + el schema (`DBT_ILUQUE_CORE`). El primer `dbt build` creó
  `DBT_ILUQUE_F1`, `_SEEDS`, `_SNAPSHOTS`, `_CORE` e `_INTERMEDIATE`; el build completo dio
  verde y el ranking quedó igual. Schemas antiguos `F1`, `SEEDS`, `SNAPSHOTS`,
  `CORE` e `INTERMEDIATE` borrados.
- **Tags por capa** en `dbt_project.yml` (`staging`, `silver`, `gold`, `intermediate` y
  `core`). Tags creados y resultado de `dbt ls --select tag:silver` (7 modelos) y
  `tag:core` (5).
- **No implementado:** el hook `on-run-end` con `log_run_summary`, los hooks de modelo, los
  secretos `DBT_ENV_SECRET_` y subir la config común de Silver a `dbt_project.yml`.
**Por qué lo hice así (y qué alternativa descarté):**
- **Umbrales como `var()` y bases de datos como `env_var()`.** Los umbrales son una decisión
  metodológica del proyecto y valen igual en todos los entornos, así que van en `vars`. Lo que
  cambia entre DEV y PRO (las bases de datos) sigue en `env_var`. Los valores no cambian: son
  los que ya usaba el score, ahora a la vista y sin repetirse en tres ficheros. Además puedo
  ejecutar `dbt build --select fct_driver_season --vars '{min_valid_races: 6, min_duels: 8}'`
  y ver si el top 5 se mueve, que es una prueba de sensibilidad para la defensa.
- **Los pesos del score (1/3 cada uno) no son variables.** Convertirlos cambiaría la fórmula
  y los unit tests, y "pesos iguales" se defiende mejor como decisión fija.
- **Unit tests con las variables fijadas.** Si alguien cambia `min_duels` en el proyecto, el
  piloto D del test (4 duelos) podría pasar a ser fiable y el test fallaría sin cambiar el
  código. Con `overrides` el test comprueba la fórmula, no la configuración.
- **Límite de las variables:** solo valen en modelos que se reconstruyen enteros, como Gold.
  En un incremental, cambiar la variable no reprocesaría las temporadas ya cargadas.
- **Por qué cambié la macro del día 4.** La versión del día 4 quitaba siempre el prefijo,
  incluso en el IDE. Con un solo desarrollador era suficiente, pero el IDE y el despliegue
  escribían en los mismos schemas de la misma base de datos. Con la del curso, el IDE usa
  schemas personales y los jobs con target `dev` y `pro` escriben en schemas limpios; además
  DEV y PRO siguen separados por base de datos. La decisión del día 4 sigue en esta bitácora
  con su fecha: la regla cambia, el registro de por qué se tomó se queda.
- **Cambios respecto a la macro del curso:** quité `pre` de la lista porque solo tengo `dev` y
  `pro`. Mantengo la comprobación de CI aunque no tengo jobs de CI: no estorba y evita que un
  CI futuro escriba en schemas compartidos.
- **No hice el hook `on-run-end`.** dbt ya imprime al final `PASS`, `WARN`, `ERROR` y `TOTAL`,
  y el resumen que se proponía repetía esos números. Solo habría aportado el nombre del
  entorno y la separación entre modelos y tests. Una alternativa que sí aportaba algo era
  listar los nombres de los nodos con warn, pero no es necesaria. Los hooks de modelo
  (`pre_hook` y `post_hook`) tampoco: ningún modelo depende de un parámetro de sesión, y un
  hook sin uso es difícil de defender.
- **Tags y selectors.** Los tags se heredan por carpeta y los voy a usar para elegir qué
  ejecuta cada job (`tag:silver`, `tag:core`). Un selector con nombre solo se justifica donde
  la selección no cabe en un tag: el job diario sin snapshots. Con dos jobs, `dbt build
  --exclude resource_type:snapshot` también habría bastado.
- **Qué no moví:** la config común de Silver (`materialized` y `on_schema_change`) sigue en
  cada modelo.
**Cosas que aprendí:**
- En el IDE, `target.name` es `default`, así que la rama de schemas limpios de la macro nunca
  se activa ahí. Para probarla sin jobs hay que cambiar temporalmente la lista de targets y
  usar solo `dbt ls`, nunca `build`. La rama de CI no se puede probar desde el IDE.
- El nombre del target de cada job, que se fija en dbt Platform, decide qué rama de la macro
  se usa: tiene que ser exactamente `dev` o `pro`.
- El comentario de cabecera de la macro estaba desactualizado (decía que nunca había prefijo).
  Lo cambié para describir los tres casos.
- Cambiar la macro cambió la ubicación del snapshot: `DBT_ILUQUE_SNAPSHOTS` empezó con una sola
  versión por estado. La historia de la prueba de `Retired` quedó en el schema antiguo, que era
  una demostración.
**Problemas encontrados y cómo los resolví:** el comentario de cabecera de la macro seguía
describiendo la versión anterior; lo corregí.
 
**Pendiente / siguiente paso:** pull request de DEV a `main`; día 7: entornos `dev` y `pro` y
jobs, con el target de cada job como `dev` o `pro` (así se comprueba en la práctica la rama
limpia de la macro) y un job aparte para `dbt snapshot`.
 
---
 
### 2026-11-23: día 5 (on_schema_change y snapshot de la clasificación de estados)
**Qué hice:**
- **`on_schema_change='fail'`** en la config de los 7 modelos incrementales de Silver
  (`slv_f1__circuits`, `constructors`, `drivers`, `races`, `results`, `qualifying` y
  `sprint_results`). No cambia ninguna columna, así que `dbt build --select silver+` pasa
  sin `--full-refresh`.
- **Snapshot `status_classification_snapshot`** sobre la seed `status_classification`
  (`snapshots/_snapshots.yml`): `unique_key: status`, `strategy: check`,
  `check_cols: [status_category]` y `hard_deletes: new_record`. En `dbt_project.yml`, el
  apartado `snapshots` lleva `+database: DBT_SILVER_DB`, `+schema: snapshots` y
  `+transient: false`; con `generate_schema_name`, el schema es `SNAPSHOTS` sin prefijo.
- **Prueba con historia real.** Ejecuté `dbt seed` y `dbt snapshot` con la seed original
  (versión 1 de cada estado), cambié `Retired` de `other_not_finished` a `mechanical`, volví
  a ejecutar `dbt seed` y `dbt snapshot` y comprobé que `Retired` tenía dos versiones: la
  antigua con `dbt_valid_to` y la nueva vigente. Para ver el efecto en el ranking reconstruí
  Silver con `dbt build --full-refresh --select slv_f1__results+ slv_f1__sprint_results+`.
  [Completar: efecto en el top 10 del ranking al pasar `Retired` a `mechanical`.]
  [Confirmar: seed devuelta a `other_not_finished` y ranking igual que antes de la prueba.]
**Por qué lo hice así (y qué alternativa descarté):**
- **`on_schema_change='fail'` en lugar del valor por defecto (`ignore`).** Con `ignore`, si
  añado o quito una columna del `select` de un modelo incremental, dbt no toca la tabla y
  no avisa: los datos quedarían incoherentes sin que se note. Con `fail` el modelo se para y
  me obliga a decidir con `--full-refresh`, que es lo que ya me pasó al cambiar a
  `generate_surrogate_key`. Descarté `append_new_columns` (el valor de la diapositiva): la
  columna nueva existiría solo en las temporadas reprocesadas y sería nula en el resto. La
  comparación es entre la tabla existente y el `select` del modelo, no con los datos de
  Bronze, así que salta cuando cambio yo el código; los datos nuevos con una columna de más
  no llegan a Silver (el `COPY INTO` de Bronze falla antes y staging lista las columnas una a
  una). Protege de mis propios cambios, más que de la fuente.
- **Snapshot de la seed y no de los datos de F1.** Los datos de carreras, pilotos y
  resultados son históricos y no cambian: un snapshot no guardaría ninguna historia. Lo que
  sí cambia por decisión mía es la clasificación de estados, y cada cambio mueve el score
  (por ejemplo, `Retired` son 76 filas, el 0,75 % de los resultados, y pasarlas a
  `mechanical` las saca de los duelos de C1 y de C3). El snapshot responde a "¿qué regla
  estaba vigente y desde cuándo?". Es una pieza de gobierno del dato, no un requisito del
  caso de uso: ningún modelo lee del snapshot, queda como tabla de auditoría.
- **`strategy: check` y no `timestamp`:** la seed no tiene una columna fiable de última
  modificación. Se compara `status_category`, lo único que puede cambiar.
- **`hard_deletes: new_record`:** si quito un estado de la seed, la versión se cierra y queda
  constancia del borrado, en lugar de seguir vigente.
- **`+transient: false`:** una tabla transient no tiene Fail-safe y la historia del snapshot
  no se puede reconstruir desde Bronze.
- **Objeción conocida:** el CSV de la seed ya está en Git, que guarda cada cambio con autor y
  fecha. El snapshot aporta que la historia se puede consultar con SQL junto a los datos y
  que registra cuándo se aplicó el cambio en el warehouse, no cuándo se hizo el commit. Es
  una justificación válida pero no una necesidad fuerte.
- **El lookback ya estaba.** El filtro `season_year >= (select max(season_year) from
  {{ this }})` reprocesa la última temporada cargada por si hay correcciones, y el `merge` actualiza en
  lugar de duplicar: es el lookback de la diapositiva, con la temporada como unidad en vez de
  una hora de `date_load`.
- **Por qué `merge` y no las otras estrategias:** `append` duplicaría la temporada que se
  relee; `delete+insert` también serviría, pero `merge` es la estrategia vista en clase y las
  claves son estables; `insert_overwrite` en Snowflake sobrescribe la tabla entera.
- **Qué descarté del día 5:**
  - Deduplicar el lote con `qualify row_number()`: en 2000-2024 el origen no repite filas, los
    tests `unique` de los `id_*` lo vigilan y Snowflake falla con un error si el `merge`
    encuentra claves duplicadas, así que no pasarían en silencio.
  - Microbatch: necesita una columna de fecha en el modelo y en su upstream, y los hechos de
    Silver solo tienen `season_year`; los z-scores se calculan por temporada, así que un lote
    por periodo interferiría; y reprocesar un periodo ya lo cubre el `>=`.
  - `full_refresh: false`: la demo del incremental y los cambios de clasificación necesitan
    `--full-refresh`.
  - El ejercicio de `append` frente a `delete+insert` (modelos temporales sin uso en el
    proyecto).
**Cosas que aprendí:**
- **Cambiar la seed no cambia Silver.** `status_category` se calcula en Silver, que es
  incremental y solo reprocesa la última temporada, así que las 24 anteriores conservan la
  categoría vieja hasta un `--full-refresh`. Con la seed cambiada y sin reconstruir, la seed y
  Silver dicen cosas distintas y el ranking sigue reflejando la regla anterior.
- **Un snapshot solo ve el estado en el momento en que se ejecuta.** Si cambio la seed y la
  devuelvo a su valor sin ejecutar `dbt snapshot` entre medias, el cambio intermedio no
  queda registrado. Cada ejecución que detecta una diferencia cierra la versión vigente y abre
  otra; no se borra nada, así que cambiar y revertir deja tres versiones.
**Problemas encontrados y cómo los resolví:** ninguno.
 
**Pendiente / siguiente paso:** pull request de DEV a `main`; más adelante, entornos y jobs
en PRO (con `dbt snapshot` en el job y la historia del snapshot de PRO empezando en su primera
ejecución). Opcional: `agg_driver_career`, `groups` y `access`, Power BI.
 
---
 
### 2026-11-23: día 4 (generate_schema_name, owner y macro z_score)
**Qué hice:** apliqué del día 4 lo que tiene sentido en este proyecto.
- **Macro `generate_schema_name`** (`macros/generate_schema_name.sql`), con la versión del curso:
  usa solo el schema indicado en `+schema`, sin el prefijo de la conexión. Antes del cambio,
  `show schemas in database DEV_SILVER_DB` mostraba `DBT_ILUQUE`, `DBT_ILUQUE_F1` y
  `DBT_ILUQUE_SEEDS`: las tablas estaban con prefijo, no en `f1` como decían las entradas
  anteriores. Después de `dbt build` aparecen `F1`, `SEEDS`, `CORE` e `INTERMEDIATE`, y el
  build pasa en verde. Borrados los schemas antiguos con prefijo.
- **`meta.owner` en `dbt_project.yml`**: `owner: "equipo-analitica-f1"` en la carpeta
  `gold/core`. Aparece en los metadatos de los modelos en `dbt docs`.
- **Macro `z_score`** (`macros/z_score.sql`), con `column_name` y dos parámetros con valor por
  defecto (`partition_by='season_year'` y `reliable_flag='is_reliable_sample'`). En
  `fct_driver_season`, los tres z-scores pasan de tres bloques copiados a
  `{{ z_score('c1_win_rate') }}`, `{{ z_score('c2_incident_rate') }}` y
  `{{ z_score('c3_positions_vs_car') }}`. Comprobé que el SQL compilado es el mismo (salvo
  espacios), que los dos unit tests pasan y que el ranking no cambia (Alonso 0,85, Max
  Verstappen 0,82, Hamilton 0,53 y Vettel 0,50).
**Por qué lo hice así (y qué alternativa descarté):**
- **`generate_schema_name` sin prefijo.** El comportamiento por defecto de dbt (`schema de la
  conexión` + `_` + `schema del modelo`) protege a un equipo que comparte una base de datos de
  desarrollo. Mi caso es otro: trabajo solo y los entornos ya se separan por base de datos
  (`DEV_*` y `PRO_*`, con variables de entorno). Sin la macro, producción habría heredado el
  prefijo del entorno de despliegue, que no controlo. Con ella, los schemas se llaman igual en
  DEV y en PRO. Coste asumido: los schemas antiguos con prefijo quedan como copias obsoletas y
  se borran a mano. Descarté dejar el comportamiento por defecto.
- **`owner` solo en Gold y solo en `core`**, como en el proyecto de clase, donde solo los
  modelos de Gold llevaban propietario. El propietario responde por los datos que consume el
  usuario final (dimensiones y hechos); `intermediate` son pasos de cálculo y staging y Silver
  son capas internas. El valor es un equipo y no una persona: es un rol, y si el proyecto
  cambiara de manos no habría que tocar nada. El nombre del equipo es una decisión mía.
- **Macro `z_score` porque el cálculo estaba escrito tres veces.** Es el criterio de las
  diapositivas: una macro merece la pena cuando la misma lógica se repite (principio DRY: si
  cambia la fórmula, se cambia en un solo sitio). El refactor era seguro porque los unit tests
  del día 3 comprueban la fórmula y el caso de desviación 0, y el SQL compilado no cambia. Los
  parámetros por defecto evitan repetir lo que es igual en las tres llamadas.
- **Qué descarté del día 4:**
  - Una macro para el filtro de temporadas de Silver (el mismo bloque con `between var(...)` e
    `is_incremental()` está en 7 modelos): es DRY real, pero toca 7 modelos que ya funcionan;
    queda como mejora.
  - Una macro para el filtro de estados (`not in ('mechanical', 'not_started')`): solo se usa
    3 veces y el SQL directo se lee mejor.
  - `dbt_utils.star`: ningún modelo selecciona "todas las columnas menos algunas".
  - `obtener_valores` y las columnas dinámicas: no pivoto datos, y `run_query` ya se usa en las
    macros de la demo del incremental.
  - Un test genérico `positive_values`: `dbt_utils.accepted_range` ya hace esa comprobación, y
    las propias diapositivas piden mirar primero si el paquete la tiene.
  - `groups`, `access` y contratos de modelo: quedan como mejora futura (por ejemplo, declarar
    `private` los modelos de `intermediate` para que solo `core` sea accesible desde fuera).
- **Gobierno del dato en el proyecto**, con los tres pilares de la diapositiva: calidad (data
  tests, tests singulares y unit tests), linaje (el DAG de dbt, de Bronze a `core`) y catálogo
  (descripciones, docs blocks y `meta.owner` en la documentación generada).
**Problemas encontrados y cómo los resolví:**
- Las entradas anteriores decían que las vistas de staging estaban en el schema `f1`. Era
  inexacto: dbt las creaba en `DBT_ILUQUE_F1`. Lo detecté con `show schemas` antes de aplicar
  la macro y lo dejo anotado aquí; las entradas antiguas no se reescriben.
**Pendiente / siguiente paso:** pull request de DEV a `main`; más adelante, entornos y jobs
(PRO). Opcional: macro para el filtro de temporadas de Silver, `agg_driver_career`, `groups` y
`access`, Power BI.
 
---
 
### 2026-11-22: contraste entre el ranking en bruto y el ajustado
**Qué hice:** creé `analyses/ranking_bruto_vs_ajustado.sql`, que compara, para los mismos
pilotos que `ranking.sql` (score en temporadas fiables y mínimo de 100 carreras: 33 pilotos), el
puesto según las victorias y el puesto según el score. Lee solo de `dim_driver` y
`fct_driver_season`; no hay modelos nuevos. Devuelve victorias, podios, porcentaje de
victorias, score, `puesto_bruto`, `puesto_ajustado` y `diferencia` (puesto bruto menos puesto
ajustado: positivo si el ajuste lo sube).
 
**Por qué lo hice así (y qué alternativa descarté):**
- **Es el contrapunto del caso de uso.** La pregunta es quién es el mejor piloto
  independientemente del coche; para justificar el método hay que enseñar qué saldría sin él.
- **El "bruto" son las victorias** (con los podios como desempate), con `rank()`: los
  empatados comparten puesto. Descarté los puntos porque el sistema de puntuación cambió en
  2000-2024 y no son comparables entre años.
- **Mismos pilotos en los dos rankings**, para que la diferencia de puestos tenga sentido. Las
  victorias y carreras de `dim_driver` cuentan todas las temporadas, también las no fiables:
  es lo que vería cualquiera sin el método.
**Resultado (33 pilotos):** la correlación entre los dos órdenes es de 0,58: el coche explica
una parte importante del ranking en bruto, pero no todo. Solo 6 de los 10 primeros del ranking
ajustado están entre los 10 primeros en bruto, y 11 pilotos se mueven 10 puestos o más.
- **El top 4 apenas cambia:** Alonso 5.º → 1.º, Max Verstappen 2.º → 2.º, Hamilton 1.º → 3.º y
  Vettel 4.º → 4.º.
- **Suben los de pocas victorias:** Gasly (+18, de 23.º a 5.º), Heidfeld (+15), Russell (+14),
  Hülkenberg (+14), Albon (+13) y Norris (+12).
- **Bajan los de coche de equipo grande, casi todos con un campeón de compañero:** Massa (-17),
  Coulthard (-13), Ralf Schumacher (-13), Barrichello (-12), Michael Schumacher (-10) y Pérez
  (-9).
**Limitaciones a tener presentes en la defensa:**
- **Los puestos bajos del bruto son poco informativos:** muchos pilotos tienen 0 victorias y se
  desempatan por podios, así que parte del salto de Hülkenberg o Heidfeld es el orden del
  desempate. Se interpreta la dirección y el tamaño del cambio, no el puesto exacto.
- **C1 no pondera la calidad del compañero y C3 tiene techo en los coches de arriba:** empuja
  hacia abajo a quienes compartieron equipo con un campeón (Barrichello, Massa). Es la
  limitación documentada del día 22.
- **Gasly** depende de tres temporadas con AlphaTauri (muestra pequeña) y **Schumacher** sale
  13.º por la ventana 2000-2024 y el techo del coche.
- El score mide rendimiento relativo a su coche y su compañero, no el mejor piloto de la
  historia.
**Pendiente / siguiente paso:** decidir cómo presentarlo en la defensa (qué tabla enseñar y
cuántos pilotos) y, si da tiempo, `agg_driver_career` para tener el ranking como tabla.
 
---
 
### 2026-11-22: día 3 (dbt_utils, tests, unit tests y docs blocks)
**Qué hice:** seguí las diapositivas del día 3 sobre el proyecto.
- **Paquete `dbt_utils`.** Creé `packages.yml` (`dbt-labs/dbt_utils`, versión `>=1.3.0,<2.0.0`),
  ejecuté `dbt deps` y subí `package-lock.yml`; `dbt_packages/` queda fuera de git.
- **Claves con `generate_surrogate_key`.** Sustituí `md5(concat_ws('|', ...))` en los 9
  modelos que generan claves (los 7 de Silver, `fct_driver_season` y `fct_driver_race`) y
  reconstruí con `--full-refresh`, porque las claves cambian de valor en todo el proyecto.
  `dbt build` pasa.
- **Tests de datos (unas 205 comprobaciones):** Silver 71, staging 23, Gold 111 (core 67 e
  intermediate 44). `dbt build --select staging` y `dbt build --select gold` pasan.
  Los tests de Silver pasan en el `dbt build` completo.
- **Tests singulares** en `tests/singular/` (`dbt test --select test_type:singular` pasa):
  `assert_cobertura_temporadas` (hay las 25 temporadas), `assert_cobertura_carreras` (cada
  temporada tiene exactamente las carreras del calendario oficial, 479 en total),
  `assert_numero_duelos_C1` (las victorias de C1 suman la mitad de los duelos en cada
  temporada) y `assert_tiempos_no_perdidos` (ningún tiempo de clasificación existente se pierde
  al pasarlo a milisegundos; `warn_if='>0'`, `error_if='>20'`).
- **Dos unit tests** sobre `fct_driver_season`, dentro de `_core__models.yml`
  (`dbt test --select test_type:unit` pasa): uno comprueba la fórmula del score, los z-scores y
  el score nulo en la muestra no fiable; el otro, que con desviación 0 los z-scores y el score
  quedan nulos sin error de división.
- **Docs blocks.** Creé `docs/f1/_f1__docs.md` con seis bloques (`season_year`, `round`,
  `grid`, `laps`, `race_time_ms` y `status_category`) y los usé con `doc()` en 43 columnas;
  añadí `docs-paths: ["docs"]` a `dbt_project.yml`. `dbt parse`, `dbt build` y
  `dbt docs generate` pasan tras este cambio.
- Unifiqué los nombres de los `.yml`: `_staging_f1__models.yml`, `_silver_f1__models.yml`,
  `_intermediate__models.yml` y `_core__models.yml`.
**Por qué lo hice así (y qué alternativa descarté):**
- **`generate_surrogate_key` en lugar de `md5` a mano.** Es la función del paquete que vimos
  en clase: hace el hash, pone un separador entre columnas y trata los nulos, y se escribe
  igual en todos los modelos. El `md5` manual hacía lo mismo, pero con más código repetido y
  sin tratamiento de nulos. Detalle que conozco: con una sola columna, un nulo y un texto
  vacío darían la misma clave; las columnas de origen llevan `not_null`, que lo cubre. La
  decisión de la entrada de Silver sobre `md5` queda sustituida por esta.
- **Staging: solo `not_null` en las claves y las medidas principales.** Staging es 1:1 con
  Bronze y conserva 1950-2024, así que no hay `unique` en `stg_f1__resultados` (antes de 1979
  hay combinaciones repetidas por coches compartidos). Solo `calendario` y `clasificacion`
  llevan `unique_combination_of_columns`, comprobado con los datos.
- **`relationships` de `status` contra la seed, ya en staging.** Es la red de seguridad del
  `left join` de Silver: un estado nuevo o mal escrito falla aquí, antes de dejar la categoría
  vacía.
- **Silver: `unique` y `not_null` en los `id_*`, `relationships` entre hechos y entidades,
  `accepted_values` en `status_category` y `accepted_range` de `season_year` con las `vars`.**
  Los rangos salen de `season_start` y `season_end`, no de años escritos a mano.
- **Gold: `relationships` de los hechos con las tres dimensiones y rangos 0-1 en las tasas.** Es
  lo que garantiza que el modelo en estrella está bien unido. No hay tests sobre
  `int_f1__teammate_duels` porque es `ephemeral` y dbt no lo permite; lo cubre el test
  singular de C1. `n_duels` y `c1_win_rate` de `fct_driver_season` no llevan `not_null`:
  pueden ser nulos a propósito.
- **Test singular de carreras con los números exactos, agrupados con `when ... in (...)`.**
  Detecta que falte una sola carrera, no solo una carga muy incompleta. Descarté el umbral
  "menos de 10 carreras": no avisaba de 21 en lugar de 22. Los valores salen del calendario
  de los CSV y suman 479. Coste asumido: están escritos en el test, y si amplío el periodo
  hay que añadir la temporada; la última línea del test hace que falle si falta, para no
  pasar sin comprobarla. Lo agrupé por número de carreras (8 líneas) y no año por año (25
  valores): se ve el patrón de un vistazo. Es un test independiente del de las 25
  temporadas, porque una temporada que falta no aparece en el `group by`.
- **Test de cobertura de temporadas sin `generator`.** La versión con `generator`,
  `row_number` y `left join` era correcta pero difícil de leer; la sustituí por un `count
  (distinct ...)` contra `season_end - season_start + 1`.
- **Severidad: `error` por defecto, `warn` solo para los tiempos.** El número de carreras de
  una temporada es un hecho cerrado: si no coincide, el score está mal. Los tiempos son un
  aviso de calidad: un tiempo perdido quita un duelo de unos 4.400 de clasificación.
  Cuidado con el argumento: **sí uso los tiempos** (los duelos de clasificación exigen Q1), así
  que no es que no importen, sino que el impacto de uno es mínimo. Umbral `error_if='>20'`:
  unas 9.000 filas de clasificación en 2000-2024, así que 20 son aproximadamente el 0,2 %; es
  un umbral elegido por mí, sin cálculo detrás. Con `try_cast` el dato malo no rompe la
  carga, y el test impide que se pierda sin que nadie lo sepa.
- **Unit tests con 0,75 y 0,25 en C1 y 0 y 0,5 en C2.** Son números que el ordenador
  representa sin redondeo, así que los z-scores salen exactos (+1 y -1) y se pueden calcular
  a mano. Cada test responde a una pregunta: el primero incluye un piloto no fiable (D) para
  comprobar que no altera la media y la desviación de la temporada; el segundo comprueba el
  `nullif` de la desviación 0. Complementan a los tests de datos: estos dicen que los datos
  son válidos, y el unit test que la fórmula está bien aplicada.
- **Docs blocks solo donde el texto estaba idéntico en varias capas.** Una columna escrita en
  15 sitios es un riesgo de que se desincronice. `status_category` lleva una tabla con las
  cinco categorías y su efecto en el score, como el `order_status` del curso. No usé bloques
  para los `id_*`: en su modelo son la clave y en los hechos una referencia, y un único texto
  borraría esa diferencia. Descarté documentar todas las columnas con bloques por exceso de
  ficheros para el beneficio.
- **Los `.yml` con tests siguen siendo uno por carpeta**, con nombre `_<capa>_f1__models.yml`
  en staging y Silver, y `_<carpeta>__models.yml` en Gold, que no tiene un origen único.
**Problemas encontrados y cómo los resolví:**
- Las descripciones aparecían unas con comillas y otras sin ellas tras regenerar los `.yml`.
  Decidí poner todas entre comillas dobles y lo regeneré con ese formato.
- Tras el cambio de claves, las descripciones seguían diciendo "md5"; las cambié por "clave
  sustituta de".
- Una primera justificación del test de tiempos ("no uso los tiempos") era incorrecta: C1 los
  necesita. La reescribí con el argumento del impacto.
**Pendiente / siguiente paso:** pull request de DEV a `main`, despliegue y job en PRO;
contraste entre el ranking en bruto y el ajustado por coche; modelos físicos de cada capa
(para la defensa); y subir `04_demo_incremental.sql` y los CSV de prueba a `/ingesta`.
Opcional: `agg_driver_career` y Power BI.
 
---
 
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
| Claves con `dbt_utils.generate_surrogate_key` (sustituye a la decisión del `md5`) | `md5(concat_ws('\|', ...))` a mano | Función del paquete vista en clase: mismo hash en todos los modelos y con tratamiento de nulos. Con una sola columna un nulo y un texto vacío darían la misma clave; `not_null` en el origen lo cubre. Reconstruido con `--full-refresh` |
| Staging solo con `not_null`, `unique` en calendario y clasificación, y `relationships` de `status` con la seed | `unique` en `resultados`; sin tests | Antes de 1979 `resultados` repite (temporada, ronda, piloto); el `relationships` es la red de seguridad del `left join` de Silver |
| Tests de Silver y Gold: unicidad, `relationships`, valores permitidos y rangos con `vars` | Años escritos a mano en los tests | Garantizan el modelo en estrella y se ajustan al cambiar el periodo. Sin tests sobre el `ephemeral` de duelos (no se puede) |
| Test singular de carreras por temporada con valores exactos agrupados | Umbral de mínimo de carreras; un valor por año | Detecta que falte una sola carrera; agrupado por número se ve el patrón. Coste: valores escritos en el test |
| Test singular de las 25 temporadas con `count(distinct)` | `generator` y `left join` | Misma comprobación, más fácil de leer; una temporada ausente no aparece en un `group by` de carreras |
| Test de tiempos con `warn_if='>0'` y `error_if='>20'` | Siempre `error`; siempre `warn` | `try_cast` evita que un dato malo rompa la carga y el test avisa; unas 20 filas son el 0,2 % de la clasificación; umbral elegido por mí. Los tiempos sí se usan en C1 |
| Severidad `error` por defecto en el resto de tests | `warn` generalizado | Un resultado histórico que no cuadra invalida el score |
| Dos unit tests sobre `fct_driver_season` con números exactos | Solo tests de datos | La fórmula del score es el núcleo del caso de uso; los tests de datos no detectan un signo mal puesto |
| Docs blocks para seis columnas repetidas y `docs-paths: ["docs"]` | Descripción copiada en cada capa; bloques para todas las columnas | Se escribe una vez y se reutiliza; no se usan en los `id_*` porque su significado cambia entre modelos |
| Macro `generate_schema_name` sin prefijo | Comportamiento por defecto (`schema de la conexión` + `_` + `schema del modelo`) | El prefijo protege a quien comparte base de datos de desarrollo; aquí los entornos ya se separan por base de datos y en PRO el prefijo vendría del entorno de despliegue. Coste: borrar a mano los schemas antiguos |
| `meta.owner` solo en `gold/core`, con un equipo como valor | Owner en todas las capas; una persona como owner | Como en el proyecto de clase, solo los modelos que consume el usuario final tienen propietario; un rol no cambia si cambia quien lo ejerce |
| Macro `z_score` con parámetros por defecto | Tres bloques copiados en `fct_driver_season` | Mismo cálculo tres veces: DRY. Refactor seguro porque los unit tests comprueban la fórmula y el SQL compilado no cambia |
| No hacer macro del filtro de temporadas de Silver ni del filtro de estados | Una macro para cada uno | La de Silver toca 7 modelos que ya funcionan; la de estados se usa 3 veces y el SQL directo se lee mejor. Quedan como mejora |
| Sin `dbt_utils.star`, sin `obtener_valores` y sin test genérico `positive_values` | Aplicar todos los ejercicios del día 4 | No hay caso real en el proyecto; `accepted_range` ya cubre `positive_values` y `run_query` ya está en las macros de la demo |
| `groups`, `access` y contratos fuera del alcance | Declarar `intermediate` como `private` y `core` como `public` | Mejora de gobierno sin impacto en el resultado; se cita como trabajo futuro |
| Ranking en bruto = victorias (desempate por podios) frente al ajustado | Puntos; puestos del campeonato | Los puntos no son comparables entre 2000 y 2024 por los cambios de sistema; las victorias son lo más intuitivo |
| `on_schema_change='fail'` en los 7 modelos incrementales de Silver | `ignore` (defecto); `append_new_columns` | Con `ignore` una columna nueva no se crea y no avisa; con `append_new_columns` quedaría nula en las temporadas no reprocesadas. `fail` me obliga a decidir con `--full-refresh` |
| Lookback por temporada (`>=` sobre la última temporada cargada) con `merge` | Lookback de una hora sobre `date_load`; `append`; `delete+insert` | La carga es estática y la unidad natural del dato es la temporada; `append` duplicaría lo que se relee y `merge` es la estrategia vista en clase |
| Sin deduplicar el lote en los hechos de Silver | `qualify row_number()` en `results`, `qualifying` y `sprint_results` | El origen es único en 2000-2024, los `unique` lo vigilan y Snowflake falla si el `merge` encuentra claves duplicadas |
| Sin microbatch ni `full_refresh: false` | Microbatch por año; proteger los incrementales | Los hechos no tienen columna de fecha y los z-scores se calculan por temporada; la demo y los cambios de clasificación necesitan `--full-refresh` |
| Snapshot de la seed `status_classification` con `check` sobre `status_category` | Snapshot de pilotos o resultados; estrategia `timestamp`; no hacer snapshot | Los datos de F1 no cambian; la clasificación es la única regla mía que cambia y mueve el score; la seed no tiene columna de última modificación. Ningún modelo lo lee: es una tabla de auditoría |
| Snapshot con `hard_deletes: new_record` y `+transient: false` | `ignore` (defecto); tabla transient | Un estado borrado de la seed queda registrado; la historia no se puede reconstruir desde Bronze y necesita Fail-safe |
| Umbrales del score (`min_valid_races`, `min_duels`, `min_career_races`) como `var()` | Escribirlos en el SQL; también convertir los pesos en variables | Decisión metodológica común a todos los entornos; permite probar la sensibilidad del ranking con `--vars`. Los pesos se quedan fijos |
| Unit tests de `fct_driver_season` con `overrides: vars:` | Dejar que lean el valor del proyecto | Comprueban la fórmula, no la configuración |
| `generate_schema_name` del curso (schema limpio con target `dev` o `pro`, prefijo en el IDE) | Mantener la del día 4 (nunca prefijo) | Separa el desarrollo en el IDE del despliegue en los jobs; conserva la separación DEV/PRO por base de datos. Sin `pre`; con la rama de CI aunque no haya jobs de CI |
| Sin `on-run-end` ni hooks de modelo | `log_run_summary`; `pre_hook` y `post_hook` | dbt ya imprime PASS/WARN/ERROR; ningún modelo depende de un parámetro de sesión |
| Tags por capa y dominio, y selector solo para el job diario sin snapshots | Selectors para cada capa; no usar selectors | Los tags cubren la selección de los jobs; el selector se justifica solo donde un tag no basta |
| Duelos de compañeros dentro de `int_f1__driver_season_c1` (un solo modelo) | Dos modelos con duelos `ephemeral` (decisión del 21 de noviembre); duelos como modelo propio | Solo se usa en un sitio; el SQL compilado es el mismo; quita un nodo del linaje y el `int` que lee de otro `int`. Si otro criterio necesita los duelos, se vuelve a separar |
| Entornos DEV y PRO, sin PRE ni freshness ni cron; PRO por job y merge a `main` | Tres entornos; paso de freshness; ejecutar en PRO desde el IDE | Proyecto en solitario con Bronze estático; trazabilidad, credenciales de servicio y revisión |
| Un solo `dbt build` por job, con el snapshot dentro | Selector aparte y job de snapshot | `build` ya incluye el snapshot y el DAG ordena seed → snapshot |
| Grants declarativos con `+grants` a `REPORTING_ROLE` en `core` | `run-operation` `grant_select_on_gold` | Se aplican solos en cada build; los grants de `all tables` se pierden al recrear la tabla |
| Un grupo `analitica_f1`, `int` private y `core` public | Sin grupos; un grupo por modelo | Un solo equipo; deja escrita la intención de qué se consume |
| Exposure de tipo `analysis` | Exposure `dashboard`; sin exposure | No hay Power BI; el linaje no debe mostrar un dashboard que no existe |
| Contrato solo en `fct_driver_season` | Contrato en todos los modelos de `core`; sin contratos | Es el mart que consume el ranking; el resto no compensa por trabajo y riesgo |
| Sin versiones de modelo | `latest_version` con `deprecation_date` | Sin consumidores que migren; un solo propietario |
| Todo Gold incremental (9 modelos), misma estrategia que Silver (`merge`, `>=`, `fail`) | Gold en full refresh; solo los hechos de carrera | El ahorro se pierde en el eslabón más débil; con 2025 y 2026 solo se procesa lo nuevo; una sola estrategia que defender |
| Dimensiones incrementales por claves afectadas (con todo su historial) | Filtrar solo por temporada; full refresh | Son totales de toda la carrera: filtrar por temporada daría totales incorrectos |
| C3 lee todo el histórico y escribe solo la última temporada, con `--full-refresh` periódico | Filtrar también la entrada; dejar C3 en full refresh | La media del puesto esperado necesita todas las temporadas; la limitación (C3 de temporadas antiguas desfasado hasta el full refresh) es pequeña y está documentada |
| Demo con `--vars '{season_end: 2025}'` y limpieza con `--full-refresh` de Silver y Gold | Subir `season_end` en el proyecto; borrar filas a mano | `season_end` es una decisión metodológica (2000-2024); la limpieza se reproduce con un solo comando |
 
 
## Errores y soluciones (rellenar según aparezcan)
 
| Fecha | Error | Causa | Solución |
| --- | --- | --- | --- |
| 2026-11-25 | `ver_2025` devuelve 0 filas de 2025 en Silver y Gold | `season_end` es 2024 y Silver filtra `between season_start and season_end`: los datos de prueba no entran | Ejecutar `dbt run --select silver gold --vars '{season_end: 2025}'` en la demo; la limpieza, sin `--vars` |
 