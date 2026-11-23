{{
    config(
        materialized = 'table',
        partition_by = {
            'field': 'timestamp',
            'data_type': 'timestamp',
            'granularity': 'month'
        },
        cluster_by = ['building_id']
    )
}}

-- Kaynak tablo ve bina sütunlarının listesi (timestamp hariç)
{% set source_relation = source('bdg2_raw', 'electricity_raw') %}

{% if execute %}
    {% set all_columns = adapter.get_columns_in_relation(source_relation) %}
    {% set building_columns = all_columns
        | map(attribute='name')
        | reject('equalto', 'timestamp')
        | list %}
{% else %}
    {% set building_columns = [] %}
{% endif %}

-- Geniş tablo (1 sütun = 1 bina) → uzun tablo (1 satır = 1 bina x 1 saat)
select
    timestamp,
    building_id,
    kwh
from {{ source_relation }}
unpivot include nulls (
    kwh for building_id in (
        {%- for col in building_columns %}
        `{{ col }}`{{ "," if not loop.last }}
        {%- endfor %}
    )
)