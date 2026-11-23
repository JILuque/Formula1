----------------------------------------------------------------------------
-- Usa solo el schema indicado en +schema (sin el prefijo de la conexión).
-- Los entornos ya se separan por base de datos (DEV_/PRO_), no por schema.
----------------------------------------------------------------------------

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}