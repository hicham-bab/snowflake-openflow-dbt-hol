-- ---------------------------------------------------------------------------
-- stg_risk_assess_customers
--
-- Customer dimension for the credit risk star. 1,000 rows.
--
-- GOVERNANCE NOTE
-- The source has a `customer_name` column. It does not appear below.
--
-- In this particular data set the values are persona labels ("Stable Prime
-- Customer") rather than real names, so nothing here is actually identifying.
-- It is excluded anyway, for two reasons. First, a column called customer_name
-- in a customer table is a name field until someone proves otherwise, and the
-- default has to be exclude-then-justify rather than the other way round.
-- Second, everything downstream of this model eventually reaches an AI agent,
-- and an agent will happily read a name column out loud to whoever asked.
--
-- Where the business genuinely needs to join on identity without seeing it, a
-- one-way hash is the usual answer, and `customer_name_hash` below is that.
-- It is stable, it joins, and it cannot be read back.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    select * from {{ ref('risk_assess_customers') }}

),

renamed as (

    select

        -- ---- keys ---------------------------------------------------------
        cast(customer_id as varchar) as customer_id,

        -- ---- PII, hashed rather than dropped ---------------------------------
        -- md5 is fine for a join key. It is not fine as a security control on
        -- a low-cardinality field, because the values can be enumerated. Real
        -- production masking belongs in a Snowflake masking policy, applied by
        -- the platform team. See snowflake/GOTCHAS.md.
        md5(cast(customer_name as varchar)) as customer_name_hash,

        -- ---- segmentation dimensions -------------------------------------------
        cast(segment as varchar) as customer_segment,
        cast(income_bracket as varchar) as income_bracket,
        cast(credit_score_range as varchar) as credit_score_range,
        cast(education_level as varchar) as education_level,
        cast(employment_sector as varchar) as employment_sector,

        -- ---- credit facts --------------------------------------------------------
        cast(annual_income as number(18, 2)) as annual_income,
        cast(credit_score as number(38, 0)) as credit_score,
        cast(debt_to_income_ratio as number(9, 4)) as debt_to_income_ratio,
        cast(years_of_credit_history as number(38, 0)) as years_of_credit_history,
        cast(num_credit_accounts as number(38, 0)) as num_credit_accounts,
        cast(num_delinquencies_last_2_years as number(38, 0)) as num_delinquencies_last_2_years,
        cast(num_recent_inquiries as number(38, 0)) as num_recent_inquiries,

        -- ---- booleans that arrive as text -----------------------------------------
        -- The source Postgres columns are `text` holding 'True' / 'False'.
        case
            when upper(cast(is_homeowner as varchar)) = 'TRUE' then true
            else false
        end as is_homeowner,

        case
            when upper(cast(has_previous_bankruptcy as varchar)) = 'TRUE' then true
            else false
        end as has_previous_bankruptcy

    from source

)

select * from renamed
