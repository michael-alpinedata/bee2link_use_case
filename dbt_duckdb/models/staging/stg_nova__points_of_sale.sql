-- Staging Nova Points of Sale
with source as (
    select * from {{ source('nova', 'points_of_sale') }}
),

renamed as (
    select
        cast(pos_id as string) as pos_id,
        cast(tenant_id as string) as tenant_id,
        trim(pos_name) as pos_name,
        'nova' as source_system
    from source
)

select * from renamed