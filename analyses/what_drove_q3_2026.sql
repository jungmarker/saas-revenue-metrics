-- Analysis: what drove net new MRR in Q3 2026, by segment and movement type?
select
    c.segment,
    m.movement_type,
    count(*)                    as accounts,
    round(sum(m.mrr_change), 0) as mrr_change
from {{ ref('fct_mrr_movements') }} m
join {{ ref('dim_customers') }} c using (account_id)
where m.month_end between date '2026-07-01' and date '2026-09-30'
  and m.movement_type not in ('retained', 'inactive')
group by 1, 2
order by 1, 4 desc
