-- ---------------------------------------------------------------------------
-- stg_risk_assess_performance_metrics
--
-- Pre-aggregated performance fact, one row per customer, institution and
-- product type. 2,948 rows, the same grain as the risk profiles.
--
-- Note what this table is: numbers somebody else already aggregated. It is
-- convenient and it is also a trap, because nothing in it can be recomputed
-- from the monthly assessments without knowing exactly what window the source
-- used. It is carried through and used, but the mart keeps it in its own
-- columns rather than mixing it with figures this project calculates itself.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    select * from {{ ref('risk_assess_performance_metrics') }}

),

renamed as (

    select

        -- ---- keys ---------------------------------------------------------
        cast(performance_id as number(38, 0)) as performance_id,
        cast(customer_id as varchar) as customer_id,
        cast(institution_id as varchar) as institution_id,
        cast(product_type as varchar) as product_type,

        -- ---- risk ------------------------------------------------------------
        cast(avg_risk_score as number(9, 4)) as avg_risk_score,
        cast(risk_score_volatility as number(9, 4)) as risk_score_volatility,
        cast(risk_trend as varchar) as risk_trend,
        cast(risk_trend_percentage as number(9, 4)) as risk_trend_percentage,
        cast(avg_fraud_probability as number(9, 4)) as avg_fraud_probability,
        cast(anomaly_percentage as number(9, 4)) as anomaly_percentage,
        cast(risk_assessment_accuracy as number(9, 4)) as risk_assessment_accuracy,

        -- ---- decisioning --------------------------------------------------------
        cast(approval_percentage as number(9, 4)) as approval_percentage,
        cast(most_common_recommendation as varchar) as most_common_recommendation,

        -- ---- volume and exposure -------------------------------------------------
        cast(avg_monthly_transaction_volume as number(18, 2)) as avg_monthly_transaction_volume,
        cast(total_transaction_volume as number(18, 2)) as total_transaction_volume,
        cast(transaction_volatility as number(9, 4)) as transaction_volatility,
        cast(total_exposure as number(18, 2)) as total_exposure,

        -- ---- commercial value ------------------------------------------------------
        cast(risk_adjusted_return as number(9, 4)) as risk_adjusted_return,
        cast(customer_value_score as number(38, 0)) as customer_value_score,
        cast(customer_value_category as varchar) as customer_value_category,

        -- ---- next best action --------------------------------------------------------
        cast(optimization_opportunity as varchar) as optimization_opportunity,
        cast(optimization_priority as varchar) as optimization_priority

    from source

)

select * from renamed
