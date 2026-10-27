select user_id, full_name, role, segment as user_segment, region as user_region, hire_date, termination_date
from {{ source('ledgerly', 'users') }}
