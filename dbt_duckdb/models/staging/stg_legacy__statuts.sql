-- stg_legacy__statuts.sql à créer
select
    cast(i_statut as integer) as i_statut,
    cast(i_veh_configuration as integer) as i_veh_configuration,
    trim(s_libelle) as libelle,
    case
        when i_statut in (100) then 'PREN'
        when i_statut in (101,200,302) then 'PHEN'
        when i_statut in (102,201) then 'PREP'
        when i_statut in (103,202,301) then 'SAST'
        when i_statut in (104,106,203,303) then 'DELI'
        when i_statut in (105,204,304) then 'EXIT'
        when i_statut in (300) then 'UNCO'
        else 'UNKNOWN'
    end as canonical_status
from {{ source('legacy','statuts') }}