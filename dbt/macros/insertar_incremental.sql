{% macro insertar_incremental() %}
    
    {% set bd = env_var('DBT_BRONZE_DB') %}

    {# 0. Si ya hay datos de prueba, parar antes de cargar #}
    {% set previos = run_query(
        "select (select count(*) from " ~ bd ~ ".f1.calendario where season_year = 2025)"
        ~ " + (select count(*) from " ~ bd ~ ".f1.resultados where season_year = 2025)"
    ).rows[0][0] %}
    {% if previos > 0 %}
        {{ exceptions.raise_compiler_error("Ya hay " ~ previos ~ " registros de prueba en Bronze: ejecuta limpiar_incremental antes de cargar") }}
    {% endif %}

    {# 1. Lanza la task #}
    {% do run_query("execute task " ~ bd ~ ".public.task_demo_cargar") %}

    {# 2. Espera 10 segundos a que termine el COPY INTO #}
    {% do run_query("call system$wait(10)") %}

    {# 3. Cuenta los registros de 2025 en Bronze #}
    {% set n = run_query(
        "select (select count(*) from " ~ bd ~ ".f1.calendario where season_year = 2025)"
        ~ " + (select count(*) from " ~ bd ~ ".f1.resultados where season_year = 2025)"
    ).rows[0][0] %}

    {# 4. Comprueba que son 3 #}
    {% if n == 3 %}
        {{ log("OK: se han cargado 3 registros de prueba en Bronze", info=True) }}
    {% else %}
        {{ exceptions.raise_compiler_error("Esperaba 3 registros de 2025 en Bronze y hay " ~ n) }}
    {% endif %}
{% endmacro %}


{% macro ver_2025() %}
    {% set q %}
        select 'races' as modelo, id_race as clave, race_name as detalle
        from {{ ref('slv_f1__races') }} where season_year = 2025
        union all
        select 'circuits', id_circuit, circuit_name
        from {{ ref('slv_f1__circuits') }} where circuit_ref = 'test_circuit'
        union all
        select 'drivers', id_driver, driver_full_name
        from {{ ref('slv_f1__drivers') }} where driver_ref like 'test_driver%'
        union all
        select 'constructors', id_constructor, constructor_name
        from {{ ref('slv_f1__constructors') }} where constructor_ref = 'test_constructor'
        union all
        select 'results', id_result, status
        from {{ ref('slv_f1__results') }} where season_year = 2025
    {% endset %}

    {% set r = run_query(q) %}

    {% for fila in r.rows %}
        {{ log(fila[0] ~ ' | ' ~ fila[2] ~ ' | ' ~ fila[1], info=True) }}
    {% endfor %}

    {{ log('Filas de 2025 en Silver: ' ~ (r.rows | length) ~ ' (esperado: 7)', info=True) }}
{% endmacro %}