
-- =============================================================
-- MODEL: dim_date
-- TYPE: Special Dimension (generated, not from source)
-- GRAIN: One row per calendar date (2016-01-01 to 2020-12-31)
-- PURPOSE: Power BI time intelligence enable karna
--          (YTD, MoM, QoQ, Same Period Last Year)
-- NOTE: Rows SOURCE se nahi aati — Snowflake GENERATOR se
--       programmatically create hoti hain
-- =============================================================

with date_spine as (
    -- Snowflake GENERATOR function se date series banao
    -- SEQ4() = 0 se start hone wala sequence
    -- DATEADD se har row pe ek din add hota hai
    -- rowcount = 1826 = 5 years (2016-2020) + 1 leap day
    select
        dateadd(
            day,
            seq4(),
            '2016-01-01'::date
        )                               as date_day
    from table(generator(rowcount => 1826))
),

final as (
    select
        -- Surrogate Primary Key
        {{ dbt_utils.generate_surrogate_key(['date_day']) }}
                                        as date_key,

        -- Natural Key
        date_day,

        -- Year attributes
        year(date_day)                  as year,
        quarter(date_day)               as quarter_number,
        month(date_day)                 as month_number,
        to_char(date_day, 'MMMM')       as month_name,
        to_char(date_day, 'Mon')        as month_short,

        -- Week attributes
        week(date_day)                  as week_of_year,
        dayofweek(date_day)             as day_of_week,
        to_char(date_day, 'DY')         as day_name_short,

        -- Useful flags
        -- Snowflake: 0=Sunday, 6=Saturday
        case
            when dayofweek(date_day) in (0, 6)
            then true else false
        end                             as is_weekend,

        -- Formatted labels (Power BI display ke liye)
        to_char(date_day, 'YYYY-MM')    as year_month,
        'Q' || quarter(date_day)
            || '-' || year(date_day)    as quarter_label,
        to_char(date_day, 'DD/MM/YYYY') as date_formatted

    from date_spine
)

select * from final