-- ---------------------------------------------------------------------------
-- stg_cpg_records
--
-- One typed, renamed view over the raw seed data. Staging models in this
-- lab do four things and nothing else:
--   1. select explicit columns (never select *)
--   2. cast text columns to real types
--   3. give columns business-readable names
--   4. standardise casing on the low-cardinality text columns
--
-- No joins, no aggregation, no business logic. That happens downstream.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    select
        record_id,
        order_id,
        customer_id,
        product_id,
        order_date,
        order_total,
        product_price,
        inventory_level,
        customer_segment,
        order_status,
        product_category,
        product_subcategory,
        customer_ltv,
        order_frequency,
        average_order_value,
        product_rating,
        product_review_count,
        price_optimization_flag,
        price_elasticity,
        demand_forecast,
        inventory_turnover,
        stockout_rate,
        overstock_rate,
        revenue_growth_rate,
        customer_satisfaction_rate,
        price_optimization_date,
        price_optimization_result,
        price_optimization_recommendation

    from {{ ref('cpg_records') }}

),

renamed as (

    select

        -- ---- identifiers ------------------------------------------------
        cast(record_id as varchar) as record_id,
        cast(order_id as varchar) as order_id,
        cast(customer_id as varchar) as customer_id,
        cast(product_id as varchar) as product_id,

        -- ---- dates -------------------------------------------------------
        -- The source Postgres columns are `text` holding ISO YYYY-MM-DD, so
        -- the seed lands them as VARCHAR. Casting here means every model
        -- downstream gets a real DATE and date maths just works.
        cast(order_date as date) as order_date,
        cast(price_optimization_date as date) as price_optimization_date,

        -- ---- order facts ---------------------------------------------------
        cast(order_total as number(18, 2)) as order_total,
        cast(average_order_value as number(18, 2)) as modelled_average_order_value,
        cast(order_frequency as number(38, 0)) as order_frequency,

        -- ---- product facts -------------------------------------------------
        cast(product_price as number(18, 2)) as product_price,
        cast(product_rating as number(9, 4)) as product_rating,
        cast(product_review_count as number(38, 0)) as product_review_count,

        -- ---- customer facts ------------------------------------------------
        cast(customer_ltv as number(18, 2)) as customer_lifetime_value,
        cast(customer_satisfaction_rate as number(9, 6)) as customer_satisfaction_rate,

        -- ---- inventory facts -----------------------------------------------
        cast(inventory_level as number(38, 0)) as inventory_level,
        cast(demand_forecast as number(38, 0)) as demand_forecast,
        cast(inventory_turnover as number(9, 4)) as inventory_turnover,
        cast(stockout_rate as number(9, 6)) as stockout_rate,
        cast(overstock_rate as number(9, 6)) as overstock_rate,

        -- ---- pricing facts ---------------------------------------------------
        cast(price_elasticity as number(9, 4)) as price_elasticity,
        cast(revenue_growth_rate as number(9, 6)) as revenue_growth_rate,

        -- The raw column is the string 'TRUE' / 'FALSE', not a boolean.
        -- upper() first so a stray 'true' still converts correctly.
        case
            when upper(cast(price_optimization_flag as varchar)) = 'TRUE' then true
            else false
        end as is_price_optimized,

        -- ---- descriptive text ------------------------------------------------
        -- initcap() standardises casing so 'delivered' and 'Delivered' group
        -- together in every downstream mart.
        initcap(cast(order_status as varchar)) as order_status,
        initcap(cast(customer_segment as varchar)) as customer_segment,
        initcap(cast(product_category as varchar)) as product_category,
        initcap(cast(product_subcategory as varchar)) as product_subcategory,
        cast(price_optimization_result as varchar) as price_optimization_result,
        cast(price_optimization_recommendation as varchar) as price_optimization_recommendation

    from source

)

select * from renamed
