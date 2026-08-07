-- Staging Nova Vehicles : Typage, normalisation et création de la Surrogate Key composite
with source as (
    select * from {{ source('nova', 'vehicles') }}
),

renamed as (
    select
        -- Clef composite unique par tenant et vehicle_id
        md5(concat_ws('||', 'nova', tenant_id, vehicle_id)) as stock_vehicle_id,
        cast(vehicle_id as string) as raw_vehicle_id,
        cast(tenant_id as string) as tenant_id,
        cast(pos_id as string) as pos_id,
        'nova' as source_system,
        
        -- Attributs véhicule
        upper(trim(vin)) as vin,
        upper(trim(make)) as make,
        trim(model) as model,
        lower(trim(energy)) as energy,
        upper(trim(plate)) as plate,
        cast(mileage as integer) as mileage,
        cast(first_registration as date) as first_registration_date,
        
        -- Prix
        cast(entry_price as decimal(10,2)) as entry_price,
        cast(listing_price as decimal(10,2)) as listing_price,
        
        -- Standardisation Configuration : 1=NEW(VN), 2=DEMO(VD), 3=USED(VO)
        case cast(configuration as integer)
            when 1 then 'VN'
            when 2 then 'VD'
            when 3 then 'VO'
            else 'UNKNOWN'
        end as configuration_code,
        
        -- Standardisation Destination : 1=private, 2=professional, 3=scrapyard
        case cast(destination as integer)
            when 1 then 'private'
            when 2 then 'professional'
            when 3 then 'scrapyard'
            else 'unknown'
        end as destination_code

    from source
)

select * from renamed