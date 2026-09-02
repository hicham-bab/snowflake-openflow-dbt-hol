# Adding an industry track

Roughly two to three hours for someone who has run the lab once. The template
does the structural work; your time goes on understanding the data and choosing
a business story.

**Before you start, know that the source database has 26 schemas.** This lab
uses three. The rest are available:

```
agriculture, attractions, census, construction, consumer_packaged_goods,
customer_service, energy, financial_services, healthcare, higher_education,
hospitality, insurance, manufacturing, media_entertainment, pharma, retail,
sales, single_string_winery_review, supply_chain, telco, transportation,
utilities, weather
```

Good next candidates: `insurance`, `telco`, `manufacturing`, `retail`,
`healthcare`.

---

## Step 1: introspect the real schema (30 min, and do not skip it)

**Model from the data, never from a description of the data.** Every track in
this repo was built by querying the source directly, and every one of them
turned up something the brief did not mention. In energy, two source tables
turned out to be byte-for-byte identical. In financial services, three columns
documented as numeric were text with empty strings.

Connect to the source and answer these questions before writing a line of SQL.
This is an author-only step: attendees never connect to the source database
directly (their raw data ships as a seed), so these credentials aren't on the
lab credentials card — get them from whoever owns the source database.

```bash
export PGPASSWORD='<from the source database owner, not the lab credentials card>'
CONN="host={{POSTGRES_HOST}} port=5432 dbname=industry user={{POSTGRES_USER}} sslmode=require"
```

### Columns and types

```sql
select table_name, ordinal_position, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = '<your_schema>'
order by table_name, ordinal_position;
```

**Look for columns that are `text` and should not be.** They are everywhere in
this database: dates as ISO strings, booleans as `'True'`, percentages as
`'7.90%'`, numerics with `''` for unknown. Each one is a decision about `cast`
versus `try_cast`, and each one is a candidate teaching moment.

### Exact row counts

```sql
select count(*) from <your_schema>.<table>;
```

Use `count(*)`, not `reltuples`. The estimate was wrong by 800 rows on one
table here.

### Grain, for every table

```sql
select count(*) as rows,
       count(distinct <candidate_key>) as distinct_keys
from <your_schema>.<table>;
```

If they differ, you have not found the grain yet. Keep going until you can
write "one row per X" and mean it.

### Every value of every categorical column

```sql
select distinct <column> from <your_schema>.<table>;
```

**Do this for every column you plan to write an `accepted_values` test on.** A
guessed list fails at checkpoint 1 and blocks the whole room. This is the
single most common way to break a new track.

### Ranges, for every column you plan to range-test

```sql
select min(<column>), max(<column>) from <your_schema>.<table>;
```

The WTI crude column in energy has a minimum of -37.63. A reasonable-looking
`min_value: 0` test would fail on real, correct data.

### Referential integrity, if there is more than one table

```sql
select count(*)
from <fact> f
left join <dim> d on f.<key> = d.<key>
where d.<key> is null;
```

Zero means an inner join is safe. Anything else and you need to decide what to
do about it, and say so in a comment.

### Duplicate feeds

If two tables look similar, check before assuming:

```sql
select count(*) from (select * from <table_a> except select * from <table_b>) d;
select count(*) from (select * from <table_b> except select * from <table_a>) d;
```

Both zero means they are the same data. That is what happened in energy, and it
became the best teaching moment in the track.

### Sentinel values

```sql
select <column>, count(*) from <your_schema>.<table> group by 1 order by 1 limit 10;
```

`999`, `-1`, `'NA'`, `''`. They are real integers in real integer columns and
nothing warns you.

**Write everything you find into `BUILD-NOTES.md` as you go.**

---

## Step 2: pick the story before you pick the tables (20 min)

Write the business question first, in one sentence a customer in that vertical
would recognise. The three existing ones:

- **CPG:** where are we losing money on this range, and is it a demand problem
  or a supply problem?
- **Energy:** what is our exposure to commodity prices, and what is our fleet
  costing us when it breaks?
- **Financial services:** where is our credit risk concentrated, is it getting
  worse, and can we let an AI agent answer that without handing it anyone's
  social security number?

Then decide:

**What is the headline mart?** One table that answers most of the question.

**What is the second mart?** Usually the other side of the story: demand versus
supply, price versus reliability, snapshot versus time series.

**Are there two subject areas or one?** If your track has two things that share
no key, they get one Semantic View each. Do not force them together.

**What is the interesting flaw in the data?** Every track has one, and it is
what makes the data-quality view worth building. If you cannot find one, look
harder; there is always one.

**Scope to 90 minutes.** Two required marts, maybe one stretch. Financial
services has eight source tables and only five are on the required path.

---

## Step 3: copy the template and build (60-90 min)

```bash
cp -r projects/_template projects/<track_key>
```

Then work through `projects/_template/README.md`, which lists every file to
rename and every rule that keeps tracks interchangeable. The short version:

1. Fill in the `vars` block in `dbt_project.yml`. That is the only per-track
   config.
2. Write staging: one typed, renamed view per source table. **Must be green.**
3. Write the intermediate layer: joins, reshapes, derived flags, banding.
4. Write the marts with enforced contracts, casting every column to exactly the
   declared type.
5. Write the data-quality view **from staging**, not from the marts.
6. Write the Semantic View and the MetricFlow specs, and note where they cannot
   express the same thing.
7. Add two or three singular tests that guard real invariants.

Build and confirm green before seeding any bugs.

---

## Step 4: seed four bugs (20 min)

Mark each with `-- HOL_BUG_<TRACK>_<nn>`. Spread them across independent DAG
branches. The rules that matter:

- Never in staging SQL or a staging test. Checkpoint 1 must stay green.
- Never in a `semantic_model:` or `metrics:` block. Semantic YAML is validated
  at parse time and a malformed metric blocks the whole project.
- **Never a bad `ref()`.** On Fusion an unresolvable `ref()` is a parse-time
  error, so it fails `dbt build --select staging` too and breaks checkpoint 1.
  Verified, not theoretical. Use a wrong column name instead.
- Each must produce a clear error on `dbt build` or `dbt test`, never a silent
  wrong number.
- **At least one should have a wrong fix that compiles.** That is where the
  lesson about reviewing agent output actually lands.

Then verify the failure set is exactly what you expect:

```bash
dbt build 2>&1 | grep -E "Error|FAIL"
```

Apply your own fixes and confirm fully green.

---

## Step 5: wire it into the lab (30 min)

Five files to update. Miss one and the track is invisible or unsupportable.

**1. `docs/answer-key.md`.** Add a section for your four bugs, in the same
format: file, layer, wave, symptom, what it blocks, cause, fix, Wizard prompt,
teaching point. Add them to the quick-reference table and flag any with a wrong
fix that compiles.

**2. `docs/attendee-guide-<track>.md`.** Copy an existing guide and adapt. Keep
the same nine sections and the same minute budgets, so an instructor supporting
four tracks at once can say "everyone should be at section 5 now" and have it
mean something.

**3. `README.md`.** Add a row to the track picker table: folder, the story, and
who should pick it. Be honest about difficulty.

**4. `snowflake/cortex_semantic/`.** Add `<track>_semantic_view.sql`, following
the existing pattern: reference and verification, not duplicated DDL. Then add
agent instructions and 6 to 8 sample questions to `agents_setup.md`.

**Agent instructions are not optional.** They are where you tell the agent
about the flaw you found in step 1. Every existing track needs them: CPG to
stop the agent reporting the wrong revenue, energy to stop it returning empty
answers for "this year", financial services to handle de-identified data
gracefully.

**5. `docs/facilitator-guide.md`.** Add your track to the steering table and to
anything track-specific in the failure playbook.

---

## Step 6: dry run (30 min)

As an attendee would, from a clean state:

- [ ] `dbt deps`, then `dbt seed` (every track needs one — that's where your
      raw data lives now, see `scripts/generate_seed_data.py`)
- [ ] `dbt build --select staging` → green. Record model and test counts and
      put the real numbers in your attendee guide
- [ ] `dbt build` → fails with exactly your four bugs
- [ ] Apply the answer key → fully green
- [ ] Full build under 60 seconds on an XS warehouse
- [ ] Semantic View created; query it with `SEMANTIC_VIEW(...)` directly
- [ ] Production job run, and your track appears in dbt Catalog with populated
      Columns tabs (needs `dbt build` plus `dbt docs generate` as a second
      command — there is no "generate docs on run" checkbox on Fusion)
- [ ] Cortex Agent answers all your sample questions sensibly
- [ ] Ask a deliberately bad question and check the agent handles it well

Then hand the guide to somebody who has not seen the track and watch them
follow it without helping. Every place they hesitate is a place the guide is
wrong.

---

## What makes a good track

Looking back at the three that exist, the ones that work share four things.

**A flaw worth finding.** Energy's duplicate feed is the best thing in this
lab, and it was discovered by running two `EXCEPT` queries rather than trusting
a description. Look for the thing that would silently produce a wrong number.

**A governance angle, if the data has one.** Financial services is the
strongest track because the PII is real, redundant and worth arguing about.
Insurance and healthcare would both support this.

**Two sides to the story.** Demand and supply. Price and reliability. Snapshot
and trend. Two marts that answer different halves of one question beat one mart
that answers all of it.

**Column descriptions that earn their place.** Section 8 of every guide has
attendees read a description in dbt Catalog and ask whether an agent could act
on it. Write at least a couple that would clearly change an AI's answer: CPG's
`recognised_revenue` and financial services' `risk_weighted_exposure` are the
models to copy.

**Metrics a practitioner would actually use.** `unplanned_work_rate` is what a
reliability engineer watches. `total_risk_weighted_exposure` is what a
regulator asks about. Both beat `count of rows` for making a room lean forward.

---

## What to avoid

**Do not add macros.** Every `macros/` folder in this repo is empty and should
stay that way. A new-to-dbt attendee has to be able to read any model top to
bottom without chasing an abstraction.

**Do not use incremental models.** Nothing in this database is large enough to
justify the explaining time.

**Do not enable source freshness.** The data is static, so it fails for
everyone by design. Leave the config commented out with a note, as the other
tracks do.

**Do not add a sync-audit column.** Raw data ships as a seed, not a live
ingestion feed, so there's no `_fivetran_synced`-style column and no
"when did this row last change" beat to build. See
`../openflow/openflow-overview.md` if you want the full reasoning.

**Do not diverge structurally.** Same folders, same file-naming, same `vars`
block, same nine guide sections. The whole point is that one instructor can
support four tracks in one room without holding four DAGs in their head.
