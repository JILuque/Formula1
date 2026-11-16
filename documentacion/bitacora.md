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
bronze. [confirmar que cuadraron todos]

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

## Errores y soluciones (rellenar según aparezcan)

| Fecha | Error | Causa | Solución |
| --- | --- | --- | --- |
