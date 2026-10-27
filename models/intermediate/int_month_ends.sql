-- Month-end calendar from the first month of data through the snapshot date.
select
    last_day(month_start::date) as month_end,
    month_start::date           as month_start
from generate_series(
    date '{{ var("first_month") }}',
    date_trunc('month', date '{{ var("as_of_date") }}'),
    interval 1 month
) as t(month_start)
