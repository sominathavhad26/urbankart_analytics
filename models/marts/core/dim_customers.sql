-- =============================================================
-- MODEL: dim_customers
-- TYPE: Dimension Table (SCD Type 1 — overwrite, no history)
-- GRAIN: One row per unique customer (customer_unique_id)
-- PURPOSE: Customer descriptive attributes for fct_orders join
-- NOTE: Uses customer_unique_id (not customer_id) because Olist
--       assigns a new customer_id per order — unique_id is the
--       actual person-level identifier
-- =============================================================

with customers as (
    select * from {{ ref('stg_olist__customers') }}
),

-- One customer_unique_id can map to multiple customer_id values;
-- keep the most recent record per customer.
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