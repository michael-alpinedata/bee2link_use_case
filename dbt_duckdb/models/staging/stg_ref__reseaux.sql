-- Staging Réseau Partagé
with source as (
    select * from {{ source('ref', 'reseaux') }}
),

renamed as (
    select
        lower(trim(source_system)) as source_system,
        trim(pos_id) as pos_id,
        lower(trim(reseau)) as reseau
    from source
)

select * from renamed