-- ---------------------------------------------------------------------------
-- stg_risk_assess_risk_profiles
--
-- The relationship fact: one row per customer and institution pair. 2,948 rows.
--
-- Three columns here look numeric and are not: collateral_quality_score,
-- liquidity_ratio and projected_cash_flow_rating are all `text` in the source,
-- with an empty string where the value is unknown. About two thirds of rows are
-- empty on each.
--
-- try_cast is the right tool. cast() throws "Numeric value '' is not
-- recognized" and takes the whole model down. try_cast returns NULL for the
-- rows it cannot convert and keeps going, which is what "unknown" should mean.
-- Use cast() when a failure to convert is a bug you want to hear about, and
-- try_cast when the source is genuinely allowed to be blank.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    select * from {{ ref('risk_assess_risk_profiles') }}

),

renamed as (

    select

        -- ---- keys ---------------------------------------------------------
        cast(risk_profile_id as number(38, 0)) as risk_profile_id,
        cast(customer_id as varchar) as customer_id,
        cast(institution_id as varchar) as institution_id,

        -- ---- dimensions ------------------------------------------------------
        cast(product_type as varchar) as product_type,
        cast(risk_pattern as varchar) as risk_pattern,

        -- ---- clean numeric facts -----------------------------------------------
        cast(base_risk_score as number(9, 4)) as base_risk_score,
        cast(total_exposure as number(18, 2)) as total_exposure,
        cast(relationship_length_months as number(38, 0)) as relationship_length_months,
        cast(products_held as number(38, 0)) as products_held,
        cast(repayment_history_score as number(38, 0)) as repayment_history_score,
        cast(recent_transaction_volatility as number(9, 4)) as recent_transaction_volatility,

        -- ---- text-that-should-be-numeric ------------------------------------------
        -- try_cast, not cast. See the note at the top of this file.
        try_cast(cast(collateral_quality_score as varchar) as number(9, 4)) as collateral_quality_score,
        try_cast(cast(liquidity_ratio as varchar) as number(9, 4)) as liquidity_ratio,
        try_cast(cast(projected_cash_flow_rating as varchar) as number(9, 4)) as projected_cash_flow_rating,

        -- Keeping a flag for "we did not know this" is more useful downstream
        -- than a bare NULL, because it lets a report distinguish "no collateral"
        -- from "collateral not assessed".
        case
            when trim(cast(collateral_quality_score as varchar)) = '' then true
            else false
        end as is_collateral_unassessed,

        -- ---- text left as text -----------------------------------------------------
        cast(primary_risk_factors as varchar) as primary_risk_factors,

        -- risk_factor_weights is a Python-dict-shaped string with single
        -- quotes, so it is not valid JSON and parse_json would fail on it. It
        -- stays as text and is deliberately kept out of the semantic layer.
        cast(risk_factor_weights as varchar) as risk_factor_weights

    from source

)

select * from renamed
