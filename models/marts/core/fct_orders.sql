
-- =============================================================
-- MODEL: fct_orders
-- TYPE: Fact Table
-- GRAIN: One row per ORDER-ITEM (order_id + order_item_id)
-- PRIMARY KEY: order_item_key (surrogate)
-- PURPOSE: Central fact table — Finance, Ops, Marketing KPIs
-- SOURCE: int_orders_joined + int_order_payments_summary
--         + int_delivery_performance + all 4 dimensions
-- BUSINESS REQ: Phase 3 Req #1 (delivery), #3 (payments),
--               #5 (CX correlation)
-- NOTE: 1 order + N items = N rows
--       For order count: COUNT(DISTINCT order_id)
--       For GMV: SUM(item_total_value)
-- =============================================================

{{
    config(
        materialized = 'incremental',
        unique_key = 'order_item_key',
        on_schema_change = 'sync_all_columns'
    )
}}

with orders_joined as (
    -- Wide model — order + item + product + seller details
    select * from {{ ref('int_orders_joined') }}
),

payments as (
    -- Aggregated to order grain (fan-out already resolved)
    select * from {{ ref('int_order_payments_summary') }}
),

delivery as (
    -- Delivery delay + SLA flags per order
    select * from {{ ref('int_delivery_performance') }}
),

-- Dimension tables — sirf keys chahiye joining ke liye
dim_customers as (
    select
        customer_key,
        customer_unique_id
    from {{ ref('dim_customers') }}
),

dim_sellers as (
    select
        seller_key,
        seller_id
    from {{ ref('dim_sellers') }}
),

dim_products as (
    select
        product_key,
        product_id
    from {{ ref('dim_products') }}
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
        -- Composite kyunki grain = order_id + order_item_id
        {{ dbt_utils.generate_surrogate_key(
            ['oj.order_id', 'oj.order_item_id']
        ) }}                            as order_item_key,

        -- ============ NATURAL KEYS ============
        oj.order_id,
        oj.order_item_id,

        -- ============ FOREIGN KEYS (dimension joins) ============
        dc.customer_key,
        ds.seller_key,
        dp.product_key,
        dd.date_key                     as order_date_key,

        -- ============ ORDER ATTRIBUTES ============
        oj.order_status,
        oj.ordered_at,
        oj.approved_at,
        oj.shipped_at,
        oj.delivered_at,
        oj.estimated_delivery_at,

        -- ============ ITEM FINANCIAL METRICS ============
        -- Phase 3 KPI: GMV, AOV
        oj.price,
        oj.freight_value,
        oj.item_total_value,            -- price + freight (pre-calculated)

        -- ============ PAYMENT METRICS ============
        -- From int_order_payments_summary (order grain)
        -- Note: payment values repeat for each item of same order
        -- Use with COUNT(DISTINCT order_id) to avoid double counting 
        p.total_payment_value,
        p.max_installments,
        p.installment_payment_count,
        p.credit_card_value,
        p.boleto_value,
        p.voucher_value,
        p.debit_card_value,
        p.payment_record_count,

        -- ============ DELIVERY METRICS ============
        -- Phase 3 KPI: On-time delivery rate, SLA breach rate
        d.delivery_delay_days,
        d.is_on_time_delivery,
        d.is_seller_sla_breach,
        d.seller_processing_days

    from orders_joined oj    
    -- ============ DIMENSION JOINS ============
    -- LEFT JOIN everywhere — koi bhi row silently drop nahi hogi
    -- INNER JOIN se orphan records miss ho sakte hain

    left join dim_customers dc
        on oj.customer_unique_id = dc.customer_unique_id 

    left join dim_sellers ds
        on oj.seller_id = ds.seller_id

    left join dim_products dp
        on oj.product_id = dp.product_id

    -- Date join — ordered_at ko date level pe cast karo
    left join dim_date dd
        on oj.ordered_at::date = dd.date_day

    -- ============ INTERMEDIATE MODEL JOINS ============
    -- Payments: order grain pe join (not item grain)
    left join payments p
        on oj.order_id = p.order_id

    -- Delivery: order grain pe join
    left join delivery d
        on oj.order_id = d.order_id

            -- Incremental filter: only new orders since last run

    {% if is_incremental() %}
    where oj.ordered_at >= (
        select dateadd('day', -3, max(ordered_at))  -- Look-back window of 3 days to catch late-arriving orders
        from {{ this }}
    )
    {% endif %}
    
)

select * from final