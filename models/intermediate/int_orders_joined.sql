
-- =============================================================
-- MODEL: int_orders_joined
-- GRAIN: One row per ORDER-ITEM (order_id + order_item_id)
-- PURPOSE: 5 staging tables ka central wide join
-- fct_orders (Phase 5B) ka primary input hai ye model
-- SOURCE: orders + order_items + products + sellers + categories
-- NOTE: Ye model ephemeral hai — Snowflake mein nahi dikhega
--       Sirf fct_orders ke compiled SQL mein CTE banega
-- =============================================================

with orders as (
    select * from {{ ref('stg_olist__orders') }}
),

order_items as (
    -- Grain yahan se aata hai — order_items ek row per item per order hai
    -- 1 order + 4 items = 4 rows in this CTE
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

-- English category names ke liye translation table
-- Phase 3.6 DQ risk: "product_category_name Portuguese mein hai"
-- Ye join se English names milenge Power BI ke liye
categories as (
    select * from {{ ref('stg_olist__product_category_translation') }}
),

joined as (
    select
        -- ============ ORDER IDENTIFIERS ============
        oi.order_id,
        oi.order_item_id,       -- ye dono milke grain define karte hain

        -- ============ ORDER DETAILS ============
        o.customer_id,
        cu.customer_unique_id,                           -- ← NEW
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

        -- COALESCE kyun?
        -- Agar English translation available hai — use karo
        -- Agar nahi hai (NULL) — Portuguese fallback karo
        -- Phase 3.6: "kuch categories ka translation missing ho sakta hai"
        coalesce(
            c.product_category_name_english,
            p.product_category_name
        )                                           as product_category_name_english,

        -- Physical dimensions (dim_products mein bhi jayenge)
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,

        -- ============ SELLER DETAILS ============
        -- Phase 3: Seller Management domain
        s.seller_city,
        s.seller_state

    from order_items oi

    -- ORDER JOIN
    -- LEFT JOIN kyun? Koi item orphan nahi hoga
    -- INNER JOIN se items jinke order missing hain drop ho jaate
    left join orders o
        on oi.order_id = o.order_id

    -- PRODUCT JOIN
    -- LEFT JOIN kyun? Kuch items ka product_id missing ho sakta hai
    -- Data quality issue — silently drop mat karo
    left join customers cu                               -- ← NEW
        on o.customer_id = cu.customer_id

    left join products p
        on oi.product_id = p.product_id

    -- SELLER JOIN
    -- LEFT JOIN kyun? Kuch sellers table mein na ho (new seller edge case)
    left join sellers s
        on oi.seller_id = s.seller_id

    -- CATEGORY TRANSLATION JOIN
    -- LEFT JOIN kyun? Kuch categories ka English translation missing hai
    -- COALESCE se handle kiya upar — NULL aane pe bhi safe hai
    left join categories c
        on p.product_category_name = c.product_category_name
)

select * from joined 