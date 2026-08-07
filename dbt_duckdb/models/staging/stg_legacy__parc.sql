-- Staging Legacy Parc : Décodage statuts français, configurations, destinations et typage
with source as (
    select * from {{ source('legacy', 'parc') }}
),

renamed as (
    select
        -- Clef composite unique par tenant et i_veh_id
        md5(concat_ws('||', 'legacy', tenant_id, i_veh_id)) as stock_vehicle_id,
        cast(i_veh_id as string) as raw_vehicle_id,
        cast(tenant_id as string) as tenant_id,
        cast(i_pve_id as string) as pos_id,
        'legacy' as source_system,
        
        -- Attributs véhicule
        upper(trim(vin)) as vin,
        upper(trim(s_veh_marque)) as make,
        trim(s_veh_modele) as model,
        lower(trim(s_veh_energie)) as energy,
        upper(trim(s_veh_plaque)) as plate,
        cast(i_veh_km as integer) as mileage,
        cast(d_veh_date_mec as date) as first_registration_date,
        
        -- Dates de stock
        cast(d_veh_date_entree_stock as date) as entry_stock_date,
        cast(d_veh_date_sortie as date) as exit_stock_date,
        cast(snapshot_date as date) as snapshot_date,
        
        -- Prix
        cast(f_veh_prix_rentree as decimal(10,2)) as entry_price,
        cast(f_veh_prix_vente as decimal(10,2)) as listing_price,
        
        -- Mapping Configuration : 0 et 3 = VN, 1 = VO, 2 = VD
        case cast(i_veh_configuration as integer)
            when 0 then 'VN'
            when 3 then 'VN'
            when 1 then 'VO'
            when 2 then 'VD'
            else 'UNKNOWN'
        end as configuration_code,
        
        -- Mapping Destination : 1=private, 2/3=professional, 4=scrapyard, 999=unknown
        case cast(i_veh_destination as integer)
            when 1 then 'private'
            when 2 then 'professional'
            when 3 then 'professional' -- Marchand et Enchériste regroupés sous 'professional'
            when 4 then 'scrapyard'
            else 'unknown' -- Pour le code 999 (Non renseigné)
        end as destination_code,
        
        -- Mapping Statut Canonique Legacy basé sur le dictionnaire des statuts
        case cast(i_veh_statut as integer)
            when 100 then 'PREN'
            when 101 then 'PHEN'
            when 102 then 'PREP'
            when 103 then 'SAST'
            when 104 then 'DELI'
            when 106 then 'DELI' -- Livraison différée
            when 105 then 'EXIT'
            
            when 200 then 'PHEN'
            when 201 then 'PREP'
            when 202 then 'SAST'
            when 203 then 'DELI'
            when 204 then 'EXIT'
            
            when 300 then 'UNCO'
            when 301 then 'SAST'
            when 302 then 'PHEN'
            when 303 then 'DELI'
            when 304 then 'EXIT'
            else 'UNKNOWN'
        end as canonical_status

    from source
)

select * from renamed