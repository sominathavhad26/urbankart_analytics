
-- Fails if any row has a negative value in this column —
-- catches invalid financial data (price, freight, etc.).
{% test positive_values(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} < 0

{% endtest %}