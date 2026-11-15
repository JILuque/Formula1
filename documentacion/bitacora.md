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

## Errores y soluciones (rellenar según aparezcan)

| Fecha | Error | Causa | Solución |
| --- | --- | --- | --- |
