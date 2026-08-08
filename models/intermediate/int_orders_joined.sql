
-- GRAIN: One row per ORDER-ITEM (order_id + order_item_id)
-- PURPOSE: Central wide join across 6 staging tables — primary
--          input for fct_orders (Phase 5B)
-- SOURCE: orders + order_items + customers + products + sellers
--         + categories
-- NOTE: Ephemeral model — not materialized in Snowflake, only
--       compiled as a CTE inside fct_orders

with orders as (
    select * from {{ ref('stg_olist__orders') }}
),

order_items as (
    -- Grain originates here — one row per item per order
    select * from {{ ref('stg_olist__order_items') }}
),

customers as (                                          -- ← NEW
    select * from {{ ref('stg_olist__customers') }}
),

products as (
    select * from {{ ref('stg_olist__products') }}
),

sellers as (
    select * from {{ ref('stg_olist__sellers') }}
),

-- Product categories are stored in Portuguese in the raw data;
-- this table provides the English translation for reporting.
categories as (
    select * from {{ ref('stg_olist__product_category_translation') }}
),

joined as (
    select
        -- ============ ORDER IDENTIFIERS ============
        oi.order_id,
        oi.order_item_id,   

        -- ============ ORDER DETAILS ============
        o.customer_id,
        cu.customer_unique_id,                         
        o.order_status,
        o.ordered_at,           -- renamed in staging (order_purchase_timestamp)
        o.approved_at,
        o.shipped_at,
        o.delivered_at,
        o.estimated_delivery_at,

        -- ============ ITEM FINANCIALS ============
        -- Phase 3 KPI: GMV = SUM(price + freight_value)
        oi.product_id,
        oi.seller_id,
        oi.price,
        oi.freight_value,

        -- Pre-calculate item total — DRY principle
        -- fct_orders mein baar-baar price + freight likhne ki zaroorat nahi
        oi.price + oi.freight_value                 as item_total_value,

        -- Seller shipping deadline (for SLA context at item level)
        oi.shipping_limit_at,

        -- ============ PRODUCT DETAILS ============
        p.product_category_name,        -- Portuguese (original)

        -- Falls back to the original Portuguese name when an
        -- English translation isn't available for this category
        coalesce(
            c.product_category_name_english,
            p.product_category_name
        )                                           as product_category_name_english,

        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,

        -- ============ SELLER DETAILS ============

        s.seller_city,
        s.seller_state

    from order_items oi

    -- LEFT JOIN so items with a missing order aren't silently dropped
    left join orders o
        on oi.order_id = o.order_id

    left join customers cu
        on o.customer_id = cu.customer_id

    -- LEFT JOIN so items with a missing product aren't dropped
    -- (data quality issue, not something to hide)

    left join products p
        on oi.product_id = p.product_id

    -- LEFT JOIN to handle sellers not yet present in the sellers table
    left join sellers s
        on oi.seller_id = s.seller_id

    left join categories c
        on p.product_category_name = c.product_category_name
)

select * from joined 
