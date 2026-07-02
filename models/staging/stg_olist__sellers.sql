
with source as (
    select * from {{ source('olist', 'SELLERS') }}
),

renamed as (
    select
        seller_id,
        upper(seller_city) as seller_city,
        seller_state,
        seller_zip_code_prefix
    from source
)

select * from renamed