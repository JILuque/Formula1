{% macro limpiar_incremental() %}
    {% set bd = env_var('DBT_BRONZE_DB') %}

    {# 1. Lanza la task de limpieza #}
    {% do run_query("execute task " ~ bd ~ ".public.task_demo_limpiar") %}

    {# 2. Espera 10 segundos a que termine #}
    {% do run_query("call system$wait(10)") %}

    {# 3. Cuenta los registros de 2025 que quedan en Bronze #}
    {% set n = run_query(
        "select (select count(*) from " ~ bd ~ ".f1.calendario where season_year = 2025)"
        ~ " + (select count(*) from " ~ bd ~ ".f1.resultados where season_year = 2025)"
    ).rows[0][0] %}

    {# 4. Comprueba que no queda ninguno #}
    {% if n == 0 %}
        {{ log("OK: Bronze limpio, no quedan registros de prueba", info=True) }}
    {% else %}
        {{ exceptions.raise_compiler_error("Esperaba 0 registros de 2025 en Bronze y quedan " ~ n) }}
    {% endif %}
{% endmacro %}