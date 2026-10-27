-- Cohort retention: for each cohort (month of first payment) and months since start,
-- how many logos are still paying and how much of the cohort's starting MRR remains (NRR curve).
with customers as (
    select account_id, segment, cohort_month, starting_mrr from {{ ref('dim_customers') }}
),

monthly as (
    select
        c.cohort_month,
        c.segment,
        datediff('month', c.cohort_month, date_trunc('month', m.month_end)) as months_since_start,
        c.account_id,
        c.starting_mrr,
        m.mrr
    from customers c
    join {{ ref('fct_mrr_movements') }} m using (account_id)
)

select
    cohort_month,
    segment,
    months_since_start,
    count(distinct account_id)                                      as cohort_customers,
    count(distinct account_id) filter (where mrr > 0)               as retained_customers,
    sum(starting_mrr)                                               as cohort_starting_mrr,
    sum(mrr)                                                        as cohort_mrr,
    round(count(distinct account_id) filter (where mrr > 0) * 1.0 / count(distinct account_id), 4) as logo_retention,
    round(sum(mrr) / nullif(sum(starting_mrr), 0), 4)               as revenue_retention
from monthly
group by 1, 2, 3
