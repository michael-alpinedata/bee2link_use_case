-- Staging Legacy Concessions
with source as (
    select * from {{ source('legacy', 'concessions') }}
),

renamed as (
    select
        cast(i_pve_id as string) as pos_id,
        cast(tenant_id as string) as tenant_id,
        trim(s_nom_concession) as pos_name,
        'legacy' as source_system
    from source
)

select * from renamed