-- Staging Nova Status Events : Nettoyage, déduplication (ex: e16/e49) et mapping canonique
with source as (
    select * from {{ source('nova', 'status_events') }}
),

deduplicated as (
    -- Traitement des doublons exacts d'événements repérés dans Nova
    select distinct
        event_id,
        vehicle_id,
        tenant_id,
        status_type,
        status_from
    from source
),

renamed as (
    select
        cast(event_id as string) as event_id,
        md5(concat_ws('||', 'nova', tenant_id, vehicle_id)) as stock_vehicle_id,
        cast(vehicle_id as string) as raw_vehicle_id,
        cast(tenant_id as string) as tenant_id,
        cast(status_from as date) as status_date,
        cast(status_type as integer) as raw_status_type,
        
        -- Mapping des codes statuts Nova vers le dictionnaire canonique
        case cast(status_type as integer)
            when 1 then 'UNCO'
            when 6 then 'PREN'
            when 5 then 'PHEN'
            when 2 then 'SAST'
            when 3 then 'DELI'
            when 4 then 'EXIT'
            else 
                -- Les codes 7 à 13 correspondent à toutes les activités de PREP
                case 
                    when cast(status_type as integer) between 7 and 13 then 'PREP'
                    else 'UNKNOWN'
                end
        end as canonical_status

    from deduplicated
)

select * from renamed