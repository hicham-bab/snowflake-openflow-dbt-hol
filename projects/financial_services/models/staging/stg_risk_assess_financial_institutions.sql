-- ---------------------------------------------------------------------------
-- stg_risk_assess_financial_institutions
--
-- Institution dimension for the credit risk star. 20 rows, and every fact in
-- the track eventually joins to it.
--
-- `institution_name` is carried through. It is not personal data, so the PII
-- rule does not apply, but it is commercially sensitive: a Cortex Analyst
-- answer that names which bank has the worst default rate is a different
-- conversation from one that says "Credit Unions in the Midwest". The name is
-- available for drill-down and the semantic layer leads with type, size and
-- region instead. That is a deliberate choice, not an oversight.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    select * from {{ ref('risk_assess_financial_institutions') }}

),

renamed as (

    select

        -- ---- keys ---------------------------------------------------------
        cast(institution_id as varchar) as institution_id,

        -- ---- descriptive ------------------------------------------------------
        cast(institution_name as varchar) as institution_name,
        cast(institution_type as varchar) as institution_type,
        cast(institution_size as varchar) as institution_size,
        cast(region as varchar) as region,
        cast(primary_risk_model as varchar) as primary_risk_model,

        -- ---- scale ---------------------------------------------------------------
        cast(assets_under_management_billions as number(18, 4)) as assets_under_management_billions,
        cast(customer_base_millions as number(18, 4)) as customer_base_millions,
        cast(years_in_operation as number(38, 0)) as years_in_operation,
        cast(avg_customer_lifetime_years as number(9, 4)) as avg_customer_lifetime_years,

        -- ---- risk posture ---------------------------------------------------------
        -- risk_appetite is a number from 0 to 1, not a category. Naming it
        -- _score makes that obvious to anyone reading a query later.
        cast(risk_appetite as number(9, 4)) as risk_appetite_score,
        cast(regulatory_rating as number(38, 0)) as regulatory_rating,
        cast(digital_maturity_score as number(38, 0)) as digital_maturity_score,
        cast(fraud_loss_percentage as number(9, 4)) as fraud_loss_percentage,
        cast(default_rate_percentage as number(9, 4)) as default_rate_percentage,

        -- ---- derived: a readable band for the numeric appetite -------------------
        case
            when risk_appetite >= 0.6 then 'Aggressive'
            when risk_appetite >= 0.4 then 'Balanced'
            else 'Conservative'
        end as risk_appetite_band

    from source

)

select * from renamed
