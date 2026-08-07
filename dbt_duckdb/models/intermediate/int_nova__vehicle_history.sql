-- Intermediate Nova History : Reconstitution chronologique et dédoublonnée des périodes de statut
with stg_events as (
    select * from {{ ref('stg_nova__status_events') }}
),

parsed_events as (
    select
        *,
        cast(replace(event_id, 'e', '') as integer) as event_seq
    from stg_events
),

-- 1. Élimination des événements doublons consécutifs ayant le même statut canonique
deduped_events as (
    select
        *,
        lag(canonical_status) over (
            partition by stock_vehicle_id 
            order by status_date asc, event_seq asc
        ) as prev_canonical_status
    from parsed_events
),

filtered_events as (
    select *
    from deduped_events
    where prev_canonical_status is null 
       or canonical_status != prev_canonical_status
),

-- 2. Calcul des dates de fin de période sur la séquence nettoyée
windowed as (
    select
        stock_vehicle_id,
        raw_vehicle_id,
        tenant_id,
        canonical_status,
        status_date as period_start_date,
        
        lead(status_date) over (
            partition by stock_vehicle_id 
            order by status_date asc, event_seq asc
        ) as period_end_date,
        
        row_number() over (
            partition by stock_vehicle_id 
            order by status_date desc, event_seq desc
        ) as rank_desc

    from filtered_events
)

select
    stock_vehicle_id,
    raw_vehicle_id,
    tenant_id,
    canonical_status,
    period_start_date,
    period_end_date,
    case when rank_desc = 1 then true else false end as is_current_period
from windowed