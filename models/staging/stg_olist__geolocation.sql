
with source as (
    select * from {{ source('olist', 'GEOLOCATION') }}
),

renamed as (
    select
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        upper(geolocation_city) as geolocation_city,
        geolocation_state
    from source
)

select * from renamed