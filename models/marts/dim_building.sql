with coverage as (

    -- Her binanın veri kapsamı ve 2016 enerji yoğunluğu
    select
        building_id,
        any_value(price_region)                                  as price_region,
        min(date)                                                as first_date,
        max(date)                                                as last_date,
        countif(year = 2016)                                     as days_2016,
        countif(year = 2017)                                     as days_2017,
        avg(kwh)                                                 as avg_daily_kwh,
        sum(if(year = 2016, kwh_per_sqm, 0))
            / nullif(countif(year = 2016), 0) * 366              as eui_2016_kwh_sqm   -- yıllığa ölçeklenmiş
    from {{ ref('int_building_daily') }}
    group by building_id

)

select
    m.building_id,
    m.site_id,
    m.country,
    loc.state,
    loc.city,
    cov.price_region,
    m.primary_use,
    m.sub_use,
    m.sqm,
    m.year_built,
    m.floors,
    m.timezone,
    m.is_parking,

    cov.first_date,
    cov.last_date,
    coalesce(cov.days_2016, 0)                                   as days_2016,
    coalesce(cov.days_2017, 0)                                   as days_2017,
    cov.avg_daily_kwh,
    cov.eui_2016_kwh_sqm,

    coalesce(cov.days_2016, 0) >= 300
        and coalesce(cov.days_2017, 0) >= 300
        and not m.is_parking                                     as is_modelable

from {{ ref('stg_metadata') }}       as m
left join {{ ref('site_locations') }} as loc
  on loc.site_id = m.site_id
left join coverage                   as cov
  on cov.building_id = m.building_id