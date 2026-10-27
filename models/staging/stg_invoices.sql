select
    invoice_id,
    subscription_id,
    account_id,
    invoice_date::date      as invoice_date,
    due_date::date          as due_date,
    amount::decimal(14, 2)  as amount,
    status,
    paid_date::date         as paid_date
from {{ source('ledgerly', 'invoices') }}
