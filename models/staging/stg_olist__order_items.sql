

with source as (
    select * from {{ source('olist', 'ORDER_ITEMS') }}
),

renamed as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        cast(shipping_limit_date as timestamp) as shipping_limit_at,
        price,
        freight_value
    from source
)

select * from renamed