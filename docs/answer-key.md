# Answer key: facilitators only

**Do not share this link with attendees before or during the lab.** The whole
value of section 5 is attendees diagnosing failures with dbt Wizard rather than
looking up the answer.

Twelve seeded bugs, four per track. Every one is marked in the code with a
greppable token:

```bash
grep -rn "HOL_BUG_" projects/
```

---

## Design rules, so you can explain them if asked

- **Checkpoint 1 (`dbt build --select staging`) is always green in every
  track.** No bug sits in staging SQL or in a staging test. If an attendee is
  red at checkpoint 1, it is their project subdirectory or a grants problem,
  not one of the twelve bugs — check `dbt seed` actually loaded first.
- **No bug is a parse-time error.** A malformed semantic YAML would fail the
  whole project at parse and block checkpoint 1 too. All twelve are
  compile-time, run-time or test failures scoped to a single node.
- **Bugs are spread across independent DAG branches** so one failure does not
  cascade and block everything else.
- **CPG and energy have a deliberate two-wave shape.** Bug 04 in each is the
  contract equivalent of bug 01, so it can only surface once bug 01 is fixed and
  the model compiles. That "oh, the contract has to agree too" moment is
  intentional. Financial services surfaces all four at once.
- **Four of the twelve have a wrong fix that compiles.** ENERGY_02, FS_02 and
  FS_04 in particular. Those are the ones worth slowing the room down for,
  because they are where "review the diff" stops being a slogan.

---

## Consumer packaged goods

### HOL_BUG_CPG_01

| | |
|---|---|
| **File** | `projects/cpg/models/intermediate/int_cpg_order_performance.sql` |
| **Layer** | intermediate |
| **Wave** | 1 |
| **Symptom** | `SQL compilation error: invalid identifier 'CUSTOMER_LTV'` |
| **Blocks** | `cpg_order_performance`, `sv_cpg_commercial_performance`, `assert_cancelled_orders_have_no_recognised_revenue` |

**Cause.** The model selects `customer_ltv`, the raw source column name.
`stg_cpg_records` renames it to `customer_lifetime_value`.

**Fix.** Replace `customer_ltv,` with `customer_lifetime_value,` and delete the
`HOL_BUG_CPG_01` comment.

**Wizard prompt:**
> This model fails with `invalid identifier 'CUSTOMER_LTV'`. Look at the
> staging model it selects from and find and fix the issue.

**Teaching point.** Staging renames columns; downstream has to keep up. This is
the single most common real-world dbt error and it is why `ref()` and column
lineage matter.

---

### HOL_BUG_CPG_02

| | |
|---|---|
| **File** | `projects/cpg/models/marts/cpg_product_inventory_health.sql` |
| **Layer** | mart |
| **Wave** | 1 |
| **Symptom** | `SQL compilation error: invalid identifier 'INVENTORY_COVERAGE_RATE'` |
| **Blocks** | `sv_cpg_commercial_performance` |

**Cause.** The mart selects `inventory_coverage_rate`. The intermediate model
produces `inventory_coverage_ratio`.

**Fix.** `cast(inventory_coverage_ratio as number(18, 4)) as inventory_coverage_ratio,`

**Wizard prompt:**
> This model fails with `invalid identifier 'INVENTORY_COVERAGE_RATE'`. Check
> the column names `int_cpg_inventory_health` actually produces and fix it.

**Teaching point.** A near-miss column name, which is the most common thing an
agent gets wrong when it writes SQL from memory rather than from the schema.

**Why this is not a `ref()` typo.** It was, in an earlier draft. On the Fusion
engine a bad `ref()` is a **parse-time** error, which fails the whole project
before any model runs, including `dbt build --select staging`. That would have
broken checkpoint 1 for every attendee. The ref-typo lesson is still in the lab,
in section 4.2 of each attendee guide, where they break a `ref()` on purpose and
watch Fusion catch it instantly. That is a better demonstration anyway.

---

### HOL_BUG_CPG_03

| | |
|---|---|
| **File** | `projects/cpg/models/marts/_cpg__marts.yml`, `vw_cpg_data_quality` → `data_quality_score` |
| **Layer** | mart test |
| **Wave** | 1 |
| **Symptom** | `FAIL 10 ... dbt_utils_accepted_range_vw_cpg_data_quality_data_quality_score...` |
| **Blocks** | nothing |

**Cause.** `min_value: 95`. Actual scores are roughly 91 to 92 for all 10
categories, because consistency scores about 74 (192 cancelled orders with
value, 8 low-confidence ratings, 373 orders predating their price
optimisation). 95 was never achievable.

**Fix.** Change `min_value` to `85`.

**Wizard prompt:**
> The accepted_range test on data_quality_score fails for all 10 categories.
> Look at the actual scores and tell me whether the data is wrong or the
> threshold is wrong, then fix whichever it is.

**Teaching point.** The best one in the CPG track. A failing test does not
always mean the data is broken; sometimes the test is wrong. Deciding which is
a judgement call the agent should inform, not make. Push back if an attendee
accepts a suggested threshold without asking what the business actually
committed to.

---

### HOL_BUG_CPG_04

| | |
|---|---|
| **File** | `projects/cpg/models/marts/_cpg__marts.yml`, `cpg_order_performance` contract |
| **Layer** | mart contract |
| **Wave** | **2**, only appears after CPG_01 is fixed |
| **Symptom** | `This model has an enforced contract that failed.` Mismatch on `customer_ltv` |
| **Blocks** | `sv_cpg_commercial_performance` |

**Cause.** The contract declares `customer_ltv`; the model produces
`customer_lifetime_value`.

**Fix.** Rename the contract column to `customer_lifetime_value`.

**Wizard prompt:**
> The contract on cpg_order_performance fails. Compare the columns the model
> produces with the columns the contract declares, and fix the mismatch.

**Teaching point.** This is the payoff for CPG_01. A contract is a separate,
deliberate promise about a table's shape. Changing the model means changing the
promise, in a diff someone reviews. Make the point that without the contract, a
downstream consumer would have discovered the rename instead.

---

## Energy

### HOL_BUG_ENERGY_01

| | |
|---|---|
| **File** | `projects/energy/models/intermediate/int_energy_commodity_prices_unpivoted.sql` |
| **Layer** | intermediate |
| **Wave** | 1 |
| **Symptom** | `SQL compilation error: invalid identifier 'CRUDE_OIL'` |
| **Blocks** | `energy_commodity_price_history`, `sv_energy_commodity_prices`, `assert_commodity_prices_cover_every_commodity` |

**Cause.** The `UNPIVOT` column list contains `crude_oil`. No such column
exists; the real one is `wti_crude`.

**Fix.** Replace `crude_oil,` with `wti_crude,` in the `IN (...)` list.

**Wizard prompt:**
> The UNPIVOT in this model fails with `invalid identifier 'CRUDE_OIL'`. Check
> the column list against what `stg_commodity_prices` actually produces and fix
> the wrong one.

**Teaching point.** The singular test
`assert_commodity_prices_cover_every_commodity` exists precisely because the
seed and the unpivot list are in different files and drift apart. Show it after
the fix.

---

### HOL_BUG_ENERGY_02

| | |
|---|---|
| **File** | `projects/energy/models/marts/energy_maintenance_cost_by_type.sql` |
| **Layer** | mart |
| **Wave** | 1 |
| **Symptom** | `SQL compilation error: ... 'MAINTENANCE_STATUS' ... is not a valid group by expression` |
| **Blocks** | nothing |

**Cause.** `maintenance_status` is selected in the `aggregated` CTE but the
`group by` is on `maintenance_type` only.

**Fix.** **Delete the `maintenance_status` line.** Do not add it to the
`group by`.

**THIS ONE HAS A WRONG FIX THAT COMPILES.** Adding `maintenance_status` to
the `group by` makes the error disappear and produces a table at the wrong
grain: 25 rows instead of 5. That then breaks the enforced contract (no such
column declared) and the `unique` test on `maintenance_type`. An attendee who
accepts that suggestion ends up with two new failures and no idea why.

The model header documents the grain as one row per `maintenance_type`. That is
the deciding evidence, and it is in the file.

**Wizard prompt:**
> This model fails with a group by error. Work out whether the extra column
> belongs in the group by or should not be selected at all, given the model is
> documented as one row per maintenance type.

**Teaching point.** Two ways to silence an error, one correct. The agent
infers; the attendee knows the intended grain because it is written down. Slow
the room down here.

---

### HOL_BUG_ENERGY_03

| | |
|---|---|
| **File** | `projects/energy/models/marts/_energy__marts.yml`, `energy_maintenance_logs` → `maintenance_status` |
| **Layer** | mart test |
| **Wave** | 1 |
| **Symptom** | `FAIL 1 ... accepted_values_energy_maintenance_logs_maintenance_status...` |
| **Blocks** | nothing |

**Cause.** The `values` list omits `Cancelled`, which is present on 165 rows
and is a documented legitimate status.

**Fix.** Add `'Cancelled'` to the list.

**Wizard prompt:**
> The accepted_values test on maintenance_status fails with one result. Find
> which value is missing from the test and decide whether to add it to the test
> or treat it as bad data.

**Teaching point.** `accepted_values` encodes an assumption about the source.
When the source legitimately grows a value, the test is what tells you, and the
right response is to update the test knowingly rather than to filter the data.

---

### HOL_BUG_ENERGY_04

| | |
|---|---|
| **File** | `projects/energy/models/marts/_energy__marts.yml`, `energy_commodity_price_history` contract |
| **Layer** | mart contract |
| **Wave** | **2**, only appears after ENERGY_01 is fixed |
| **Symptom** | `This model has an enforced contract that failed.` Contract declares `commodity`, model produces `commodity_code` |
| **Blocks** | `sv_energy_commodity_prices` |

**Cause.** The contract column is named `commodity`. The model produces
`commodity_code`.

**Fix.** Rename the contract column to `commodity_code`. Note that the
model-level `dbt_utils.unique_combination_of_columns` test already references
`commodity_code`, which is a hint.

**Wizard prompt:**
> The contract on energy_commodity_price_history fails. Compare the columns the
> model produces with the columns the contract declares, and fix the mismatch.

**Teaching point.** Same as CPG_04.

---

## Financial services

All four surface in wave 1.

### HOL_BUG_FS_01

| | |
|---|---|
| **File** | `projects/financial_services/models/intermediate/int_fs_monthly_risk_enriched.sql` |
| **Layer** | intermediate |
| **Wave** | 1 |
| **Symptom** | `Numeric value '' is not recognized` |
| **Blocks** | `fs_monthly_risk_assessment`, `sv_fs_credit_risk` |

**Cause.** `cast(assessments.risk_change_from_previous_raw as number(9,4))`.
That column is `text` and is an empty string on the first assessment of every
relationship: exactly 700 of 25,200 rows.

**Fix.** `try_cast(...)`.

**Wizard prompt:**
> This model fails with `Numeric value '' is not recognized`. Work out which
> column has empty strings and how many rows are affected, then fix the
> conversion. There is a correct pattern further down the same file.

The correct pattern is in `is_material_deterioration` a few lines below, which
already uses `try_cast`.

**Follow-up worth insisting on:**
> Should a blank risk change become NULL or 0? Which does the average metric
> need?

NULL. There is no previous month, so the change is unknown, not zero. Zero
across 700 rows would drag `average_risk_change` toward nothing. The model
already carries `is_first_assessment` so the NULL is explainable.

**Teaching point.** `cast` when a conversion failure is a bug you want to hear
about; `try_cast` when the source is genuinely allowed to be blank. Then the
separate, harder question of what blank *means*, which is a business decision
and belongs in the intermediate layer, not in staging.

---

### HOL_BUG_FS_02

| | |
|---|---|
| **File** | `projects/financial_services/models/marts/_financial_services__marts.yml`, `fs_loan_portfolio` contract |
| **Layer** | mart contract |
| **Wave** | 1 |
| **Symptom** | `This model has an enforced contract that failed.` Contract declares `emp_title`, model does not produce it |
| **Blocks** | `assert_loan_mart_publishes_every_staged_loan` |

**Cause.** The contract declares `emp_title`. `stg_loan` deliberately excludes
it as personal data, so the mart never produces it.

**Fix.** **Delete the `emp_title` entry from the contract.**

**THIS ONE HAS A WRONG FIX THAT COMPILES.** Adding `emp_title` back into
`stg_loan.sql` and `fs_loan_portfolio.sql` makes the build go green and
publishes employer names into a table the Semantic View and Cortex Analyst can
read. Everything passes. The governance control is gone.

**Wizard prompt:**
> The contract on fs_loan_portfolio fails. Compare the columns the contract
> declares with the columns the model produces, then check
> `models/staging/stg_loan.sql` before deciding how to fix it.

The "check stg_loan.sql first" clause matters. Without it the agent has no way
to know the exclusion was deliberate.

**Teaching point.** The best moment in the whole lab. A contract failure is not
always telling you the model is wrong; sometimes it is telling you somebody
tried to put PII back. Ask the room which fix they would have accepted at 4pm
on a Friday.

---

### HOL_BUG_FS_03

| | |
|---|---|
| **File** | `projects/financial_services/models/marts/_financial_services__marts.yml`, `fs_risk_relationship_summary` → `risk_tier` |
| **Layer** | mart test |
| **Wave** | 1 |
| **Symptom** | `FAIL ... accepted_values_fs_risk_relationship_summary_risk_tier...` |
| **Blocks** | nothing |

**Cause.** The `values` list has four tiers. `int_fs_risk_relationships` derives
five: `Very High` for `base_risk_score >= 0.80` is missing.

**Fix.** Add `'Very High'` to the list.

**Wizard prompt:**
> The accepted_values test on risk_tier fails. Find which tier is missing from
> the test and check the model that derives it before deciding.

**Teaching point.** The test and the `CASE` statement that produces the values
are in different files and drifted. Worth noting the test caught it, which is
the point of having it.

---

### HOL_BUG_FS_04

| | |
|---|---|
| **File** | `projects/financial_services/models/marts/fs_product_recommendations.sql` |
| **Layer** | mart, `stretch` tag |
| **Wave** | 1 |
| **Symptom** | `SQL compilation error: invalid identifier 'CUSTOMER_EMAIL'` |
| **Blocks** | nothing |

**Cause.** The model selects `customer_email`. `stg_fpr_records` deliberately
excludes it as personal data.

**Fix.** **Delete the `customer_email` line** from the mart.

**SAME WRONG FIX AS FS_02.** Adding `customer_email` back into
`stg_fpr_records` compiles and publishes email addresses.

**Wizard prompt:**
> This stretch model fails with `invalid identifier 'CUSTOMER_EMAIL'`. Check
> what `stg_fpr_records` exposes and fix it.

**Teaching point.** The same lesson as FS_02 in a different shape, on purpose.
Once is a puzzle; twice is a pattern. If an attendee gets FS_02 right and FS_04
wrong, that is a genuinely useful thing for them to notice about themselves.

Note this model is tagged `stretch`, so it only builds under a plain `dbt build`
or `dbt build --select tag:stretch`.

---

## Quick reference

| ID | File | Layer | Wave | One-line fix |
|---|---|---|---|---|
| CPG_01 | `int_cpg_order_performance.sql` | int | 1 | `customer_ltv` → `customer_lifetime_value` |
| CPG_02 | `cpg_product_inventory_health.sql` | mart | 1 | `inventory_coverage_rate` → `inventory_coverage_ratio` |
| CPG_03 | `_cpg__marts.yml` | test | 1 | `min_value: 95` → `85` |
| CPG_04 | `_cpg__marts.yml` | contract | 2 | `customer_ltv` → `customer_lifetime_value` |
| ENERGY_01 | `int_energy_commodity_prices_unpivoted.sql` | int | 1 | `crude_oil` → `wti_crude` |
| ENERGY_02 | `energy_maintenance_cost_by_type.sql` | mart | 1 | delete `maintenance_status` (!!) |
| ENERGY_03 | `_energy__marts.yml` | test | 1 | add `'Cancelled'` |
| ENERGY_04 | `_energy__marts.yml` | contract | 2 | `commodity` → `commodity_code` |
| FS_01 | `int_fs_monthly_risk_enriched.sql` | int | 1 | `cast` → `try_cast` |
| FS_02 | `_financial_services__marts.yml` | contract | 1 | delete `emp_title` (!!) |
| FS_03 | `_financial_services__marts.yml` | test | 1 | add `'Very High'` |
| FS_04 | `fs_product_recommendations.sql` | mart | 1 | delete `customer_email` (!!) |

(!!) = has a wrong fix that compiles. Slow down here.

---

## Regenerating this key

```bash
grep -rn -B2 -A2 "HOL_BUG_" projects/
```

If you add or move a bug, update this file and the wave table in
`BUILD-NOTES.md`.

---

## Stretch prompts for fast attendees

For anyone finished before 1:15.

**Any track:**
> Add a unit test for the banding logic in this model, mocking three input rows
> that fall in different bands.

> Generate column descriptions for every column in this mart that does not have
> one, and tell me which ones you were unsure about.

**CPG:**
> Add a metric for revenue per unit sold, derived from total recognised revenue
> and implied units.

**Energy:**
> The commodity price data ends in November 2022. Add a singular test that
> fails if the maximum price date is more than 30 days older than the maximum
> across all commodities, so a stalled feed for one commodity gets caught.

**Financial services:**
> Build the institution-level rollup from section 5.5, then add it to the
> Snowflake Semantic View as a third logical table with the right relationship.
