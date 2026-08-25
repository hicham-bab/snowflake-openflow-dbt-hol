-- ---------------------------------------------------------------------------
-- RENAME THIS FILE to sv_<track_key>_<subject>.sql
--
-- A Snowflake Semantic View, defined as a dbt model. One of the two ways this
-- lab defines meaning; the other is models/semantic/<track_key>.yml.
--
-- The `semantic_view` materialization comes from the Snowflake-Labs
-- dbt_semantic_view package and is a direct passthrough to Snowflake's
-- CREATE SEMANTIC VIEW syntax:
-- https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view
--
-- ONE SEMANTIC VIEW PER SUBJECT AREA, not one per track. If your track has two
-- subject areas with no key in common, give them one object each. Forcing them
-- together hands Cortex Analyst a join it cannot make. The energy track does
-- exactly this and it is the honest shape.
--
-- FACTS are row-level expressions. METRICS are aggregations over those facts.
-- DIMENSIONS are what you group by.
--
-- SYNONYMS AND COMMENTS ARE NOT DECORATION. They are what Cortex Analyst reads
-- to map plain English onto the right column. If two metrics could plausibly
-- both be called "revenue", say in the comment which one is meant.
-- ---------------------------------------------------------------------------

{{ config(materialized='semantic_view') }}

TABLES (

    <alias> AS {{ ref('<track_key>_<subject>') }}
        PRIMARY KEY (<key_column>)
        WITH SYNONYMS = ('<what people call this>', '<and this>')
        COMMENT = '<One line: what one row is.>'

    -- Add a second logical table and a RELATIONSHIPS block only if the two
    -- genuinely share a key:
    --
    -- , <alias_2> AS {{ ref('<other_mart>') }}
    --     PRIMARY KEY (<key_column>)
    --     COMMENT = '...'

)

-- RELATIONSHIPS (
--     <name> AS <alias> (<key>) REFERENCES <alias_2> (<key>)
-- )

FACTS (

    <alias>.<fact_name> AS <alias>.<column>
        COMMENT = '<What this is, and its units or range.>',

    -- Flags become facts so they can be summed into rates.
    <alias>.<flag_name> AS CASE WHEN <alias>.<boolean_column> THEN 1 ELSE 0 END
        COMMENT = 'One when <...>, otherwise zero.'

)

DIMENSIONS (

    <alias>.<dimension_name> AS <alias>.<column>
        WITH SYNONYMS = ('<what people call this>', '<and this>')
        COMMENT = '<The values it can take.>'

)

METRICS (

    <alias>.<metric_name> AS SUM(<alias>.<fact_name>)
        WITH SYNONYMS = ('<what people ask for>', '<and this>')
        COMMENT = '<Exactly what this counts, and what it excludes.>',

    -- Rates: always NULLIF the denominator.
    <alias>.<rate_name> AS SUM(<alias>.<flag_name>) / NULLIF(COUNT(<alias>.<key_column>), 0)
        WITH SYNONYMS = ('<rate>', '<share of>')
        COMMENT = '<Share of ..., 0 to 1.>'

)

COMMENT = '<Subject area> for the <track name> track of the Openflow, Snowflake and dbt hands-on lab.'
