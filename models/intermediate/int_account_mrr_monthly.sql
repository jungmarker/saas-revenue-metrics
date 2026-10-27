-- Account × month-end grid of MRR.
-- Business rule: MRR for a month = sum of contract lines active on the LAST DAY of that month.
-- Every account gets a row for every month after its first contract, including $0 months,
-- so churn and reactivation can be detected by comparing consecutive months.
with lines as (
    select * from {{ ref('stg_subscription_lines') }}
),

first_contract as (
    select account_id, min(start_date) as first_start_date
    from lines
    group by 1
),

grid as (
    select f.account_id, m.month_end
    from first_contract f
    join {{ ref('int_month_ends') }} m
      on m.month_end >= f.first_start_date
)

select
    g.account_id,
    g.month_end,
    coalesce(sum(l.mrr), 0)::decimal(14, 2)     as mrr,
    coalesce(sum(l.seats), 0)                   as seats
from grid g
left join lines l
  on l.account_id = g.account_id
 and g.month_end between l.start_date and l.end_date
group by 1, 2
