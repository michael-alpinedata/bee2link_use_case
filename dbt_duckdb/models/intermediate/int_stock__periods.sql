-- Intermediate Core : Modèle canonique unifié historisé (Nova + Legacy)
with nova_history as (
    select * from {{ ref('int_nova__vehicle_history') }}
),

nova_vehicles as (
    select * from {{ ref('stg_nova__vehicles') }}
),

nova_pos as (
    select * from {{ ref('stg_nova__points_of_sale') }}
),

legacy_parc as (
    select * from {{ ref('stg_legacy__parc') }}
),

legacy_concessions as (
    select * from {{ ref('stg_legacy__concessions') }}
),

reseaux as (
    select * from {{ ref('stg_ref__reseaux') }}
),

-- 1. Assemblage de l'historique Nova enrichi des attributs véhicule et POS
nova_periods as (
    select
        h.stock_vehicle_id,
        'nova' as source_system,
        v.tenant_id,
        v.pos_id,
        p.pos_name,
        r.reseau,
        
        -- Attributs véhicule
        v.vin,
        v.make,
        v.model,
        v.energy,
        v.plate,
        v.mileage,
        v.first_registration_date,
        v.configuration_code,
        v.destination_code,
        v.entry_price,
        v.listing_price,
        
        -- Périodes et statuts
        h.canonical_status,
        h.period_start_date,
        h.period_end_date,
        h.is_current_period,
        
        -- Date d'entrée initiale en stock (première période où le véhicule passe en stock)
        min(case when h.canonical_status in ('PHEN', 'PREP', 'SAST', 'DELI') then h.period_start_date end) over (
            partition by h.stock_vehicle_id
        ) as entry_stock_date

    from nova_history h
    left join nova_vehicles v on h.stock_vehicle_id = v.stock_vehicle_id
    left join nova_pos p on v.pos_id = p.pos_id and v.tenant_id = p.tenant_id
    left join reseaux r on r.source_system = 'nova' and r.pos_id = v.pos_id
),

-- 2. Assemblage du snapshot Legacy sous forme d'une période unique par véhicule
legacy_periods as (
    select
        l.stock_vehicle_id,
        'legacy' as source_system,
        l.tenant_id,
        l.pos_id,
        c.pos_name,
        r.reseau,
        
        -- Attributs véhicule
        l.vin,
        l.make,
        l.model,
        l.energy,
        l.plate,
        l.mileage,
        l.first_registration_date,
        l.configuration_code,
        l.destination_code,
        l.entry_price,
        l.listing_price,
        
        -- Périodes et statuts
        l.canonical_status,
        l.entry_stock_date as period_start_date,
        l.exit_stock_date as period_end_date,
        true as is_current_period,
        l.entry_stock_date

    from legacy_parc l
    left join legacy_concessions c on l.pos_id = c.pos_id and l.tenant_id = c.tenant_id
    left join reseaux r on r.source_system = 'legacy' and r.pos_id = l.pos_id
),

-- 3. Union des deux systèmes
unified as (
    select * from nova_periods
    union all
    select * from legacy_periods
)

select
    *,
    -- Flags métiers de présence en stock
    case 
        when canonical_status in ('PHEN', 'PREP', 'SAST', 'DELI') then true 
        else false 
    end as is_in_stock,
    
    case 
        when canonical_status in ('PHEN', 'PREP', 'SAST') then true 
        else false 
    end as is_in_stock_excl_delivery

from unified