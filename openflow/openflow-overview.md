# Openflow: how this pipeline ingests in production

**This lab does not run Openflow live. This page explains what it would do
and why the lab skips that step on purpose.**

---

## What Openflow is

Snowflake Openflow is Snowflake's own managed ingestion service, built on
Apache NiFi. You build a flow on a visual, drag-and-drop canvas out of
processors: connectors for a source (JDBC/Postgres, Kafka, REST APIs, SharePoint,
cloud storage and more) and stages that transform or route data in flight,
before it lands in a Snowflake table or stage. It runs as a managed
deployment, either Snowflake-hosted or bring-your-own-cloud.

Sources:
- [Snowflake Openflow product page](https://www.snowflake.com/en/product/features/openflow/)
- [About Openflow (Snowflake docs)](https://docs.snowflake.com/en/user-guide/data-integration/openflow/about)

`TODO: verify with the Snowflake team.` The two links above describe the
product; nobody on this project has hands-on-verified the current Openflow
console, so exact setup screens, connector names and configuration fields are
not documented here the way `dbt/setup.md` documents dbt platform. If you're
adding a live Openflow walkthrough for a future delivery, that verification
pass is the first thing to do.

---

## What it would do for this lab

If this pipeline ran for real, Openflow is the layer that sits where Fivetran
used to sit in earlier versions of this lab: a PostgreSQL connector polling
the same source database (`industry`, 26 schemas, three of which this lab
uses) and landing raw tables into `HOL_SNOWFLAKE_INDUSTRY`, continuously, with
no code in this repo. Everything downstream — staging, marts, the semantic
layer, dbt Catalog, Snowflake CoWork — is unaffected by which tool does that
landing. That's the point of the architecture: ingestion is a swappable first
stage, not something the rest of the stack has opinions about.

A real Openflow (or any CDC/ingestion) pipeline would also typically add a
load-audit column to every landed table, so you can answer "when did this row
last change" without asking anyone. Earlier versions of this lab used
Fivetran's `_fivetran_synced` column for exactly that teaching beat. This
lab's seeds don't carry an equivalent column, because they're not simulating
a live sync — there's nothing here to say "arrived at 09:14" about. If you
add live Openflow ingestion later, bringing that column (and that beat) back
is a reasonable thing to do.

---

## Why this lab seeds instead

Watching a connector sync is not, in itself, a good use of two hours in a
room. The earlier Fivetran version of this lab already treated the sync as
overlap time — attendees started it and immediately moved on to dbt setup
while it ran in the background — because the actual teaching value was
"raw tables now exist in Snowflake," not "here is what a progress bar looks
like." Openflow doesn't change that calculus; if anything, building a NiFi
flow live has more surface area to go wrong in a room of thirty people than
accepting a Fivetran invite did.

So each industry track ships its raw data as a **dbt seed**
(`projects/<track>/seeds/*.csv`). Running `dbt seed` loads it in seconds, with
no account to provision, no destination schema prefix to type correctly, and
no sync to babysit. That freed time goes to the part of the lab that's
actually new and worth the room's attention: the semantic layer, dbt Catalog,
and Snowflake CoWork.

This is the same design instinct already applied elsewhere in this repo —
see `BUILD-NOTES.md` on why energy's duplicate-feed bug is a deliberate
`dbt_utils.accepted_range` rather than something more elaborate, and why no
track uses macros or incremental models. Cut the setup that doesn't teach
anything; keep the setup that does.

**What you lose, honestly:** attendees don't get to watch their own rows land
in real time, and there's no fallback-schema safety net to talk about,
because there's nothing left that can go wrong on the ingestion side. Both of
those were genuine teaching beats in the Fivetran version. What replaces them
is more time in section 7 (Ask, and act, in English), which is where the
Snowflake CoWork content lives.
