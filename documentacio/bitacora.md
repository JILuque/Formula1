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

### 2026-11-09: forma de cargar los CSV en Snowflake
**Qué hice:** valoré subir los CSV a un repositorio de GitHub y cargarlos desde ahí.
**Por qué lo hice así (y qué alternativa descarté):** descarto cargar desde GitHub porque `COPY INTO` lee de stages internos o de almacenamiento en la nube, y usar un repositorio añadiría una integración con permisos de administrador sin ninguna ventaja. Los datos son una descarga estática de Kaggle, así que la carga manual a un stage interno es suficiente y se justifica como carga puntual. Los CSV se guardarán también en el repositorio del proyecto solo para que sea reproducible.
**Problemas encontrados y cómo los resolví:** ninguno.
**Pendiente / siguiente paso:** ejecutar el script de carga en Snowflake y comprobar los recuentos.

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

## Errores y soluciones (rellenar según aparezcan)

| Fecha | Error | Causa | Solución |
| --- | --- | --- | --- |
