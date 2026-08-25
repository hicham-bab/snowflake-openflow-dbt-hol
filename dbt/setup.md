# dbt platform setup

**Time: 15 minutes, including loading your seed data.**

This is the one setup page you cannot skip. Snowflake has a fallback (use
the shared account); this page doesn't, because if the dbt platform isn't
connected there is no lab.

---

## What you are building

| | |
|---|---|
| An account | Developer seat with dbt Studio, dbt Wizard, jobs and dbt State |
| A connection | dbt platform to Snowflake |
| A project | Pointed at **your fork**, and at **one track folder inside it** |
| A dev environment | Where your `dbt build` runs |
| A production environment | Needed later for the production job and dbt Catalog |

---

## Step 1: create your account (4 min)

Go to `{{DBT_WORKSHOP_URL}}`, or start a standard trial at `getdbt.com`.

Verify your email. You land in a setup wizard; the next three steps follow it.

**Expected result:** you are signed in and looking at a "set up your project"
screen.

---

## Step 2: connect Snowflake (4 min)

| Field | Value |
|---|---|
| Account | `{{SNOWFLAKE_ACCOUNT}}` |
| Database | `HOL_SNOWFLAKE_INDUSTRY` |
| Warehouse | `HOL_DBT_WH` |
| Role | `HOL_DBT` |

Then your **development credentials**, which are personal to you:

| Field | Value |
|---|---|
| Auth method | Key pair, or username and password. On the credentials card |
| Schema | `dbt_<yourfirstname>`, for example `dbt_jane` |

**On the schema:** this is where *your* models get built. Everyone in the room
needs a different one, or you will overwrite each other. Use your first name.

**On the account identifier:** it is not the URL. If Snowsight shows you
`https://abc12345.eu-west-1.snowflakecomputing.com`, the account identifier is
`abc12345.eu-west-1`, not the whole address.

**On key-pair auth:** if the lab uses it, paste the **private** key, including
the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines. People
routinely paste only the middle and then wonder why it fails.

Click **Test connection**.

**Expected result:** a green success message. If it fails, it is almost always
the account identifier format. Check that before anything else.

---

## Step 3: connect your fork (3 min)

Connect GitHub and choose **your fork**, not `hicham-bab/snowflake-openflow-dbt-hol`.

If you pick the original you will be able to read it and unable to commit to
it, and you will not find that out until the very last section of the lab.

**Expected result:** the repository shows as connected, with a green tick.

---

## Step 4: set the project subdirectory (1 min)

**This is the step people miss. Read it even if you are skimming.**

This repo holds three separate dbt projects, one per industry track. The dbt
platform does not know which one is yours until you tell it.

Find the field called **Project subdirectory** and type your track's folder
path into it, exactly:

| If you picked | Type this into **Project subdirectory** |
|---|---|
| Consumer packaged goods | `projects/cpg` |
| Energy | `projects/energy` |
| Financial services | `projects/financial_services` |

**Where the field is:** it appears in the repository step of the setup wizard.
If you have already finished the wizard, go to **Account settings** then
**Projects**, open your project, click **Edit**, and it is under the repository
settings.

**What happens if you skip it:** dbt looks in the repository root, finds no
`dbt_project.yml`, and every single command fails with
`Could not find dbt_project.yml`. Nothing else in the lab works.

You can change it later. If you picked the wrong track, come back here and edit
this one field rather than starting over.

---

## Step 5: create the environments (2 min)

You need two.

**Development.** Usually created for you by the setup wizard. This is what dbt
Studio uses when you click Build. It writes to your personal `dbt_<yourname>`
schema.

**Production.** You need to create this one, and you need it before section 7.

- Environment type: **Deployment**
- Set it as the **production** environment
- Schema: `dbt_prod_<yourfirstname>`

**Why it matters now:** dbt Catalog only shows metadata from a deployment
environment marked production or staging, and only after a job has succeeded
there. If you skip this, section 7 has nothing to look at. Two minutes now
saves the confusion later.

---

## Step 6: open dbt Studio and confirm (1 min)

Open dbt Studio. You should see your track's folder structure: `models/`,
`seeds/`, `tests/`, and a `dbt_project.yml` at the top.

If you see the whole repository instead, with a `projects/` folder and no
`dbt_project.yml` at the top level, your subdirectory is wrong. Go back to
step 4.

Then run:

```bash
dbt deps
```

**Expected result:**

```
Installed 2 packages
```

`dbt_utils` and `Snowflake-Labs/dbt_semantic_view`. If this fails, you are
almost certainly not in the right subdirectory.

---

## You are ready

Go back to your track's guide and continue from section 2.2, where you load
your track's seed data and run your first build.

| Track | Guide |
|---|---|
| Consumer packaged goods | [../docs/attendee-guide-cpg.md](../docs/attendee-guide-cpg.md) |
| Energy | [../docs/attendee-guide-energy.md](../docs/attendee-guide-energy.md) |
| Financial services | [../docs/attendee-guide-financial-services.md](../docs/attendee-guide-financial-services.md) |

---

## Troubleshooting

**"Could not find dbt_project.yml".**
Project subdirectory. Step 4. This accounts for most of the setup failures in
this lab.

**Snowflake connection test fails.**
Account identifier format first. Then role and warehouse: they are `HOL_DBT`
and `HOL_DBT_WH`, and your user needs to have been granted the role. Then, if
the account uses key-pair auth, whether you pasted the full private key
including the header and footer lines.

**"Object does not exist" once you start building.**
Not a connection problem, and not your seed data (it's committed in the repo,
so it's always there). The Snowflake grants on your dev schema are almost
certainly missing. Tell the facilitator — a grants problem affects the whole
room, not just you.

**"No seeds found" on `dbt seed`.**
Same root cause as `dbt_project.yml` not being found: check the project
subdirectory first.

**"Insufficient privileges" when dbt tries to create a schema.**
Your development schema name may collide with someone else's, or the role
cannot create schemas. Change your schema to something unmistakably yours and
try again.

**I cannot commit at the end of the lab.**
You connected the original repository instead of your fork. Step 3.

**dbt Studio is empty or shows the wrong models.**
Wrong subdirectory, or you are on a branch that does not have your changes.
Check step 4 first.
