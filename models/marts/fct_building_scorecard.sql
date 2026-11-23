{% set cv_threshold = 0.25 %}   -- ASHRAE Guideline 14, günlük veri için kabul eşiği
{% set excess_threshold = 0.10 %}

with pred as (

    -- Günlük tahmin + o günün fiyatı
    select
        p.building_id,
        p.date,
        p.actual_kwh,
        p.expected_kwh,
        p.use_ml,
        p.model_run_at,
        f.price_usd_per_kwh
    from {{ ref('stg_ml_predictions_daily') }} as p
    join {{ ref('fct_building_daily') }}       as f
      on f.building_id = p.building_id and f.date = p.date

),

per_building as (

    select
        building_id,
        count(*)                                                          as n_days,
        sum(actual_kwh)                                                   as actual_kwh,
        sum(expected_kwh)                                                 as expected_kwh,
        sum((actual_kwh - expected_kwh) * price_usd_per_kwh)              as excess_usd,
        sqrt(avg(pow(actual_kwh - expected_kwh, 2)))
            / nullif(avg(actual_kwh), 0)                                  as cv_rmse,
        logical_or(use_ml)                                                as use_ml,
        max(model_run_at)                                                 as model_run_at
    from pred
    group by building_id

),

scored as (

    select
        *,
        actual_kwh - expected_kwh                                         as excess_kwh,
        safe_divide(actual_kwh - expected_kwh, expected_kwh)              as excess_pct,
        n_days >= 0.8 * max(n_days) over ()                               as has_full_year
    from per_building

)

select
    s.building_id,
    d.site_id,
    d.city,
    d.country,
    d.primary_use,
    d.sqm,

    s.n_days,
    s.has_full_year,
    if(s.use_ml, 'LightGBM', 'Referans')                                  as model_used,
    s.cv_rmse,

    s.actual_kwh,
    s.expected_kwh,
    s.excess_kwh,
    s.excess_pct,
    s.excess_usd,

    s.has_full_year
        and s.cv_rmse < {{ cv_threshold }}
        and s.excess_pct > {{ excess_threshold }}                         as is_flagged,

    s.model_run_at

from scored as s
join {{ ref('dim_building') }} as d
  on d.building_id = s.building_id