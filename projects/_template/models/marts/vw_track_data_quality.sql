-- ---------------------------------------------------------------------------
-- RENAME THIS FILE to vw_<track_key>_data_quality.sql
--
-- The data-quality scorecard. Every track has one, and it does double duty:
-- it is the model the lab uses to tour dbt Studio and Fusion, and it is where
-- the track's genuine data problems get surfaced instead of hidden.
--
-- BUILD IT FROM STAGING, NOT FROM THE MARTS. Two reasons. It keeps this branch
-- of the DAG independent of the seeded bugs, so it always builds. And some
-- findings are only visible before the marts clean them up: in the energy
-- track, the duplicate maintenance feed disappears after de-duplication.
--
-- Keep the CTEs small and named after what they check. Attendees preview them
-- individually during the Fusion tour, so each one has to make sense alone.
--
-- Three dimensions, each scored out of 100:
--   completeness  are the fields we need populated?
--   validity      are values inside the range the business expects?
--   consistency   do fields that should agree with each other agree?
--
-- Grain: one row per <data_domain or dimension>.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with base as (

    select * from {{ ref('stg_<source_table>') }}

),

-- ---- completeness -----------------------------------------------------------
-- Blank strings count as missing, not just NULLs. The raw feed encodes
-- blanks as an empty string rather than a null.
completeness as (

    select
        <group_column>,
        count(*) as total_rows,
        sum(case when <column> is null or trim(<column>) = '' then 1 else 0 end) as blank_<column>
    from base
    group by <group_column>

),

-- ---- validity ---------------------------------------------------------------
-- Present but outside the range the business defines. A rating of 7 on a 1-5
-- scale is present, and it is not valid.
validity as (

    select
        <group_column>,
        sum(case when <measure> < <min> or <measure> > <max> then 1 else 0 end) as <measure>_out_of_range
    from base
    group by <group_column>

),

-- ---- consistency ---------------------------------------------------------------
-- The interesting ones. Fields that are individually fine and contradict each
-- other. Invisible to a column-by-column check, and exactly what breaks a
-- metric three layers later.
consistency as (

    select
        <group_column>,
        sum(case when <contradiction_condition> then 1 else 0 end) as <finding_name>
    from base
    group by <group_column>

),

scored as (

    select
        completeness.<group_column>,
        completeness.total_rows,

        round(100 - (100.0 * completeness.blank_<column> / nullif(completeness.total_rows * 1, 0)), 2) as completeness_score,
        round(100 - (100.0 * validity.<measure>_out_of_range / nullif(completeness.total_rows * 1, 0)), 2) as validity_score,
        round(100 - (100.0 * consistency.<finding_name> / nullif(completeness.total_rows * 1, 0)), 2) as consistency_score

    from completeness
    inner join validity     on completeness.<group_column> = validity.<group_column>
    inner join consistency  on completeness.<group_column> = consistency.<group_column>

),

final as (

    select
        <group_column>,
        total_rows,
        completeness_score,
        validity_score,
        consistency_score,

        round((completeness_score + validity_score + consistency_score) / 3, 2) as data_quality_score,

        case
            when (completeness_score + validity_score + consistency_score) / 3 >= 95 then 'A'
            when (completeness_score + validity_score + consistency_score) / 3 >= 90 then 'B'
            when (completeness_score + validity_score + consistency_score) / 3 >= 80 then 'C'
            else 'D'
        end as data_quality_grade

    from scored

)

select * from final
order by data_quality_score asc
