-- Staging Legacy Parc : Décodage statuts français, configurations, destinations et typage
with source as (
    select * from {{ source('legacy', 'parc') }}
),

statuts_ref as (
    select * from {{ ref('stg_legacy__statuts') }}
),

renamed as (
    select
        -- Clef composite unique par tenant et i_veh_id
        md5(concat_ws('||', 'legacy', p.tenant_id, p.i_veh_id)) as stock_vehicle_id,
        cast(p.i_veh_id as string) as raw_vehicle_id,
        cast(p.tenant_id as string) as tenant_id,
        cast(p.i_pve_id as string) as pos_id,
        'legacy' as source_system,
        
        -- Attributs véhicule
        upper(trim(p.vin)) as vin,
        upper(trim(p.s_veh_marque)) as make,
        trim(p.s_veh_modele) as model,
        lower(trim(p.s_veh_energie)) as energy,
        upper(trim(p.s_veh_plaque)) as plate,
        cast(p.i_veh_km as integer) as mileage,
        cast(p.d_veh_date_mec as date) as first_registration_date,
        
        -- Dates de stock
        cast(p.d_veh_date_entree_stock as date) as entry_stock_date,
        cast(p.d_veh_date_sortie as date) as exit_stock_date,
        cast(p.snapshot_date as date) as snapshot_date,
        
        -- Prix
        cast(p.f_veh_prix_rentree as decimal(10,2)) as entry_price,
        cast(p.f_veh_prix_vente as decimal(10,2)) as listing_price,
        
        -- Mapping Configuration : 0 et 3 = VN, 1 = VO, 2 = VD
        case cast(p.i_veh_configuration as integer)
            when 0 then 'VN'
            when 3 then 'VN'
            when 1 then 'VO'
            when 2 then 'VD'
            else 'UNKNOWN'
        end as configuration_code,
        
        -- Mapping Destination : 1=private, 2/3=professional, 4=scrapyard, 999=unknown
        case cast(p.i_veh_destination as integer)
            when 1 then 'private'
            when 2 then 'professional'
            when 3 then 'professional' -- Marchand et Enchériste regroupés sous 'professional'
            when 4 then 'scrapyard'
            else 'unknown' -- Pour le code 999 (Non renseigné)
        end as destination_code,
        
        -- Mapping Statut Canonique Legacy dynamisé via la table de référence
        coalesce(s.canonical_status, 'UNKNOWN') as canonical_status

    from source p
    left join statuts_ref s
        on cast(p.i_veh_statut as integer) = s.i_statut
        and cast(p.i_veh_configuration as integer) = s.i_veh_configuration
)

select * from renamed