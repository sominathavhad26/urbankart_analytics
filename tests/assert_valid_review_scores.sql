
-- Singular test: specific to fct_reviews only (not reusable).
-- Returns rows where review_score is outside 1-5 or missing.
-- Zero rows returned = test passes.
select *
from {{ ref('fct_reviews') }}
where review_score not between 1 and 5
   or review_score is null