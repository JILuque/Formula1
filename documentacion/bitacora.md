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
pasa. [Pendiente: `_f1__models.yml` con descripciones y tests, que va con el
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
| Mínimo de 36 carreras con columna de marca | Sin filtro; 5 o 24 carreras | Evita que una sola temporada brillante entre en el top |
| Carga manual a stage interno | Cargar desde GitHub | Datos estáticos; sin integraciones innecesarias |
| Periodo 2000-2024 | Otro rango | Justificación por redactar |
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
| (Por confirmar) C1 cuenta duelos de carrera, clasificación y sprint juntos | Solo carrera; pesos por sesión | Cada duelo vale 1 y el peso de cada sesión sale de su frecuencia, sin inventar pesos |


## Errores y soluciones (rellenar según aparezcan)

| Fecha | Error | Causa | Solución |
| --- | --- | --- | --- |
