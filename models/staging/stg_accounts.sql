-- One row per CRM account. Normalizes state codes; flags accounts that never became customers.
with source as (
    select * from {{ source('ledgerly', 'accounts') }}
),

state_lookup as (
    select * from (values
        ('california','CA'),('new york','NY'),('texas','TX'),('florida','FL'),('illinois','IL'),
        ('massachusetts','MA'),('washington','WA'),('georgia','GA'),('colorado','CO'),('north carolina','NC'),
        ('virginia','VA'),('maryland','MD'),('pennsylvania','PA'),('ohio','OH'),('minnesota','MN'),
        ('arizona','AZ'),('new jersey','NJ'),('oregon','OR'),('michigan','MI'),('tennessee','TN'),
        ('utah','UT'),('missouri','MO'),('wisconsin','WI'),('indiana','IN')
    ) as t(state_name, state_code)
)

select
    s.account_id,
    trim(s.account_name)                                     as account_name,
    s.industry,
    s.employee_count::integer                                as employee_count,
    s.segment,
    coalesce(l.state_code, upper(trim(s.billing_state)))     as billing_state,
    s.region,
    s.owner_id,
    s.csm_id,
    s.created_at,
    s.lead_source,
    s.customer_since,
    s.status                                                 as crm_status
from source s
left join state_lookup l on lower(trim(s.billing_state)) = l.state_name
