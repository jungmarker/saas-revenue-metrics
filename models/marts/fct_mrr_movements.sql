-- One row per account per month: MRR, prior-month MRR, and the movement that explains the change.
--   new          : first month with MRR > 0
--   reactivation : MRR > 0 again after a $0 month
--   expansion    : MRR up vs. prior month (existing customer)
--   contraction  : MRR down but still > 0
--   churn        : MRR went to 0
with mrr as (
    select
        account_id,
        month_end,
        mrr,
        seats,
        lag(mrr, 1, 0) over (partition by account_id order by month_end)                    as prior_mrr,
        max(mrr) over (partition by account_id order by month_end
                       rows between unbounded preceding and 1 preceding)                    as max_prior_mrr
    from {{ ref('int_account_mrr_monthly') }}
)

select
    account_id,
    month_end,
    mrr,
    prior_mrr,
    mrr - prior_mrr as mrr_change,
    seats,
    case
        when prior_mrr = 0 and mrr > 0 and coalesce(max_prior_mrr, 0) = 0 then 'new'
        when prior_mrr = 0 and mrr > 0                                     then 'reactivation'
        when prior_mrr > 0 and mrr = 0                                     then 'churn'
        when mrr > prior_mrr                                               then 'expansion'
        when mrr < prior_mrr                                               then 'contraction'
        when mrr > 0                                                       then 'retained'
        else 'inactive'
    end as movement_type
from mrr
