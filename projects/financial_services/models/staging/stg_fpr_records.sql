-- ---------------------------------------------------------------------------
-- stg_fpr_records
--
-- Financial product recommendations and customer lifecycle. 751 rows.
-- Optional stretch material: not needed to finish the track.
--
-- GOVERNANCE NOTE
-- The source has `customer_name` and `customer_email`. Neither appears below.
-- Same reasoning as stg_loan.sql: nothing downstream needs them, and a column
-- you never selected cannot leak into an AI answer. `customer_id` is enough to
-- join on.
-- ---------------------------------------------------------------------------

{{ config(
    materialized='view',
    tags=['stretch']
) }}

with source as (

    select
        record_id,
        customer_id,
        account_balance,
        customer_segment,
        customer_lifecycle_stage,
        customer_satisfaction_score,
        customer_churn_probability,
        customer_transaction_count,
        customer_transaction_value,
        product_id,
        product_name,
        product_type,
        product_recommendation,
        product_recommendation_status,
        product_recommendation_date,
        recommendation_score,
        product_sales_amount,
        product_sales_date

    from {{ ref('fpr_records') }}

),

renamed as (

    select

        -- ---- keys ---------------------------------------------------------
        cast(record_id as varchar) as recommendation_id,
        cast(customer_id as varchar) as customer_id,
        cast(product_id as varchar) as product_id,

        -- ---- time -----------------------------------------------------------
        cast(product_recommendation_date as date) as recommended_at,
        cast(product_sales_date as date) as sold_at,

        -- ---- product dimensions -----------------------------------------------
        cast(product_name as varchar) as product_name,
        cast(product_type as varchar) as product_type,
        cast(product_recommendation as varchar) as recommended_product,
        cast(product_recommendation_status as varchar) as recommendation_status,

        -- ---- customer dimensions -------------------------------------------------
        cast(customer_segment as varchar) as customer_segment,
        cast(customer_lifecycle_stage as varchar) as customer_lifecycle_stage,

        -- ---- measures ---------------------------------------------------------------
        cast(recommendation_score as number(9, 6)) as recommendation_score,
        cast(account_balance as number(18, 2)) as account_balance,
        cast(customer_satisfaction_score as number(9, 4)) as customer_satisfaction_score,
        cast(customer_churn_probability as number(9, 6)) as customer_churn_probability,
        cast(customer_transaction_count as number(38, 0)) as customer_transaction_count,
        cast(customer_transaction_value as number(18, 2)) as customer_transaction_value,
        cast(product_sales_amount as number(18, 2)) as product_sales_amount,

        -- ---- derived: did the recommendation land ------------------------------------
        -- The source uses six status values for what is really three outcomes.
        -- Collapsing them here means every downstream conversion rate agrees.
        case
            when product_recommendation_status in ('Accepted', 'Approved') then 'Accepted'
            when product_recommendation_status in ('Rejected', 'Declined') then 'Rejected'
            else 'Open'
        end as recommendation_outcome,

        case
            when product_recommendation_status in ('Accepted', 'Approved') then true
            else false
        end as is_accepted

    from source

)

select * from renamed
