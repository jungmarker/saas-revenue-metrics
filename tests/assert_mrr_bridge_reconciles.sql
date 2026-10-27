-- Every month: starting MRR + all movements must equal ending MRR (to the cent).
select *
from {{ ref('mrr_bridge') }}
where abs(starting_mrr + new_mrr + reactivation_mrr + expansion_mrr + contraction_mrr + churned_mrr - ending_mrr) > 0.01
