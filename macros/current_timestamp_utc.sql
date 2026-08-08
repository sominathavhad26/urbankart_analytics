
-- Returns the current timestamp normalized to UTC, ensuring
-- consistent timezone handling across all models.

{% macro current_timestamp_utc() %}
    convert_timezone('UTC', current_timestamp())
{% endmacro %}