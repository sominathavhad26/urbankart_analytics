
-- Converts a raw value stored in cents into a standard currency
-- amount rounded to 2 decimal places (e.g. 1050 -> 10.50).

{% macro cents_to_currency(column_name, currency_code='BRL') %}
    round(
        cast({{ column_name }} as numeric) / 100.0,
        2
    )
{% endmacro %}