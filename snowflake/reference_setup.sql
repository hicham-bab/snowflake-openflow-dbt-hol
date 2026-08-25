-- ===========================================================================
-- Reference setup for the Snowflake and dbt hands-on lab
--
-- THIS IS A REFERENCE, NOT A SCRIPT TO RUN BLIND.
--
-- It is owned and adapted by the Snowflake team. Names, sizes and grant model
-- will all differ depending on the account. Read it, take what applies, and
-- read snowflake/GOTCHAS.md, which is where the actual value is. This file
-- creates objects; that file explains the four or five things that will
-- otherwise break the lab.
--
-- Idempotent: every statement is IF NOT EXISTS or OR REPLACE-safe, so it can
-- be re-run while you iterate.
--
-- Sized for roughly 30 attendees, three tracks, a two-hour session. Raw data
-- ships as a dbt seed per track, not a live ingestion connector — see
-- ../openflow/openflow-overview.md for what a production pipeline would use
-- instead (Openflow) and why this lab doesn't run that live.
-- ===========================================================================

USE ROLE ACCOUNTADMIN;


-- ---------------------------------------------------------------------------
-- 1. Database
--
-- One database holds everything: the dbt development schemas (one per
-- attendee per track) and the dbt-built marts and semantic views.
-- ---------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS HOL_SNOWFLAKE_INDUSTRY
  COMMENT = 'Snowflake + dbt hands-on lab. Safe to drop after the session.';


-- ---------------------------------------------------------------------------
-- 2. Warehouse
--
-- One is enough. There's no separate ingestion warehouse this time: raw data
-- loads via `dbt seed` on the same warehouse dbt already uses, and the
-- largest seed table in the lab is roughly 25k rows.
-- ---------------------------------------------------------------------------

CREATE WAREHOUSE IF NOT EXISTS HOL_DBT_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'dbt seeds, builds and attendee queries.';


-- ---------------------------------------------------------------------------
-- 3. Roles
-- ---------------------------------------------------------------------------

CREATE ROLE IF NOT EXISTS HOL_DBT
  COMMENT = 'dbt platform role. Seeds raw data, writes marts and semantic views.';

CREATE ROLE IF NOT EXISTS HOL_ATTENDEE
  COMMENT = 'Attendee role for Snowsight and Snowflake CoWork. Read-only on data.';

GRANT ROLE HOL_DBT      TO ROLE SYSADMIN;
GRANT ROLE HOL_ATTENDEE TO ROLE SYSADMIN;


-- ---------------------------------------------------------------------------
-- 4. Service user
--
-- KEY-PAIR AUTHENTICATION, NOT PASSWORDS. This is not a preference.
--
-- Snowflake is in the final phase (August to October 2026) of blocking
-- single-factor password sign-ins. TYPE = SERVICE blocks password auth
-- outright, and TYPE = LEGACY_SERVICE can no longer be created. A
-- password-only service user will fail. See GOTCHAS.md section 1.
--
-- Generate the keys first:
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out dbt_key.p8 -nocrypt
--   openssl rsa -in dbt_key.p8 -pubout -out dbt_key.pub
--
-- Then paste the .pub body below with the BEGIN/END lines and all newlines
-- removed. Load the matching .p8 private key into the dbt platform.
-- ---------------------------------------------------------------------------

CREATE USER IF NOT EXISTS DBT_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = HOL_DBT
  DEFAULT_WAREHOUSE = HOL_DBT_WH
  RSA_PUBLIC_KEY = '<<PASTE DBT_SVC PUBLIC KEY BODY>>'
  COMMENT = 'dbt platform service user. Key-pair auth only.';

GRANT ROLE HOL_DBT TO USER DBT_SVC;


-- ---------------------------------------------------------------------------
-- 5. Warehouse and database grants
-- ---------------------------------------------------------------------------

GRANT USAGE ON WAREHOUSE HOL_DBT_WH TO ROLE HOL_DBT;
GRANT USAGE ON WAREHOUSE HOL_DBT_WH TO ROLE HOL_ATTENDEE;

GRANT USAGE ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT USAGE ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;

-- dbt creates a development schema per attendee, plus the target schema.
GRANT CREATE SCHEMA ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;


-- ---------------------------------------------------------------------------
-- 6. THE GRANTS THAT ACTUALLY BREAK THE LAB
--
-- Each attendee's dbt platform project creates its own development schema on
-- first build (and a production schema later). Without future grants,
-- HOL_ATTENDEE can't see a schema dbt hasn't created yet, and the error tells
-- you nothing useful. Without grants on existing objects as well, schemas dbt
-- already created stay invisible, because future grants are not retroactive.
--
-- You need both halves. See GOTCHAS.md section 2.
-- ---------------------------------------------------------------------------

-- Future objects
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON FUTURE TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;

-- Existing objects
GRANT USAGE  ON ALL SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON ALL TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON ALL VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;

-- Check for schema-level future grants that would shadow the database-level
-- ones above. More specific wins, and it wins silently.
SHOW FUTURE GRANTS IN DATABASE HOL_SNOWFLAKE_INDUSTRY;


-- ---------------------------------------------------------------------------
-- 7. Cortex
--
-- Three things must be true before Cortex Analyst answers anything: the role,
-- the region, and Snowflake CoWork being switched on. Trial accounts
-- routinely fail the second. See GOTCHAS.md section 5.
-- ---------------------------------------------------------------------------

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE HOL_ATTENDEE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE HOL_DBT;

-- Only if the account region lacks the required models. ACCOUNTADMIN only,
-- account level only. Note the parameter name: CORTEX_ENABLED_CROSS_REGION.
-- Be deliberate: this sends inference outside the home geography.
-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';


-- ---------------------------------------------------------------------------
-- 8. Attendee users
--
-- Human users, so MFA applies. If attendees are using their own Snowflake
-- trial accounts instead, skip this section entirely.
--
-- Adapt the loop by hand or generate it; Snowflake has no CREATE USER loop.
-- ---------------------------------------------------------------------------

-- CREATE USER IF NOT EXISTS jane_doe
--   TYPE = PERSON
--   DEFAULT_ROLE = HOL_ATTENDEE
--   DEFAULT_WAREHOUSE = HOL_DBT_WH
--   MUST_CHANGE_PASSWORD = TRUE
--   PASSWORD = '<<one-time>>';
-- GRANT ROLE HOL_ATTENDEE TO USER jane_doe;


-- ---------------------------------------------------------------------------
-- 9. RUN THIS AFTER THE FIRST dbt JOB, NOT BEFORE
--
-- dbt creates the marts and the Semantic Views. They do not exist yet when
-- this file is first run, and Cortex Analyst cannot read what it has not been
-- granted. Substitute the dbt target schema.
--
-- Note the rebuild trap: CREATE OR REPLACE SEMANTIC VIEW drops the object and
-- every grant on it. Either set create_or_alter=true in the dbt model config,
-- or re-run these grants after each job. See GOTCHAS.md section 6.
-- ---------------------------------------------------------------------------

-- SET dbt_schema = 'dbt_hicham';
--
-- GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
--
-- GRANT SELECT ON ALL TABLES          IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON ALL VIEWS           IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON ALL SEMANTIC VIEWS  IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
--
-- GRANT SELECT ON FUTURE TABLES         IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON FUTURE VIEWS          IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;


-- ---------------------------------------------------------------------------
-- 10. Verification
--
-- Run these AS THE TARGET ROLE. Running them as ACCOUNTADMIN proves nothing:
-- ACCOUNTADMIN can see everything and will happily tell you the lab is fine.
--
-- These queries assume dbt has already run `dbt seed` and `dbt build` in
-- some attendee's (or your own test) schema — there's no pre-populated
-- fallback schema anymore, because raw data ships in the repo as a seed and
-- every fork already has it.
-- ---------------------------------------------------------------------------

-- USE ROLE HOL_DBT;
-- USE WAREHOUSE HOL_DBT_WH;
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.dbt_hicham.stg_cpg_records;                       -- expect 750
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.dbt_hicham.stg_commodity_prices;                  -- expect 5898
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.dbt_hicham.stg_risk_assess_monthly_assessments;    -- expect 25200

-- USE ROLE HOL_ATTENDEE;
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.dbt_hicham.stg_fts_records;                       -- expect 750


-- ---------------------------------------------------------------------------
-- 11. Teardown
-- ---------------------------------------------------------------------------

-- ALTER WAREHOUSE HOL_DBT_WH SUSPEND;
-- DROP DATABASE IF EXISTS HOL_SNOWFLAKE_INDUSTRY;
-- DROP WAREHOUSE IF EXISTS HOL_DBT_WH;
-- DROP USER IF EXISTS DBT_SVC;
-- DROP ROLE IF EXISTS HOL_DBT;
-- DROP ROLE IF EXISTS HOL_ATTENDEE;
