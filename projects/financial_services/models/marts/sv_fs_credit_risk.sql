-- ---------------------------------------------------------------------------
-- sv_fs_credit_risk
--
-- A Snowflake Semantic View over the credit risk star.
--
-- Two logical tables, joined on the relationship key: the monthly time series
-- and the relationship summary that carries the conformed dimensions. That
-- join is what lets Cortex Analyst answer "how did risk trend for high net
-- worth customers at credit unions in the Midwest" without anyone writing SQL.
--
-- Governance note. Every column exposed here comes from a mart with an
-- enforced contract, and no personal data reaches either of those marts. That
-- is not a coincidence, it is the design: an AI agent will describe whatever
-- it is given, so the control has to sit upstream of the semantic layer, not
-- inside it. See models/staging/stg_loan.sql.
--
-- Compare with the `semantic_model:` and `metrics:` blocks in
-- _financial_services__marts.yml, which express the same ideas as dbt Semantic
-- Layer (MetricFlow) specs.
-- ---------------------------------------------------------------------------

{{ config(materialized='semantic_view') }}

TABLES (

    monthly AS {{ ref('fs_monthly_risk_assessment') }}
        PRIMARY KEY (assessment_id)
        WITH SYNONYMS = ('monthly risk', 'risk over time', 'assessments', 'risk history')
        COMMENT = 'One row per customer, institution and month. 2022-01 to 2024-11.',

    relationships AS {{ ref('fs_risk_relationship_summary') }}
        PRIMARY KEY (customer_id, institution_id)
        WITH SYNONYMS = ('relationships', 'portfolio', 'customer book', 'exposures')
        COMMENT = 'One row per customer and institution relationship, with both conformed dimensions.'

)

RELATIONSHIPS (

    monthly_to_relationship AS
        monthly (customer_id, institution_id) REFERENCES relationships (customer_id, institution_id)

)

FACTS (

    -- ---- monthly facts ------------------------------------------------------
    monthly.month_risk_score AS monthly.current_risk_score
        COMMENT = 'Risk score for the month, 0 to 1. Higher is riskier.',

    monthly.month_risk_change AS monthly.risk_change_from_previous
        COMMENT = 'Change in risk score since the previous month. Null on the first month of a relationship.',

    monthly.month_fraud_probability AS monthly.fraud_probability
        COMMENT = 'Modelled probability of fraud for the month, 0 to 1.',

    monthly.month_approval_confidence AS monthly.approval_confidence
        COMMENT = 'Confidence in the approval recommendation, 0 to 1.',

    monthly.month_transaction_volume AS monthly.monthly_transaction_volume
        COMMENT = 'Transaction volume for the month in USD.',

    monthly.month_transaction_count AS monthly.transaction_count
        COMMENT = 'Number of transactions in the month.',

    monthly.anomaly_flag AS CASE WHEN monthly.is_anomaly THEN 1 ELSE 0 END
        COMMENT = 'One when the month was flagged as anomalous, otherwise zero.',

    monthly.denial_flag AS CASE WHEN monthly.is_denied THEN 1 ELSE 0 END
        COMMENT = 'One when the recommendation for the month was Deny, otherwise zero.',

    monthly.deterioration_flag AS CASE WHEN monthly.is_material_deterioration THEN 1 ELSE 0 END
        COMMENT = 'One when risk worsened by 0.10 or more that month, otherwise zero.',

    -- ---- relationship facts --------------------------------------------------
    relationships.relationship_exposure AS relationships.total_exposure
        COMMENT = 'Total exposure on the relationship in USD.',

    relationships.relationship_risk_weighted_exposure AS relationships.risk_weighted_exposure
        COMMENT = 'Exposure multiplied by the base risk score.',

    relationships.relationship_base_risk AS relationships.base_risk_score
        COMMENT = 'Baseline risk score for the relationship, 0 to 1.',

    relationships.relationship_credit_score AS relationships.credit_score
        COMMENT = 'Customer credit score, 303 to 850.',

    relationships.relationship_dti AS relationships.debt_to_income_ratio
        COMMENT = 'Customer debt-to-income ratio, 0.1 to 0.6.',

    relationships.relationship_risk_adjusted_return AS relationships.risk_adjusted_return
        COMMENT = 'Return on the relationship adjusted for risk.',

    relationships.relationship_customer_value AS relationships.customer_value_score
        COMMENT = 'Composite customer value score, 18 to 161.',

    relationships.relationship_volatility AS relationships.risk_score_volatility
        COMMENT = 'Standard deviation of the risk score over the period.'

)

DIMENSIONS (

    -- ---- time ----------------------------------------------------------------
    monthly.assessment_date AS monthly.assessment_date
        WITH SYNONYMS = ('date', 'month', 'when', 'assessment date')
        COMMENT = 'Assessment date. The series runs 2022-01-01 to 2024-11-16.',

    monthly.assessment_year AS monthly.assessment_year
        WITH SYNONYMS = ('year')
        COMMENT = 'Calendar year of the assessment, 2022 to 2024.',

    -- ---- monthly risk dimensions -----------------------------------------------
    monthly.risk_level AS monthly.risk_level
        WITH SYNONYMS = ('risk level', 'risk category', 'how risky')
        COMMENT = 'Very Low, Low, Moderate, High or Very High, for that month.',

    monthly.anomaly_type AS monthly.anomaly_type
        WITH SYNONYMS = ('anomaly', 'anomaly type', 'what went wrong')
        COMMENT = 'None, Fraud Alert, Unusual Transaction Pattern, Sudden Risk Change, Credit Report Change or Market Event Impact.',

    monthly.approval_recommendation AS monthly.approval_recommendation
        WITH SYNONYMS = ('recommendation', 'decision', 'approval', 'outcome')
        COMMENT = 'Approve, Approve with Conditions, Approve with Strict Conditions or Deny.',

    -- ---- customer dimensions ------------------------------------------------------
    relationships.customer_segment AS relationships.customer_segment
        WITH SYNONYMS = ('segment', 'customer segment', 'customer type')
        COMMENT = 'Retail, Small Business, Corporate, High Net Worth or Institutional.',

    relationships.income_bracket AS relationships.income_bracket
        WITH SYNONYMS = ('income bracket', 'income band', 'wealth band')
        COMMENT = 'Low, Lower-Middle, Middle, Upper-Middle, High or Ultra-High.',

    relationships.credit_score_range AS relationships.credit_score_range
        WITH SYNONYMS = ('credit band', 'credit score range', 'credit quality')
        COMMENT = 'Poor, Fair, Good, Very Good or Excellent, with the score band.',

    relationships.education_level AS relationships.education_level
        WITH SYNONYMS = ('education', 'education level')
        COMMENT = 'Highest education level attained by the customer.',

    relationships.employment_sector AS relationships.employment_sector
        WITH SYNONYMS = ('sector', 'industry', 'employment sector')
        COMMENT = 'Sector the customer works in.',

    -- ---- institution dimensions ---------------------------------------------------
    relationships.institution_type AS relationships.institution_type
        WITH SYNONYMS = ('institution type', 'bank type', 'lender type')
        COMMENT = 'Commercial Bank, Investment Bank, Credit Union, Asset Manager or Insurance Company.',

    relationships.institution_size AS relationships.institution_size
        WITH SYNONYMS = ('institution size', 'bank size', 'lender size')
        COMMENT = 'Small, Medium, Large or Global.',

    relationships.region AS relationships.region
        WITH SYNONYMS = ('region', 'geography', 'where')
        COMMENT = 'Northeast, Southeast, Midwest, Southwest, West or International.',

    relationships.regulatory_rating AS relationships.regulatory_rating
        WITH SYNONYMS = ('regulatory rating', 'supervisory rating')
        COMMENT = 'Regulatory rating, 1 is best and 5 is worst.',

    relationships.risk_appetite_band AS relationships.risk_appetite_band
        WITH SYNONYMS = ('risk appetite', 'appetite', 'how much risk they take')
        COMMENT = 'Conservative, Balanced or Aggressive.',

    relationships.primary_risk_model AS relationships.primary_risk_model
        WITH SYNONYMS = ('risk model', 'scoring model', 'methodology')
        COMMENT = 'Traditional Credit Model, Market Risk Model, Behavioral Analysis, Hybrid Approach or ML-Based Scoring.',

    -- ---- relationship dimensions ------------------------------------------------------
    relationships.product_type AS relationships.product_type
        WITH SYNONYMS = ('product', 'product type', 'what they hold')
        COMMENT = 'Personal Loan, Business Loan, Mortgage, Credit Card, Investment Portfolio or Insurance Policy.',

    relationships.risk_tier AS relationships.risk_tier
        WITH SYNONYMS = ('risk tier', 'risk band', 'tier')
        COMMENT = 'Very Low, Low, Moderate, High or Very High, from the baseline score.',

    relationships.exposure_band AS relationships.exposure_band
        WITH SYNONYMS = ('exposure band', 'size of exposure', 'ticket size')
        COMMENT = 'Under 10K, 10K to 100K, 100K to 1M, or Over 1M.',

    relationships.relationship_stage AS relationships.relationship_stage
        WITH SYNONYMS = ('tenure', 'relationship stage', 'how long a customer')
        COMMENT = 'New (under 2 years), Developing (2 to 5) or Established (5 years or more).',

    relationships.risk_pattern AS relationships.risk_pattern
        WITH SYNONYMS = ('risk pattern', 'behaviour', 'trajectory')
        COMMENT = 'Steady-Low, Steady-Moderate, Improving, Cyclical, Volatile-Improving or Volatile-Deteriorating.',

    relationships.customer_value_category AS relationships.customer_value_category
        WITH SYNONYMS = ('customer value', 'value tier', 'how valuable')
        COMMENT = 'Value tier derived from the composite customer value score.'

)

METRICS (

    -- ---- monthly risk metrics ------------------------------------------------
    monthly.average_risk_score AS AVG(monthly.month_risk_score)
        WITH SYNONYMS = ('average risk score', 'risk score', 'mean risk')
        COMMENT = 'Average monthly risk score, 0 to 1. Higher is riskier.',

    monthly.risk_score_volatility AS STDDEV(monthly.month_risk_score)
        WITH SYNONYMS = ('risk volatility', 'how volatile is risk', 'risk score volatility')
        COMMENT = 'Standard deviation of the monthly risk score.',

    monthly.average_fraud_probability AS AVG(monthly.month_fraud_probability)
        WITH SYNONYMS = ('fraud probability', 'fraud risk', 'average fraud probability')
        COMMENT = 'Average modelled probability of fraud, 0 to 1.',

    monthly.average_risk_change AS AVG(monthly.month_risk_change)
        WITH SYNONYMS = ('risk change', 'how much risk moved', 'average risk change')
        COMMENT = 'Average month-on-month change in risk score. First months are excluded.',

    monthly.anomaly_rate AS SUM(monthly.anomaly_flag) / NULLIF(COUNT(monthly.assessment_id), 0)
        WITH SYNONYMS = ('anomaly rate', 'share flagged', 'how often anomalous')
        COMMENT = 'Share of monthly assessments flagged as anomalous, 0 to 1.',

    monthly.denial_rate AS SUM(monthly.denial_flag) / NULLIF(COUNT(monthly.assessment_id), 0)
        WITH SYNONYMS = ('denial rate', 'rejection rate', 'how often denied')
        COMMENT = 'Share of monthly assessments recommending Deny, 0 to 1.',

    monthly.approval_rate AS 1 - (SUM(monthly.denial_flag) / NULLIF(COUNT(monthly.assessment_id), 0))
        WITH SYNONYMS = ('approval rate', 'how often approved', 'acceptance rate')
        COMMENT = 'Share of monthly assessments recommending any form of approval, 0 to 1.',

    monthly.deterioration_rate AS SUM(monthly.deterioration_flag) / NULLIF(COUNT(monthly.assessment_id), 0)
        WITH SYNONYMS = ('deterioration rate', 'how often risk worsened')
        COMMENT = 'Share of months where risk worsened by 0.10 or more, 0 to 1.',

    monthly.total_transaction_volume AS SUM(monthly.month_transaction_volume)
        WITH SYNONYMS = ('transaction volume', 'volume', 'total volume')
        COMMENT = 'Total transaction volume in USD.',

    monthly.assessment_count AS COUNT(monthly.assessment_id)
        WITH SYNONYMS = ('number of assessments', 'how many assessments', 'observations')
        COMMENT = 'Number of monthly assessments.',

    -- ---- relationship metrics --------------------------------------------------
    relationships.total_exposure AS SUM(relationships.relationship_exposure)
        WITH SYNONYMS = ('total exposure', 'exposure', 'how much at stake')
        COMMENT = 'Total exposure across relationships in USD.',

    relationships.average_exposure AS AVG(relationships.relationship_exposure)
        WITH SYNONYMS = ('average exposure', 'typical exposure', 'average ticket')
        COMMENT = 'Average exposure per relationship in USD.',

    relationships.total_risk_weighted_exposure AS SUM(relationships.relationship_risk_weighted_exposure)
        WITH SYNONYMS = ('risk weighted exposure', 'RWE', 'exposure at risk')
        COMMENT = 'Total exposure weighted by baseline risk score. The headline capital-at-risk figure.',

    relationships.average_credit_score AS AVG(relationships.relationship_credit_score)
        WITH SYNONYMS = ('average credit score', 'credit score', 'FICO')
        COMMENT = 'Average customer credit score.',

    relationships.average_debt_to_income AS AVG(relationships.relationship_dti)
        WITH SYNONYMS = ('DTI', 'debt to income', 'average debt to income')
        COMMENT = 'Average customer debt-to-income ratio.',

    relationships.average_risk_adjusted_return AS AVG(relationships.relationship_risk_adjusted_return)
        WITH SYNONYMS = ('risk adjusted return', 'RAROC', 'return')
        COMMENT = 'Average return on the relationship adjusted for risk.',

    relationships.average_customer_value_score AS AVG(relationships.relationship_customer_value)
        WITH SYNONYMS = ('customer value', 'average customer value score', 'how valuable')
        COMMENT = 'Average composite customer value score.',

    relationships.relationship_count AS COUNT(relationships.risk_profile_id)
        WITH SYNONYMS = ('number of relationships', 'how many customers', 'portfolio size')
        COMMENT = 'Number of customer and institution relationships.'

)

COMMENT = 'Credit risk across customers, institutions and time, for the financial services track of the Openflow, Snowflake and dbt hands-on lab. Contains no personal data by design.'
