
-- PURPOSE: Calculate delivery delay and SLA breach flags
-- BUSINESS REQ: Phase 3 Req #1 — Logistics Manager SLA dashboard
-- SOURCE: stg_olist__orders + stg_olist__order_items

with orders as (
    select * from {{ ref('stg_olist__orders') }}
),

order_items as (
    select * from {{ ref('stg_olist__order_items') }}
),

-- -- One order can have items from multiple sellers with different
-- shipping deadlines; the earliest deadline determines SLA breach.

seller_sla as (
    select
        order_id,
        min(shipping_limit_at)    as shipping_deadline
    from order_items
    group by order_id
),

delivery_calc as (
    select
        o.order_id,
        o.order_status,
        o.ordered_at,
        o.shipped_at,
        o.delivered_at,
        o.estimated_delivery_at,
        s.shipping_deadline,

        -- NULL for undelivered orders (not 0) to avoid treating
        -- canceled/in-transit orders as "on time" — Phase 3 DQ risk #1
        datediff('day',
            o.estimated_delivery_at,
            o.delivered_at)                         as delivery_delay_days,

        case
            when o.delivered_at is null then null
            when o.delivered_at <= o.estimated_delivery_at then true
            else false
        end                                         as is_on_time_delivery,

        case
            when o.shipped_at is null then null
            when o.shipped_at <= s.shipping_deadline then false
            else true
        end                                         as is_seller_sla_breach,

        datediff('day',
            o.ordered_at,
            o.shipped_at)                           as seller_processing_days

    from orders o
    -- LEFT JOIN so orders missing from order_items aren't silently dropped
    left join seller_sla s
        on o.order_id = s.order_id
)

select * from delivery_calc 