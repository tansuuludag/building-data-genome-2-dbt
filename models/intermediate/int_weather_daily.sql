-- Saatlik hava → günlük (saha x gün)
select
    site_id,
    date(timestamp)                                   as date,
    avg(air_temp_c)                                   as t_mean,
    max(air_temp_c)                                   as t_max,
    min(air_temp_c)                                   as t_min,
    avg(dew_temp_c)                                   as dew_mean,
    greatest(18 - avg(air_temp_c), 0)                 as hdd,   -- ısıtma derece-gün
    greatest(avg(air_temp_c) - 18, 0)                 as cdd,   -- soğutma derece-gün
    count(air_temp_c)                                 as temp_hours
from {{ ref('stg_weather') }}
group by site_id, date(timestamp)