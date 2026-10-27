select
    subscription_id,
    account_id,
    start_date::date        as start_date,
    end_date::date          as cancelled_on,
    billing_frequency,
    status,
    cancel_reason
from {{ source('ledgerly', 'subscriptions') }}
