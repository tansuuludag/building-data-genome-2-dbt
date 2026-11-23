with source as (

    select * from {{ source('bdg2_raw', 'weather') }}

),

renamed as (

    select
        site_id,
        timestamp,
        airTemperature                                   as air_temp_c,
        dewTemperature                                   as dew_temp_c,
        windSpeed                                        as wind_speed_ms,
        seaLvlPressure                                   as sea_level_pressure_hpa,

        -- NOAA kodu: -1 = ölçülemeyecek kadar az yağış → 0
        case
            when precipDepth1HR = -1 then 0
            else precipDepth1HR
        end                                              as precip_1h_mm

    from source

)

select * from renamed