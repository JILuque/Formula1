----------------------------------------------------------------------------
-- IDE (target default): prefijo personal -> dbt_<usuario>_<schema>
-- Jobs con target dev o pro: el schema tal cual (CORE, F1...)
-- Jobs de CI: siempre con prefijo. Los entornos se separan además por
-- base de datos (DEV_/PRO_) con env_var.
----------------------------------------------------------------------------

{% macro generate_schema_name(custom_schema_name, node) -%}
{%- set default_schema = target.schema -%}
{%- set invocation_context = env_var('DBT_CLOUD_INVOCATION_CONTEXT', '') -%}
{%- if custom_schema_name is none -%}
{{ default_schema }}
{%- elif invocation_context != 'ci'
and target.name in ['dev', 'pro'] -%}
{{ custom_schema_name | trim }}
{%- else -%}
{{ default_schema }}_{{ custom_schema_name | trim }}
{%- endif -%}
{%- endmacro %}