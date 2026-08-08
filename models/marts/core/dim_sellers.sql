
-- =============================================================
-- MODEL: dim_sellers
-- TYPE: Dimension Table (SCD Type 1)
-- GRAIN: One row per seller (seller_id)
-- PURPOSE: Seller attributes for fct_orders join
-- NOTE: History tracking (SCD Type 2) is handled separately via
--       the snp_sellers snapshot — Phase 3 Req #2
-- =============================================================

with sellers as (
    select * from {{ ref('stg_olist__sellers') }}
),

final as (
    select
        -- Surrogate Primary Key
        {{ dbt_utils.generate_surrogate_key(['seller_id']) }}
                                        as seller_key,
        -- Natural Key
        seller_id,
        -- Attributes
        seller_city,
        seller_state,
        seller_zip_code_prefix
    from sellers
)

select * from final