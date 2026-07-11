
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

        -- Count of payment records per order
        count(*) as payment_record_count  

    from payments
    group by order_id
)

select * from aggregated