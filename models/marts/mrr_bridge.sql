-- Monthly MRR bridge (a.k.a. MRR waterfall): starting MRR + movements = ending MRR.
-- A singular test (tests/assert_mrr_bridge_reconciles.sql) proves it ties out every month.
select
    month_end,
    sum(prior_mrr)                                                          as starting_mrr,
    sum(case when movement_type = 'new'          then mrr_change else 0 end) as new_mrr,
    sum(case when movement_type = 'reactivation' then mrr_change else 0 end) as reactivation_mrr,
    sum(case when movement_type = 'expansion'    then mrr_change else 0 end) as expansion_mrr,
    sum(case when movement_type = 'contraction'  then mrr_change else 0 end) as contraction_mrr,
    sum(case when movement_type = 'churn'        then mrr_change else 0 end) as churned_mrr,
    sum(mrr)                                                                as ending_mrr,
    count(*) filter (where movement_type = 'new')                           as new_customers,
    count(*) filter (where movement_type = 'churn')                         as churned_customers,
    count(*) filter (where mrr > 0)                                         as ending_customers
from {{ ref('fct_mrr_movements') }}
group by 1
order by 1
