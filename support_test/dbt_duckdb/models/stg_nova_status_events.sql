select * from {{ source('nova', 'status_events') }}
