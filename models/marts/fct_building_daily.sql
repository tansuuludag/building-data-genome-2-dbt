{{
    config(
        partition_by = {'field': 'date', 'data_type': 'date', 'granularity': 'month'},
        cluster_by = ['building_id']
    )
}}

-- Bina x gün olgu tablosu: anahtarlar + günlük ölçümler.
-- Bina özellikleri dim_building'de; building_id ile bağlanır.
select
    building_id,
    date,
    year,
    dow,
    is_weekend,
    is_holiday,

    kwh,
    kwh_hours,
    kwh_per_sqm,

    t_mean,
    t_max,
    t_min,
    dew_mean,
    hdd,
    cdd,

    price_usd_per_kwh,
    cost_usd
from {{ ref('int_building_daily') }}