-- ---------------------------------------------------------------------------
-- stg_loan
--
-- Consumer credit applications. 39,717 rows.
--
-- =========================================================================
-- THIS IS THE GOVERNANCE MODEL. READ THE LIST BEFORE THE SQL.
-- =========================================================================
--
-- The source table has 118 columns. This model selects 20 of them.
--
-- The following columns exist in the source and are DELIBERATELY EXCLUDED.
-- None of them reach staging, which means none of them reach a mart, a
-- semantic view, or an AI agent:
--
--   social_security_number   |
--   ssn                      |  Three columns. Identical value on all
--   ssnumber                 |  39,717 rows. Verified, not assumed.
--   ssnumber1                -> A fourth SSN-shaped column, holding a
--                               DIFFERENT value. Four columns, two facts.
--   drivers_license          |  Two columns. Identical value on all rows.
--   dl                       |
--   member_id                -> A second person identifier alongside id.
--   emp_title                -> Employer name, free text.
--   title                    -> Borrower-written loan title. Free text
--                               written by a member of the public, which
--                               means it contains whatever they typed.
--   c_desc                   -> Borrower-written description. Same problem,
--                               longer.
--   zip_code                 -> First three digits. Individually coarse,
--                               and a well-known re-identification vector
--                               in combination with state and income.
--   c_url                    -> A LendingClub URL containing the loan id.
--
-- Six redundant identity columns for two actual identifiers is what happens
-- when three source systems get merged and nobody owns the schema. The
-- de-duplication is the interesting part: if you drop `ssn` and stop, you have
-- shipped the same number twice under two other names.
--
-- WHY EXCLUDE RATHER THAN MASK
-- Masking is the right answer when the business needs the column. Nothing
-- downstream of this model needs any of the above, so the cheapest control is
-- not to select them. A column you never selected cannot leak. Where the
-- business does need identity for joining, hash it: see
-- stg_risk_assess_customers.sql.
--
-- WHAT THIS DOES NOT DO
-- This model is a project-level control, not a platform-level one. It stops
-- these columns reaching this project's marts. It does nothing about anyone
-- querying the raw seed table directly. In a real deployment that needs a
-- Snowflake masking policy and a grant model, which is the platform team's
-- job. See snowflake/GOTCHAS.md.
--
-- ---------------------------------------------------------------------------
-- Type handling, separately: four columns in the curated set are text that
-- should not be. int_rate is '7.90%'. revol_util is '28.30%'. issue_d is
-- 'Dec-11'. pub_rec_bankruptcies uses the string 'NA' for missing.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    -- Explicit column list. This is the control. Do not change it to
    -- `select *` without reading the block above.
    select
        id,
        funded_amnt,
        term,
        int_rate,
        grade,
        sub_grade,
        annual_inc,
        dti,
        home_ownership,
        addr_state,
        purpose,
        loan_status,
        delinq_2yrs,
        pub_rec,
        pub_rec_bankruptcies,
        revol_util,
        open_acc,
        total_acc,
        verification_status,
        issue_d

    from {{ ref('loan') }}

),

renamed as (

    select

        -- ---- keys ---------------------------------------------------------
        cast(id as number(38, 0)) as loan_id,

        -- ---- loan terms -------------------------------------------------------
        cast(funded_amnt as number(18, 2)) as funded_amount,

        -- ' 36 months' has leading whitespace and a word on the end. Strip
        -- both to get a number you can average.
        try_cast(trim(replace(cast(term as varchar), 'months', '')) as number(38, 0)) as term_months,

        -- '7.90%' -> 7.90
        try_cast(replace(cast(int_rate as varchar), '%', '') as number(9, 4)) as interest_rate_pct,

        cast(grade as varchar) as credit_grade,
        cast(sub_grade as varchar) as credit_sub_grade,
        cast(purpose as varchar) as loan_purpose,
        cast(loan_status as varchar) as loan_status,
        cast(verification_status as varchar) as income_verification_status,

        -- 'Dec-11' -> 2011-12-01. MON-YY is a Snowflake format string.
        try_to_date(cast(issue_d as varchar), 'MON-YY') as issued_at,

        -- ---- borrower financials -------------------------------------------------
        cast(annual_inc as number(18, 2)) as annual_income,
        cast(dti as number(9, 4)) as debt_to_income_ratio,
        cast(home_ownership as varchar) as home_ownership,
        cast(addr_state as varchar) as state_code,

        -- ---- credit history ------------------------------------------------------
        cast(delinq_2yrs as number(38, 0)) as delinquencies_last_2_years,
        cast(pub_rec as number(38, 0)) as public_records,

        -- 'NA' is the source's way of saying unknown, so try_cast rather than
        -- cast: unknown should become NULL, not break the build.
        try_cast(cast(pub_rec_bankruptcies as varchar) as number(38, 0)) as public_record_bankruptcies,

        -- '28.30%' -> 28.30
        try_cast(replace(cast(revol_util as varchar), '%', '') as number(9, 4)) as revolving_utilisation_pct,

        cast(open_acc as number(38, 0)) as open_accounts,
        cast(total_acc as number(38, 0)) as total_accounts,

        -- ---- derived: the outcome everyone actually models -------------------------
        case
            when loan_status = 'Charged Off' then true
            else false
        end as is_charged_off

    from source

)

select * from renamed
