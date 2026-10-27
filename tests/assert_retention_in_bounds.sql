-- GRR can never exceed 100% or NRR; both must be positive.
select segment, month_end, nrr_ttm, grr_ttm
from {{ ref('metrics_monthly') }}
where grr_ttm > 1.0001 or grr_ttm > nrr_ttm + 0.0001 or nrr_ttm <= 0
