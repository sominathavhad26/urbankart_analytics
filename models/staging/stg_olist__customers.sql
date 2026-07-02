with source as (
    select * from {{ source('olist', 'CUSTOMERS') }}
),

renamed as (
    select
        customer_id,
        customer_unique_id,
        upper(customer_city) as customer_city,
        customer_state,
        customer_zip_code_prefix
    from source
)

select * from renamed