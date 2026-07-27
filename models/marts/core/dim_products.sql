
-- =============================================================
-- MODEL: dim_products
-- TYPE: Dimension Table (SCD Type 1)
-- GRAIN: One row per product (product_id)
-- PURPOSE: Product attributes + English category names
-- NOTE: Portuguese → English translation via COALESCE
--       Phase 3 DQ Risk: kuch categories ka translation missing
-- =============================================================

with products as (
    select * from {{ ref('stg_olist__products') }}
),

categories as (
    select * from {{ ref('stg_olist__product_category_translation') }}
),

final as (
    select
        -- Surrogate Primary Key
        {{ dbt_utils.generate_surrogate_key(['product_id']) }}
                                        as product_key,
        -- Natural Key
        p.product_id,

        -- Category (Portuguese original)
        p.product_category_name,

        -- Category (English — Power BI ke liye readable)
        -- COALESCE: English available? use karo. NULL? Portuguese fallback
        coalesce(
            c.product_category_name_english,
            p.product_category_name
        )                               as product_category_name_english,

        -- Physical attributes (logistics analysis ke liye)
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,

        -- Derived: volume (delivery cost analysis)
        p.product_length_cm *
        p.product_height_cm *
        p.product_width_cm              as product_volume_cm3

    from products p
    left join categories c
        on p.product_category_name = c.product_category_name
)

select * from final