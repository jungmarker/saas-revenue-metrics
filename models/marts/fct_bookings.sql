-- Closed-won bookings (ACV) by month, type and segment, plus win rates on closed deals.
with o as (
    select o.*, a.segment
    from {{ ref('stg_opportunities') }} o
    left join {{ ref('stg_accounts') }} a using (account_id)
    where o.is_closed
)

select
    date_trunc('month', close_date)::date                       as close_month,
    opportunity_type,
    segment,
    count(*)                                                     as closed_deals,
    count(*) filter (where is_won)                               as won_deals,
    round(count(*) filter (where is_won) * 1.0 / count(*), 4)    as win_rate,
    sum(acv) filter (where is_won)                               as bookings_acv,
    round(median(close_date - created_date) filter (where is_won)) as median_cycle_days_won
from o
group by 1, 2, 3
