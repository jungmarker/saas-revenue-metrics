-- Opportunities with amount stored as annual contract value (ACV).
select
    opportunity_id,
    account_id,
    opportunity_name,
    type                        as opportunity_type,
    owner_id,
    created_at,
    created_at::date            as created_date,
    close_date::date            as close_date,
    stage,
    is_closed,
    is_won,
    loss_reason,
    forecast_category,
    lead_source,
    plan,
    seats::integer              as seats,
    discount,
    amount::decimal(14, 2)      as acv
from {{ source('ledgerly', 'opportunities') }}
