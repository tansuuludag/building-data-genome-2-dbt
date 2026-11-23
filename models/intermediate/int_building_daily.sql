{{
    config(
        materialized = 'table',
        partition_by = {'field': 'date', 'data_type': 'date', 'granularity': 'month'},
        cluster_by = ['building_id']
    )
}}

with daily_kwh as (

    -- Saatlik temiz elektrik → günlük; en az 20 saati dolu günler
    select
        building_id,
        date(timestamp)          as day_date,
        sum(kwh)                 as kwh_total,
        count(kwh)               as kwh_hours
    from {{ ref('int_electricity_cleaned') }}
    group by building_id, day_date
    having kwh_hours >= 20

),

buildings as (

    select
        m.building_id,
        m.site_id,
        m.primary_use,
        m.sqm,
        m.is_parking,
        l.country,
        l.state,
        -- Fiyat bölgesi: Kanada CA-ON (California 'CA' ile çakışmasın),
        -- diğer yabancılar ülke, ABD'de eyalet, yoksa saat dilimine göre bölge
        case
            when l.country = 'CA'            then concat('CA-', l.state)
            when l.country != 'US'           then l.country
            when l.state is not null         then l.state
            when m.timezone = 'US/Pacific'   then 'US-PAC'
            when m.timezone = 'US/Mountain'  then 'US-MTN'
            else 'US'
        end                                  as price_region
    from {{ ref('stg_metadata') }}     as m
    join {{ ref('site_locations') }}   as l
      on l.site_id = m.site_id

)

select
    dk.building_id,
    dk.day_date                                            as date,
    extract(year from dk.day_date)                         as year,
    mod(extract(dayofweek from dk.day_date) + 5, 7)        as dow,         -- 0 = Pazartesi
    mod(extract(dayofweek from dk.day_date) + 5, 7) >= 5   as is_weekend,
    hol.holiday_date is not null                           as is_holiday,

    bld.site_id,
    bld.primary_use,
    bld.sqm,
    bld.is_parking,
    bld.country,
    bld.price_region,

    dk.kwh_total                                           as kwh,
    dk.kwh_hours,
    dk.kwh_total / bld.sqm                                 as kwh_per_sqm,

    wd.t_mean,
    wd.t_max,
    wd.t_min,
    wd.dew_mean,
    wd.hdd,
    wd.cdd,

    pr.price_usd_per_kwh,
    dk.kwh_total * pr.price_usd_per_kwh                    as cost_usd

from daily_kwh as dk
join buildings as bld
  on bld.building_id = dk.building_id
left join {{ ref('int_weather_daily') }} as wd
  on wd.site_id = bld.site_id and wd.date = dk.day_date
left join {{ ref('holidays') }} as hol
  on hol.country = bld.country and hol.holiday_date = dk.day_date
left join {{ ref('electricity_prices') }} as pr
  on pr.region = bld.price_region and pr.year = extract(year from dk.day_date)