-- One row per account that has ever had a contract.
with movements as (
    select * from {{ ref('fct_mrr_movements') }}
),

lifetime as (
    select
        account_id,
        min(month_end) filter (where mrr > 0)                         as first_paid_month,
        max(month_end) filter (where mrr > 0)                         as last_paid_month,
        max(mrr)                                                      as peak_mrr,
        max(mrr) filter (where month_end = date '{{ var("as_of_date") }}') as current_mrr,
        count(*) filter (where mrr > 0)                               as paid_months
    from movements
    group by 1
),

first_contract as (
    select account_id, mrr as starting_mrr
    from movements
    where movement_type = 'new'
)

select
    a.account_id,
    a.account_name,
    a.segment,
    a.industry,
    a.region,
    a.billing_state,
    a.lead_source,
    a.owner_id,
    a.csm_id,
    s.billing_frequency,
    s.cancel_reason,
    date_trunc('month', l.first_paid_month)::date              as cohort_month,
    l.first_paid_month,
    l.last_paid_month,
    l.paid_months,
    f.starting_mrr,
    coalesce(l.current_mrr, 0)                                 as current_mrr,
    coalesce(l.current_mrr, 0) * 12                            as current_arr,
    l.peak_mrr,
    case when coalesce(l.current_mrr, 0) > 0 then 'active' else 'churned' end as customer_status
from lifetime l
join {{ ref('stg_accounts') }} a using (account_id)
left join {{ ref('stg_subscriptions') }} s using (account_id)
left join first_contract f using (account_id)
