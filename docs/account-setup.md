# Account setup

**Time: 10 minutes, done in the first block of the lab.**

You need two accounts. Both are created on the day, and both have a fallback
if provisioning does not work. Read the fallback column before you start
panicking about a missing email.

**This page covers signing up.** The step-by-step setup for each tool lives
with that tool:

| Tool | Full setup guide |
|---|---|
| **dbt platform** | **[../dbt/setup.md](../dbt/setup.md)** |
| Snowflake | admin-owned, see [../snowflake/GOTCHAS.md](../snowflake/GOTCHAS.md) |

There's no third account to set up for ingestion. In production this
pipeline would land raw data with **Openflow**; this lab loads the same raw
data as a `dbt seed` instead, so there's no separate tool or invite to wait
on. See [../openflow/openflow-overview.md](../openflow/openflow-overview.md)
for why.

---

## Placeholders the instructor fills in

Everything in `{{DOUBLE_BRACES}}` is supplied on the day, on the lab
credentials card. None of it is in this repo, deliberately: the repo is public
and gets forked.

| Placeholder | What it is |
|---|---|
| `{{DBT_WORKSHOP_URL}}` | dbt platform workshop signup URL |
| `{{LAB_CREDENTIALS_URL}}` | The credentials card, holding everything below |
| `{{PASSCODE}}` | Passcode for the credentials card |
| `{{SNOWFLAKE_ACCOUNT}}` | Snowflake account identifier for the dbt connection |

---

## 1. dbt platform

| | |
|---|---|
| **How** | `{{DBT_WORKSHOP_URL}}`, or a standard trial at `getdbt.com` |
| **What you get** | A developer seat with dbt Studio, dbt Wizard, job scheduling and dbt State. Enough for everything in this lab |
| **Time to provision** | 3 to 5 minutes including email verification |
| **You will need** | Your forked repo URL, and Snowflake connection details from the credentials card |

**Full walkthrough: [../dbt/setup.md](../dbt/setup.md).** The summary:

1. Create the account and verify your email.
2. **Connect Snowflake.** Account identifier `{{SNOWFLAKE_ACCOUNT}}`, database
   `HOL_SNOWFLAKE_INDUSTRY`, warehouse `HOL_DBT_WH`. Credentials are on the
   card.
3. **Connect your fork.** Not the original repo, your fork, or you will not be
   able to commit.
4. **Set the project subdirectory** to your track: `projects/cpg`,
   `projects/energy` or `projects/financial_services`. This is the step people
   miss, and the symptom is dbt reporting that it cannot find
   `dbt_project.yml` (and, downstream of that, `dbt seed` finding nothing to
   load).
5. **Create a production deployment environment.** You need it for the
   production job and for dbt Catalog later. Two minutes now, or confusion at
   the Catalog section.
6. **Run `dbt seed`.** Loads your track's raw data in seconds. No account,
   no sync, nothing to wait on.

**Fallback:** the instructor has a shared account with pre-created developer
seats. Ask. There may also be a pre-configured workstation at the front of the
room.

---

## 2. Snowflake

| | |
|---|---|
| **How** | Usually supplied by the instructor. If you are creating your own, `signup.snowflake.com` |
| **What you get** | Read access to the lab database, and access to Snowflake CoWork |
| **Time to provision** | Instant if supplied. 5 to 10 minutes for a self-service trial, plus email verification |

**If you are creating your own trial, pick your region deliberately.** Cortex
models are not available everywhere, and a trial that lands in the wrong region
cannot run the consumption section of the lab. Ask the instructor which region
to choose before you click.

**Fallback:** use the shared lab Snowflake account from the credentials card.
For the consumption section this is genuinely the better option anyway, because
the agents are already built there.

---

## Quick check before you start

| | Check | If not |
|---|---|---|
| [ ] | Forked the repo to your own GitHub account | Fork it now. Do not clone the original |
| [ ] | Picked a track | Consumer packaged goods if you are unsure |
| [ ] | dbt platform connected to Snowflake **and** your fork | Ask. This one is worth stopping for |
| [ ] | Project subdirectory set to your track folder | Fix it now, nothing works without it |
| [ ] | `dbt seed` has run | If it found nothing, it's the project subdirectory, not your data |
| [ ] | Can sign in to Snowsight | Use the shared account |

The only one worth blocking on is the dbt platform connection. Everything else
has a fallback that costs you nothing.

---

## Common problems

**"dbt cannot find dbt_project.yml".**
The project subdirectory is not set, or is set to the repo root. It needs to be
`projects/<your track>`.

**"No seeds found" on `dbt seed`.**
Same cause as above — check the project subdirectory first.

**"Object does not exist" when dbt reads a seed table.**
The Snowflake grants are probably missing on your dev schema. Tell the
facilitator, because a grants problem affects everyone, not just you.

**Snowflake connection test fails in the dbt platform.**
Check the account identifier format. It is not the URL. If the account uses
key-pair authentication, you need the private key, not a password, and it must
be pasted including the `-----BEGIN PRIVATE KEY-----` and
`-----END PRIVATE KEY-----` lines.

**Cortex or Snowflake CoWork is not available.**
Region problem, almost certainly, if you created your own trial. Switch to the
shared lab account.

**I broke something and don't know how to undo it.**
Re-fork `github.com/hicham-bab/snowflake-openflow-dbt-hol` (or the
instructor's fork, if they've fixed something) and set up again. Your seed
data ships in the repo, so a fresh fork is a fresh start — under a minute,
and nothing else in the lab needs to change.
