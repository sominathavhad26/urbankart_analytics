
-- PURPOSE: Delivery delay + SLA breach calculate karna
-- BUSINESS REQ: Phase 3 Req #1 — Logistics Manager SLA dashboard
-- SOURCE: stg_olist__orders + stg_olist__order_items
-- =============================================================

with orders as (
    -- Staging se clean order data lo
    -- shipped_at, delivered_at, estimated_delivery_at already cast hai staging mein
    select * from {{ ref('stg_olist__orders') }}
),

order_items as (
    -- Seller SLA ke liye shipping_limit_date chahiye
    -- Ek order mein multiple items ho sakte hain alag sellers ke
    select * from {{ ref('stg_olist__order_items') }}
),

-- Seller SLA: har order ke liye sabse strict (earliest) deadline lo
-- Kyun MIN? Ek order mein 3 items hain — seller A: 15-Jun, seller B: 13-Jun
-- Sabse pehli deadline miss karna = SLA breach
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

        -- DELIVERY DELAY CALCULATION
        -- Positive = late (bura), Negative = early (acha), 0 = exact
        -- Snowflake DATEDIFF syntax: ('unit', start_date, end_date)
        -- NULL kyun? canceled/in-transit orders deliver nahi hue
        -- isliye NULL return karo, 0 mat mano (Phase 3 DQ risk #1)
        datediff('day',
            o.estimated_delivery_at,
            o.delivered_at)                         as delivery_delay_days,

        -- ON-TIME DELIVERY FLAG
        -- Phase 3 KPI: On-time delivery rate
        -- NULL = abhi deliver nahi hua (intentional — is_on_time test mein NULL allowed)
        -- TRUE = on time ya early, FALSE = late
        case
            when o.delivered_at is null then null
            when o.delivered_at <= o.estimated_delivery_at then true
            else false
        end                                         as is_on_time_delivery,

        -- SELLER SLA BREACH FLAG
        -- Phase 3 KPI: Seller SLA breach rate
        -- Seller ne shipping_deadline tak item courier ko diya ya nahi
        -- NULL = abhi ship nahi hua
        case
            when o.shipped_at is null then null
            when o.shipped_at <= s.shipping_deadline then false
            else true
        end                                         as is_seller_sla_breach,

        -- SELLER PROCESSING TIME
        -- Order place hone se ship hone mein kitne din lage
        -- Seller efficiency metric hai ye
        -- NULL = ship nahi hua abhi tak
        datediff('day',
            o.ordered_at,
            o.shipped_at)                           as seller_processing_days

    from orders o
    -- LEFT JOIN kyun INNER nahi?
    -- Agar koi order_id order_items mein nahi hai (edge case/data quality)
    -- INNER JOIN se wo order drop ho jaayega — silently missing data
    -- LEFT JOIN = koi bhi order drop nahi hoga, NULL aayega seller_sla mein
    left join seller_sla s
        on o.order_id = s.order_id
)

select * from delivery_calc 