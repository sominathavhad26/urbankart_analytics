
-- PURPOSE: Aggregate payments to order grain (resolves fan-out
--          before joining into fct_orders)
-- BUSINESS REQ: Phase 3 Req #3 — payment/installment analysis

with payments as (
    select * from {{ ref('stg_olist__payments') }}
),

aggregated as (
    select
        order_id,

        -- Total payment value per order
        sum(payment_value) as total_payment_value,

        -- Installment usage (Phase 3 Req #3)
        max(payment_installments) as max_installments,
        sum(case when payment_installments > 1
            then 1 else 0 end) as installment_payment_count,

        -- Payment type breakdown (for Finance dashboard)
        sum(case when payment_type = 'credit_card'
            then payment_value else 0 end) as credit_card_value,
        sum(case when payment_type = 'boleto'
            then payment_value else 0 end) as boleto_value,
        sum(case when payment_type = 'voucher'
            then payment_value else 0 end) as voucher_value,
        sum(case when payment_type = 'debit_card'
            then payment_value else 0 end) as debit_card_value,

        -- One order can have multiple payment records (split
        -- payments); this counts them for downstream context
        count(*) as payment_record_count  

    from payments
    group by order_id
)

select * from aggregated