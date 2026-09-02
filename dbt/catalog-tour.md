# dbt Catalog: the metadata the agent will use

**Time: 8 minutes. Do this after your production job has run, and before you
ask an AI anything.**

This section exists because of one fact that is easy to miss:

> **dbt Catalog and the dbt MCP Server read the same metadata, through the same
> Discovery API.**

Catalog is that metadata rendered for a human. The MCP Server is that metadata
handed to an agent. So the fastest way to answer "what will the AI actually
know about my data?" is to open Catalog and look.

Everything you are about to see, an agent can see. Everything missing here is
missing for the agent too.

---

## Before you start

Catalog needs three things, and the third is the one people miss:

1. A dbt account on Starter, Enterprise or Enterprise+
2. A **deployment environment marked as production or staging**
3. **At least one successful job run in that environment**

A CI job does not count; it does not update Catalog. If you followed
[setup.md](setup.md) step 5 and ran the production job in section 6, you are
covered.

**The job command matters too.** Catalog builds different metadata from
different commands:

| Command | What it gives Catalog |
|---|---|
| `dbt run` or `dbt build` | models, lineage, run results |
| `dbt docs generate` | column names, data types, descriptions |
| `dbt test` or `dbt build` | data test results |
| `dbt source freshness` | source freshness |

`dbt docs generate` on its own does **not** create model entries. It only
enriches models that a run already put there. That is why the production job
in section 6 runs `dbt build` **and then** `dbt docs generate` as a second
command: either one alone gives you a half-empty Catalog. (On Fusion, there is
no "generate docs on run" checkbox — that toggle only exists for dbt Core
jobs — so the second command has to be added explicitly.)

---

## The tour

Open **Catalog** from the top navigation in the dbt platform.

### 1. The overview: what you built (1 min)

You should see every resource in your track: staging models, intermediate
models, marts, the semantic view, tests, and your sources.

Use the left sidebar to switch between three ways of looking at the same thing:

- **Resources**, grouped by type
- **File tree**, matching the repo you have been editing
- **Database**, matching how it actually landed in Snowflake

That third one is worth ten seconds. It is the same project seen from the
warehouse's point of view, and it is how you answer "where did this table
actually go".

### 2. Lineage: the shape of your work (2 min)

Click **Explore Lineage**.

This is the DAG you built. Sources on the left, staging, intermediate, marts,
and the semantic view on the right.

**What to look for in your track:**

- **Consumer packaged goods:** one source fanning out into two parallel
  branches that rejoin at the semantic view.
- **Energy:** two branches that never touch, because commodity prices and
  equipment maintenance share no key. You can see the reason for two semantic
  views rather than one.
- **Financial services:** five sources converging into
  `int_fs_risk_relationships` and fanning back out. The convergence point is
  the star join.

Try the **lenses** control. Colour the DAG by model layer, by materialization,
or by latest run status. The materialization lens makes your views and tables
obvious at a glance.

### 3. A model page: what the agent reads (3 min)

Click into your track's headline mart:

| Track | Model |
|---|---|
| Consumer packaged goods | `cpg_order_performance` |
| Energy | `energy_maintenance_logs` |
| Financial services | `fs_risk_relationship_summary` |

**The status bar** shows last run time, success, materialization, row count and
size. Check the row count against what you expect: 750, 750, or 2,948.

**The General tab** has the description you wrote in the YAML, the local
lineage graph, recent run info, test results, and a **Details** section.

Look at Details closely. It shows the relation name, and it shows **governance
attributes: access, group, and contracted status.** Your marts should show as
contracted, because every mart in this lab has `contract: enforced: true`.

That is the payoff for the work you did in section 5. The contract is not just
a build-time guard, it is a published fact about the table that anyone, human
or agent, can look up.

**The Columns tab** is the important one. For every column:

- name
- data type
- description
- tags
- test results, per column

Scroll it. Every description there is one you wrote, or one dbt Wizard wrote
and you reviewed. Every test result is a test you ran.

**Now the point of the whole section.** Look at a column with a good
description, and one with none. Ask yourself which one an AI agent is going to
reason about correctly.

In the CPG track, open `recognised_revenue` and read its description:
*"Value of the order line in USD, zero for cancelled orders. Use this rather
than order_total when reporting revenue."*

That sentence is the difference between an agent that reports revenue correctly
and one that overstates it by a quarter. It is not documentation hygiene. It is
the agent's context window.

### 4. Tests and sources (1 min)

Click a test from the Tests section of any model. You get its status, what it
targets, which column, and its compiled SQL.

Then click one of your sources. You get freshness (off in this lab, by design,
because the data is static), the database and schema it lives in, and its
columns.

**Data health signals** appear across Catalog as Healthy, Caution, Degraded or
Unknown. They are a summary of freshness and test state, and they are available
on every plan.

### 5. The connection to what comes next (1 min)

Everything on these pages comes from the **Discovery API**.

The dbt MCP Server's discovery tools call that same API. So when you wire an
agent to your project in section 9, the agent's picture of your data is exactly
the picture you have just been clicking through:

| What you see in Catalog | What the agent gets |
|---|---|
| Model and column descriptions | context for choosing the right column |
| Column data types | knowing what it can aggregate or filter |
| Test results | whether a column is trustworthy |
| Lineage | where a number came from |
| Contracted status, access, group | what is governed and stable |
| Metric definitions | governed answers instead of invented SQL |

**The practical takeaway:** if you want a good AI experience on your data, the
work is not in the prompt. It is in the descriptions, the tests, the contracts
and the metric definitions, which is to say it is in the pull request. Catalog
is where you check whether you have actually done it.

---

## Worth knowing about plans

Some of Catalog is Enterprise or Enterprise+ only:

- **Column-level lineage**
- **Model performance**
- Project recommendations, multi-project lineage

If you are on a workshop or trial account, you may not see these. The core of
the tour, models, columns, lineage, tests and health signals, is available on
all plans including Starter.

If you do have column-level lineage, spend a minute on it. Pick
`recognised_revenue` in CPG or `risk_weighted_exposure` in financial services
and trace it back to the source column it came from. That is the question every
data team gets asked and usually cannot answer quickly.

---

## Troubleshooting

**Catalog is empty, or my project is not listed.**
No successful job run in a production or staging deployment environment. CI
runs do not count. Go back to section 6 and check the job actually succeeded.

**My models are there but the Columns tab is empty.**
The job did not run `dbt docs generate`. On Fusion there is no "generate docs
on run" checkbox — edit the job and add `dbt docs generate` as its own
command, then run it again.

**Descriptions are missing.**
Same cause as above, or the column genuinely has no description in the YAML.
The second case is the more interesting one: that is a gap an agent will feel.

**Tests show as unknown.**
The job ran `dbt run` rather than `dbt build`, so no tests executed. `dbt build`
runs models and tests together.

**I see the models but the lineage looks wrong.**
Catalog reflects the last successful production run, not your development
branch. If you fixed a `ref()` in dev and have not merged or re-run production,
Catalog still shows the old shape.

---

## Sources

- [Discover data with Catalog](https://docs.getdbt.com/docs/explore/explore-projects)
- [Column-level lineage](https://docs.getdbt.com/docs/explore/column-level-lineage)
- [Discovery API](https://docs.getdbt.com/docs/dbt-apis/discovery-api)
