-- =============================================================
-- MODEL: dim_customers
-- TYPE: Dimension Table (SCD Type 1 — overwrite, no history)
-- GRAIN: One row per unique customer (customer_unique_id)
-- PURPOSE: Customer descriptive attributes for fct_orders join
-- NOTE: customer_unique_id use kiya (not customer_id) kyunki
--       Olist mein ek customer har order pe naya customer_id
--       receive karta hai — unique_id = actual person identifier
-- =============================================================

with customers as (
    select * from {{ ref('stg_olist__customers') }}
),

-- Deduplication zaroori hai
-- Ek customer_unique_id ke multiple customer_id ho sakte hain
-- Latest customer_id wala record lo (most recent info)
deduped as (
    select
        customer_unique_id,
        customer_city,
        customer_state,
        customer_zip_code_prefix,
        row_number() over (
            partition by customer_unique_id
            order by customer_id desc
        ) as rn
    from customers
),

final as (
    select
        -- Surrogate Primary Key
        {{ dbt_utils.generate_surrogate_key(['customer_unique_id']) }}
                                        as customer_key,
        -- Natural Key
        customer_unique_id,
        -- Attributes
        customer_city,
        customer_state,
        customer_zip_code_prefix
    from deduped
    where rn = 1
)

select * from final