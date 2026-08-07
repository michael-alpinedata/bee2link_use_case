-- Mart 3 : Pilotage du déstockage et détection des surstocks
with core_periods as (
    select * from {{ ref('int_stock__periods') }}
),

-- 1. Historique des ventes/sorties exploitables (durée > 0 jour)
historical_exits as (
    select
        configuration_code,
        make,
        date_diff('day', entry_stock_date, period_start_date) as rotation_days
    from core_periods
    where canonical_status = 'EXIT'
      and entry_stock_date is not null
      and period_start_date > entry_stock_date -- Filtre des durées non exploitables
),

-- Benchmark niveau 1 : Par Configuration x Marque
benchmark_make as (
    select
        configuration_code,
        make,
        avg(rotation_days) as avg_rotation_make
    from historical_exits
    group by 1, 2
),

-- Benchmark niveau 2 (Fallback) : Par Configuration globale
benchmark_global as (
    select
        configuration_code,
        avg(rotation_days) as avg_rotation_global
    from historical_exits
    group by 1
),

-- 2. Stock actuel au 2026-08-01
current_stock as (
    select
        stock_vehicle_id,
        source_system,
        tenant_id,
        pos_id,
        pos_name,
        reseau,
        make,
        model,
        configuration_code,
        canonical_status,
        entry_stock_date,
        listing_price,
        date_diff('day', entry_stock_date, DATE '2026-08-01') as age_in_days,
        
        case 
            when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 30  then '0-30'
            when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 60  then '31-60'
            when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 90  then '61-90'
            when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 180 then '91-180'
            when date_diff('day', entry_stock_date, DATE '2026-08-01') <= 365 then '181-365'
            else '>365'
        end as age_bracket
    from core_periods
    where is_in_stock = true
      and period_start_date <= DATE '2026-08-01'
      and (period_end_date > DATE '2026-08-01' or period_end_date is null)
)

select
    s.*,
    round(coalesce(bm.avg_rotation_make, bg.avg_rotation_global), 1) as group_avg_rotation_days,
    case 
        when s.age_in_days > (1.5 * coalesce(bm.avg_rotation_make, bg.avg_rotation_global)) then true 
        else false 
    end as is_overstock_alert

from current_stock s
left join benchmark_make bm 
       on s.configuration_code = bm.configuration_code 
      and s.make = bm.make
left join benchmark_global bg 
       on s.configuration_code = bg.configuration_code