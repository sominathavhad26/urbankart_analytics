
-- =============================================================
-- MODEL: fct_orders
-- TYPE: Fact Table (incremental)
-- GRAIN: One row per ORDER-ITEM (order_id + order_item_id)
-- PRIMARY KEY: order_item_key (surrogate)
-- PURPOSE: Central fact table — Finance, Ops, Marketing KPIs
-- SOURCE: int_orders_joined + int_order_payments_summary
--         + int_delivery_performance + all 4 dimensions
-- BUSINESS REQ: Phase 3 Req #1 (delivery), #3 (payments),
--               #5 (CX correlation)
-- NOTE: 1 order + N items = N rows.
--       For order count use COUNT(DISTINCT order_id).
--       For GMV use SUM(item_total_value).
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

-- Dimensions — only the keys needed for joining
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
        -- Composite grain (order_id + order_item_id) requires
        -- a composite surrogate key
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
        -- Payment values repeat across items of the same order —
        -- use COUNT(DISTINCT order_id) downstream to avoid double counting 
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
    -- LEFT JOIN everywhere so no row is silently dropped —
    -- an INNER JOIN could hide orphan records
    left join dim_customers dc
        on oj.customer_unique_id = dc.customer_unique_id 

    left join dim_sellers ds
        on oj.seller_id = ds.seller_id

    left join dim_products dp
        on oj.product_id = dp.product_id

    left join dim_date dd
        on oj.ordered_at::date = dd.date_day

    -- Payments and delivery are order-grain, joined onto the
    -- item-grain base table
    left join payments p
        on oj.order_id = p.order_id

    left join delivery d
        on oj.order_id = d.order_id

    {% if is_incremental() %}
    -- Only reprocess orders from the last run onward, with a
    -- 3-day look-back to catch late-arriving records
    where oj.ordered_at >= (
        select dateadd('day', -3, max(ordered_at))  -- Look-back window of 3 days to catch late-arriving orders
        from {{ this }}
    )
    {% else %}
    -- On a full refresh, only load data from the defined start date
    where oj.ordered_at >= '{{ var("start_date") }}'
    {% endif %}
    
)

select * from final