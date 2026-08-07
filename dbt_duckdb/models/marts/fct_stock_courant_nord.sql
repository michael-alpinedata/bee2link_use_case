-- Mart 1 : Stock courant Réseau Nord (Dashboard Concession Power BI)
with core_periods as (
    select * from {{ ref('int_stock__periods') }}
)

select
    -- Identifiants & Système source
    stock_vehicle_id,
    source_system,
    tenant_id,
    pos_id,
    pos_name,
    
    -- Attributs véhicule
    vin,
    plate,
    make,
    model,
    energy,
    mileage,
    first_registration_date,
    configuration_code,
    destination_code,
    
    -- Statut & Dates
    canonical_status,
    entry_stock_date,
    period_start_date as current_status_date,
    
    -- Valorisation
    entry_price,
    listing_price,
    
    -- Ancienneté & Tranches d'âge au 2026-08-01
    date_diff('day', entry_stock_date, DATE '2026-08-01') as days_in_stock,
    case 
        when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 30  then '0-30'
        when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 60  then '31-60'
        when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 90  then '61-90'
        when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 180 then '91-180'
        when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 365 then '181-365'
        else '>365'
    end as age_bracket,
    
    -- Flags métiers
    is_in_stock,
    is_in_stock_excl_delivery,
    case 
        when date_diff('day', entry_stock_date, DATE '2026-08-01') > 365 then true 
        else false 
    end as is_over_365_days

from core_periods
where reseau = 'nord'
  and is_in_stock = true
  and period_start_date <= DATE '2026-08-01'
  and (period_end_date > DATE '2026-08-01' or period_end_date is null)