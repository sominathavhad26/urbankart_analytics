
-- =============================================================
-- MODEL: fct_reviews
-- TYPE: Fact Table (Secondary)
-- GRAIN: One row per review (review_id + order_id)
-- PURPOSE: CX domain — review score analysis,
--          late delivery to low rating correlation
-- BUSINESS REQ: Phase 3 Req #5 (CX analysis), #6 (score validation)
-- NOTE: Separate from fct_orders kyunki grain alag hai
--       fct_orders = order-item, fct_reviews = review per order
--       Merge karne se review data har item pe repeat hoga
-- =============================================================

with reviews as (
    select * from {{ ref('stg_olist__reviews') }}
),

delivery as (
    -- Delivery context join karo — late delivery correlation ke liye
    -- Phase 3 Req #5: "CX Lead needs to know if late delivery
    -- links to low review scores"
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
        -- ============ SURROGATE PRIMARY KEY ============
        -- Composite kyunki Olist mein duplicate review_id exist
        -- karte hain (Phase 3 DQ Risk #2)
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

        -- Key insight flag: Phase 3 Req #5
        -- Late delivery AND negative review — correlation analysis
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