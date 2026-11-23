with source as (

    select * from {{ source('bdg2_raw', 'metadata') }}

),

renamed as (

    select
        building_id,
        site_id,
        coalesce(primaryspaceusage, 'Unknown')            as primary_use,
        sub_primaryspaceusage                              as sub_use,
        sqm,
        lat,
        lng,
        timezone,

        -- Ülke: fiyat ve tatil tablolarını bağlamak için
        case
            when site_id in ('Crow', 'Moose')  then 'CA'   -- saat dilimi US/Eastern ama konum Ottawa
            when timezone = 'Europe/London'    then 'GB'
            when timezone = 'Europe/Dublin'    then 'IE'
            else 'US'
        end                                                as country,

        cast(yearbuilt as int64)                           as year_built,
        cast(numberoffloors as int64)                      as floors,

        -- Bayraklar
        coalesce(electricity = 'Yes', false)               as has_electricity,
        coalesce(primaryspaceusage = 'Parking', false)     as is_parking,
        lat is not null                                    as has_location

    from source

)

select * from renamed