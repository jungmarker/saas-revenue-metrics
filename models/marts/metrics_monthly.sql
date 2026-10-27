-- Headline SaaS metrics by month, for the company overall and by segment.
-- Definitions are documented in models/marts/_marts.yml and docs/metrics.md.
with m as (
    select mv.*, c.segment
    from {{ ref('fct_mrr_movements') }} mv
    join {{ ref('dim_customers') }} c using (account_id)
),

expanded as (  -- every row counts toward its segment and toward 'All'
    select *, segment as segment_key from m
    union all
    select *, 'All' as segment_key from m
),

monthly as (
    select
        segment_key                                                          as segment,
        month_end,
        sum(mrr)                                                             as mrr,
        sum(prior_mrr)                                                       as starting_mrr,
        count(*) filter (where mrr > 0)                                      as customers,
        count(*) filter (where prior_mrr > 0)                                as starting_customers,
        count(*) filter (where movement_type = 'new')                        as new_customers,
        count(*) filter (where movement_type = 'churn')                      as churned_customers,
        sum(mrr_change) filter (where movement_type in ('new', 'reactivation', 'expansion'))  as gained_mrr,
        -sum(mrr_change) filter (where movement_type in ('contraction', 'churn'))             as lost_mrr
    from expanded
    group by 1, 2
),

-- Trailing-12-month net and gross revenue retention:
-- of customers paying 12 months ago, what share of that MRR do they pay today?
ttm as (
    select
        cur.segment_key   as segment,
        cur.month_end,
        sum(prev.mrr)                         as base_mrr_12m_ago,
        sum(cur.mrr)                          as same_customers_mrr_now,
        sum(least(cur.mrr, prev.mrr))         as same_customers_mrr_capped
    from expanded cur
    join expanded prev
      on prev.account_id = cur.account_id
     and prev.segment_key = cur.segment_key
     and prev.month_end = last_day(cur.month_end - interval 12 month)
    where prev.mrr > 0
    group by 1, 2
)

select
    m.segment,
    m.month_end,
    m.mrr,
    m.mrr * 12                                                           as arr,
    m.customers,
    round(m.mrr / nullif(m.customers, 0), 2)                             as arpa_monthly,
    m.new_customers,
    m.churned_customers,
    round(m.churned_customers * 1.0 / nullif(m.starting_customers, 0), 4) as logo_churn_rate,
    round(coalesce(m.gained_mrr, 0) / nullif(m.lost_mrr, 0), 2)          as quick_ratio,
    round(t.same_customers_mrr_now / nullif(t.base_mrr_12m_ago, 0), 4)    as nrr_ttm,
    round(t.same_customers_mrr_capped / nullif(t.base_mrr_12m_ago, 0), 4) as grr_ttm,
    round((m.mrr / nullif(lag(m.mrr, 12) over (partition by m.segment order by m.month_end), 0)) - 1, 4) as arr_growth_yoy
from monthly m
left join ttm t using (segment, month_end)
order by m.segment, m.month_end
