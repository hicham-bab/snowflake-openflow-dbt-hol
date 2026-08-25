-- ---------------------------------------------------------------------------
-- RENAME THIS FILE to stg_<source_table>.sql
--
-- Staging models in this lab do four things and nothing else:
--   1. select explicit columns (never select *)
--   2. cast text columns to real types
--   3. give columns business-readable names
--   4. standardise casing on low-cardinality text columns
--
-- No joins, no aggregation, no business logic. That happens downstream.
--
-- STAGING MUST BE GREEN AT CHECKPOINT 1. Never seed a bug here or in a
-- staging test. See docs/answer-key.md for why.
--
-- GOVERNANCE. If the source carries personal data, exclude it here with an
-- explicit column list and a comment block explaining what and why. A column
-- you never selected cannot leak into an AI answer. See
-- projects/financial_services/models/staging/stg_loan.sql for the worked
-- example.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    -- Explicit column list, not select *. This is the control.
    select
        <column_1>,
        <column_2>

    from {{ ref('<table_name>') }}

),

renamed as (

    select

        -- ---- identifiers ---------------------------------------------------
        cast(<column_1> as varchar) as <business_name>,

        -- ---- dates -----------------------------------------------------------
        -- Many source columns in this database are `text` holding ISO
        -- YYYY-MM-DD. Cast them once, here.
        cast(<date_column> as date) as <business_date_name>,

        -- ---- measures ----------------------------------------------------------
        -- Use cast() when a conversion failure is a bug you want to hear about.
        -- Use try_cast() when the source is genuinely allowed to be blank, for
        -- example a text column with empty strings for unknown.
        cast(<numeric_column> as number(18, 2)) as <business_measure_name>,

        -- ---- booleans that arrive as text ----------------------------------------
        case
            when upper(cast(<flag_column> as varchar)) = 'TRUE' then true
            else false
        end as is_<something>,

        -- ---- descriptive text ------------------------------------------------------
        initcap(cast(<text_column> as varchar)) as <business_text_name>

    from source

)

select * from renamed
