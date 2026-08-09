

-- Fails if any row has a date value later than the current
-- timestamp — catches bad/corrupted date entries or load errors.

{% test no_future_dates(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} > current_timestamp()

{% endtest %}