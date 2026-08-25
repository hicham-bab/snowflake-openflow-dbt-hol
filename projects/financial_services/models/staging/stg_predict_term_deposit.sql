-- ---------------------------------------------------------------------------
-- stg_predict_term_deposit
--
-- Term-deposit marketing campaign contacts. 45,211 rows, 5,289 of which
-- converted: an 11.7% base rate.
-- Optional stretch material: not needed to finish the track.
--
-- One thing to be careful with. `age` carries two different sentinels for
-- unknown: 999 on one row and -1 on three. Both are real integers in a real
-- integer column, so nothing errors and nothing warns you. Real ages run 18 to
-- 95. Average the column as-is and the answer is wrong in both directions at
-- once.
--
-- Rather than listing the two sentinels, this model rejects anything outside a
-- plausible age range. That way a third sentinel appearing next quarter is
-- handled without anyone having to notice it.
-- ---------------------------------------------------------------------------

{{ config(
    materialized='view',
    tags=['stretch']
) }}

with source as (

    select * from {{ ref('predict_term_deposit') }}

),

renamed as (

    select

        -- ---- keys ---------------------------------------------------------
        cast(id as number(38, 0)) as contact_id,

        -- ---- customer dimensions -----------------------------------------------
        cast(job as varchar) as job_category,
        cast(marital as varchar) as marital_status,
        cast(education as varchar) as education_level,

        -- 999 and -1 are sentinels, not ages. Anything outside 17 to 120 is
        -- treated as unknown rather than being enumerated by value.
        case
            when age < 17 or age > 120 then null
            else cast(age as number(38, 0))
        end as customer_age,

        case
            when age < 17 or age > 120 then true
            else false
        end as is_age_unknown,

        -- ---- financial position -------------------------------------------------
        cast(balance as number(18, 2)) as average_yearly_balance,

        case when lower(cast(housing as varchar)) = 'yes' then true else false end as has_housing_loan,
        case when lower(cast(loan as varchar)) = 'yes' then true else false end as has_personal_loan,
        case when lower(cast(c_default as varchar)) = 'yes' then true else false end as has_credit_in_default,

        -- ---- campaign contact ------------------------------------------------------
        cast(contact as varchar) as contact_channel,
        cast(month as varchar) as contact_month,
        cast(day as number(38, 0)) as contact_day_of_month,
        cast(duration as number(38, 0)) as last_contact_duration_seconds,
        cast(campaign as number(38, 0)) as contacts_this_campaign,
        cast(previous as number(38, 0)) as contacts_previous_campaigns,
        cast(poutcome as varchar) as previous_campaign_outcome,

        -- -1 means "never contacted before", which is not a number of days.
        case
            when pdays = -1 then null
            else cast(pdays as number(38, 0))
        end as days_since_previous_contact,

        case
            when pdays = -1 then true
            else false
        end as is_first_campaign,

        -- ---- the target --------------------------------------------------------------
        case when lower(cast(y as varchar)) = 'yes' then true else false end as has_subscribed

    from source

)

select * from renamed
