{{
    config(
        materialized = 'table',
        partition_by = {'field': 'timestamp', 'data_type': 'timestamp', 'granularity': 'month'},
        cluster_by = ['building_id']
    )
}}

-- Kendi temizlik kuralımız:
-- 1) 24 saat ve üzeri aralıksız sıfır → boş (sayaç arızası)
-- 2) 24 saatten kısa sıfır → tut (gerçek kapanma)
-- 3) Binanın %99'luk değerinin 5 katından büyük okuma → boş (sıçrama)

with readings as (

    select
        timestamp,
        building_id,
        kwh,
        coalesce(kwh = 0, false) as is_zero
    from {{ ref('stg_electricity_raw') }}

),

-- Gaps and islands: ardışık sıfırlara ortak bir seri kimliği ver
runs as (

    select
        *,
        row_number() over (partition by building_id order by timestamp)
          - row_number() over (partition by building_id, is_zero order by timestamp) as run_id
    from readings

),

run_lengths as (

    select
        *,
        count(*) over (partition by building_id, is_zero, run_id) as run_length
    from runs

),

-- Her binanın kendi %99'luk değeri
thresholds as (

    select distinct
        building_id,
        percentile_cont(kwh, 0.99) over (partition by building_id) as p99
    from readings

)

select
    r.timestamp,
    r.building_id,
    r.kwh                                                   as kwh_raw,
    case
        when r.is_zero and r.run_length >= 24 then null
        when r.kwh > 5 * t.p99                then null
        else r.kwh
    end                                                     as kwh,
    r.is_zero and r.run_length >= 24                        as is_long_zero,
    coalesce(r.kwh > 5 * t.p99, false)                      as is_spike
from run_lengths as r
left join thresholds as t using (building_id)