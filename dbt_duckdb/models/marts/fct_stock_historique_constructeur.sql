-- Mart 2 : Historique de stock Réseau Sud (Anonymisé pour le Constructeur)
with core_periods as (
    select * from {{ ref('int_stock__periods') }}
)

select
    -- Identifiants & Concession (sans VIN ni Plaque)
    stock_vehicle_id,
    source_system,
    tenant_id,
    pos_id,
    pos_name,
    reseau,
    
    -- Attributs véhicule non-identifiants (sans prix)
    make,
    model,
    energy,
    mileage,
    first_registration_date,
    configuration_code,
    destination_code,
    
    -- Suivi historique du statut
    canonical_status,
    period_start_date,
    period_end_date,
    
    -- Durée dans le statut (si période en cours, calcul jusqu'au 2026-08-01)
    date_diff('day', period_start_date, coalesce(period_end_date, cast('{{ var('target_date') }}' as date))) as days_in_status,
    
    -- Flags métiers
    is_current_period,
    is_in_stock,
    is_in_stock_excl_delivery

from core_periods
where reseau = 'sud'