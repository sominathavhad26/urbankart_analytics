
-- =============================================================
-- MODEL: fct_reviews
-- TYPE: Fact Table (Secondary)
-- GRAIN: One row per review (review_id + order_id)
-- PURPOSE: CX domain — review score analysis and late-delivery
--          to low-rating correlation
-- BUSINESS REQ: Phase 3 Req #5 (CX analysis), #6 (score validation)
-- NOTE: Kept separate from fct_orders because the grain differs —
--       fct_orders is order-item level, fct_reviews is per review.
--       Merging them would duplicate review data across every item.
-- =============================================================

with reviews as (
    select * from {{ ref('stg_olist__reviews') }}
),

delivery as (
   
    select
        order_id,
        delivery_delay_days,
        is_on_time_delivery
    from {{ ref('int_delivery_performance') }}
),

dim_date as (
    select
        date_key,
        date_day
    from {{ ref('dim_date') }}
),

final as (
    select
        -- Composite key — Olist has duplicate review_id values,
        -- so order_id is needed to guarantee uniqueness (Phase 3 DQ Risk #2)
        {{ dbt_utils.generate_surrogate_key(
            ['r.review_id', 'r.order_id']
        ) }}                            as review_key,

        -- ============ NATURAL KEYS ============
        r.review_id,
        r.order_id,

        -- ============ FOREIGN KEY ============
        dd.date_key                     as review_date_key,

        -- ============ REVIEW METRICS ============
        r.review_score,

        -- Negative review flag (score 1 ya 2)
        case
            when r.review_score <= 2
            then true else false
        end                             as is_negative_review,

        -- ============ DELIVERY CONTEXT ============
        d.delivery_delay_days,
        d.is_on_time_delivery,

        -- Flags orders that were both late and rated poorly —
        -- core input for the CX/delivery correlation analysis (Req #5)
        case
            when r.review_score <= 2
             and d.is_on_time_delivery = false
            then true else false
        end                             as is_late_delivery_negative_review,

        -- ============ TIMESTAMPS ============
        r.review_created_at,
        r.review_answered_at

    from reviews r

    left join delivery d
        on r.order_id = d.order_id

    left join dim_date dd
        on r.review_created_at::date = dd.date_day
)

select * from final