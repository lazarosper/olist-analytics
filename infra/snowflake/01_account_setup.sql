-- =============================================================================
-- Olist analytics platform: one-off Snowflake account setup (idempotent).
-- Run as a user that can assume SYSADMIN, USERADMIN and SECURITYADMIN
-- (ACCOUNTADMIN inherits all three).  Applied with: python infra/apply_setup.py
--
-- Design (dbt Labs "how we configure Snowflake" pattern):
--   * one warehouse per workload  -> cost attribution + independent sizing
--   * one role per job function   -> least privilege (RBAC)
--   * RAW is shared, ANALYTICS_<ENV> is isolated per environment
-- =============================================================================

-- 1. Warehouses ---------------------------------------------------------------
use role sysadmin;

create warehouse if not exists loading_wh
    warehouse_size = 'xsmall' auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'Ingestion (PUT / COPY INTO)';

create warehouse if not exists transforming_wh
    warehouse_size = 'xsmall' auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'dbt runs (dev, CI and prod)';

create warehouse if not exists reporting_wh
    warehouse_size = 'xsmall' auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'BI tools (Power BI)';

-- 2. Databases ----------------------------------------------------------------
create database if not exists raw comment = 'Bronze: data landed as-is from source systems';
create schema if not exists raw.olist comment = 'Olist e-commerce source system';

create database if not exists analytics_dev  comment = 'Silver + gold: developer sandboxes (one schema prefix per developer)';
create database if not exists analytics_ci   comment = 'Silver + gold: throw-away schemas, one per pull request';
create database if not exists analytics_prod comment = 'Silver + gold: production, the only database BI tools read';

-- 3. Functional roles ---------------------------------------------------------
use role useradmin;

create role if not exists loader      comment = 'Writes raw data. Cannot read analytics.';
create role if not exists transformer comment = 'dbt. Reads RAW, owns everything in ANALYTICS_*.';
create role if not exists reporter    comment = 'BI tools and analysts. Reads marts only, PII is masked.';
create role if not exists pii_reader  comment = 'Reporter + sees unmasked PII. Granted on request only.';

-- 4. Role hierarchy -----------------------------------------------------------
use role securityadmin;

grant role reporter    to role pii_reader;   -- pii_reader = reporter + unmask
grant role loader      to role sysadmin;
grant role transformer to role sysadmin;
grant role pii_reader  to role sysadmin;

-- 5. Privileges ---------------------------------------------------------------
-- loader: only its warehouse and the RAW landing schema
grant usage on warehouse loading_wh to role loader;
grant usage on database raw to role loader;
grant usage, create table, create stage, create file format on schema raw.olist to role loader;

-- transformer: read RAW, build in ANALYTICS_*
grant usage on warehouse transforming_wh to role transformer;
grant usage on database raw to role transformer;
grant usage on schema raw.olist to role transformer;
grant select on all tables    in schema raw.olist to role transformer;
grant select on future tables in schema raw.olist to role transformer;

grant usage, create schema on database analytics_dev  to role transformer;
grant usage, create schema on database analytics_ci   to role transformer;
grant usage, create schema on database analytics_prod to role transformer;

-- transformer may attach the masking policies it creates to the tables it owns
grant apply masking policy on account to role transformer;

-- reporter: its warehouse and the production database only.
-- Schema usage + SELECT on marts are granted by dbt itself (grants config and
-- an on-run-end hook), so access control is versioned with the models.
grant usage on warehouse reporting_wh to role reporter;
grant usage on database analytics_prod to role reporter;
