
-- Divides two values safely, returning NULL instead of erroring
-- out when the denominator is zero or NULL.

{% macro safe_divide(numerator, denominator) %}
    case
        when {{ denominator }} = 0 or {{ denominator }} is null
        then null
        else {{ numerator }} / {{ denominator }}
    end
{% endmacro %}