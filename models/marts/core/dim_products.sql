
-- =============================================================
-- MODEL: dim_products
-- TYPE: Dimension Table (SCD Type 1)
-- GRAIN: One row per product (product_id)
-- PURPOSE: Product attributes + English category names
-- NOTE: Portuguese → English translation via COALESCE.
--       Phase 3 DQ risk: some categories are missing a translation.
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

        -- Falls back to the Portuguese name when no English for PBI readable
        -- translation is available for this category
        coalesce(
            c.product_category_name_english,
            p.product_category_name
        )                               as product_category_name_english,

       -- Physical attributes, used in logistics analysis
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,

        -- Derived volume, used for delivery cost analysis
        p.product_length_cm *
        p.product_height_cm *
        p.product_width_cm              as product_volume_cm3

    from products p
    left join categories c
        on p.product_category_name = c.product_category_name
)

select * from final