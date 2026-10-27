-- Ending MRR in the bridge must equal the raw contract lines active on each month end
-- (catches grid/join bugs that would silently drop or double-count revenue).
with from_lines as (
    select m.month_end, sum(l.mrr) as mrr
    from {{ ref('int_month_ends') }} m
    join {{ ref('stg_subscription_lines') }} l on m.month_end between l.start_date and l.end_date
    group by 1
)
select b.month_end, b.ending_mrr, f.mrr
from {{ ref('mrr_bridge') }} b
left join from_lines f using (month_end)
where abs(b.ending_mrr - coalesce(f.mrr, 0)) > 0.01
