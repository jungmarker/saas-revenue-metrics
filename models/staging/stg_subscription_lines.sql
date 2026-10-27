-- Contract line items: the source of truth for recurring revenue.
-- A line contributes MRR on every day between start_date and end_date (inclusive).
select
    line_id,
    subscription_id,
    account_id,
    start_date::date                as start_date,
    end_date::date                  as end_date,
    plan,
    seats::integer                  as seats,
    unit_price_monthly::decimal(12, 2) as unit_price_monthly,
    mrr::decimal(14, 2)             as mrr,
    change_type,
    opportunity_id
from {{ source('ledgerly', 'subscription_lines') }}
