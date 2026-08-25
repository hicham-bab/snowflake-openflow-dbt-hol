# Financial services track

Credit risk across a portfolio of customers and lending institutions. This is
the flagship track: the same 90 minutes as the other two, but the richest data
and the only one where governance does real work.

The full step-by-step walkthrough is
[docs/attendee-guide-financial-services.md](../../docs/attendee-guide-financial-services.md).
This file is the 30-second orientation.

## Who should pick this track

Pick it if you are comfortable with SQL joins and want the harder problem. The
required path is the same length as CPG and energy, but there are five source
tables in the star instead of one, and the data actively tries to trip you up:
columns that look numeric and are text, empty strings that break a `cast()`, and
twelve personal-data columns you have to notice before an AI agent does.

If you would rather get through comfortably, take CPG or energy. Nobody is
scoring this.

## The business question

> Where is our credit risk concentrated, is it getting worse, and can we let an
> AI agent answer that without handing it anyone's social security number?

## Quickstart

1. Open this folder (`projects/financial_services`) in dbt Studio.
2. `dbt deps`
3. `dbt seed`, which loads all eight raw tables — the feeds a real deployment
   would land continuously via Openflow instead.
4. `dbt build --select staging`, which is checkpoint 1 and should be green.
5. `dbt build`, which is where the seeded bugs live. Fix them with dbt Wizard.
6. Optional: `dbt build --select tag:stretch` for the marketing and product
   recommendation marts.

Stuck? There's no schema to fall back to any more — the seed is the same for
everyone. Re-fork the repo if you think you've broken something structural.

## The star

Five tables, verified clean: 250 customers, 20 institutions, 700
relationships, 25,200 monthly assessments (700 × 36 months), zero orphans in
any direction.

```
  risk_assess_customers  ──┐
  (250, the who)           │
                           ├──> risk_assess_risk_profiles  (700, the what)
  risk_assess_financial_   │         │
  institutions           ──┘         ├──> risk_assess_monthly_assessments
  (20, the where)                    │    (25,200, the when)
                                     │
                                     └──> risk_assess_performance_metrics
                                          (700, somebody else's maths)
```

`int_fs_risk_relationships` is where the star gets joined. Everything after it
is slicing.

## The governance beat

`loan` has 118 columns. `stg_loan` selects 20. Twelve of the excluded ones are
personal data, and the interesting part is that they are redundant:

| Columns in the source | What they actually are |
|---|---|
| `social_security_number`, `ssn`, `ssnumber` | the identical value on all 3,000 rows |
| `ssnumber1` | a fourth SSN-shaped column with a different value |
| `drivers_license`, `dl` | the identical value on all rows |
| `member_id` | a second person identifier alongside `id` |
| `emp_title`, `title`, `c_desc` | free text, written by members of the public |
| `zip_code` | first three digits, a re-identification vector with state and income |
| `c_url` | a URL containing the loan id |

Six redundant identity columns for two actual identifiers. Drop `ssn` and stop,
and you have shipped the same number twice under two other names. That is the
lesson: PII removal is a de-duplication problem before it is a deletion problem.

**Contracts are the enforcement.** Every mart in this track has
`contract: enforced: true` with the full column list pinned in
`_financial_services__marts.yml`. Add a PII column back upstream and the build
fails with a named column, in a pull request, before anything is written. That
matters more here than in the other tracks, because a semantic view will
cheerfully describe whatever columns it is given.

## Three ways this data will bite you

**Empty strings that are not nulls.** `risk_change_from_previous` is text and is
`''` on the first assessment of every relationship, 700 rows.
`collateral_quality_score`, `liquidity_ratio` and `projected_cash_flow_rating`
are text and empty on roughly two thirds of rows each. `cast()` throws
`Numeric value '' is not recognized`. `try_cast()` returns NULL and keeps going.
Which one you want depends on whether a blank is a bug or a fact.

**Percentages stored as strings.** `int_rate` is `'7.90%'`, `revol_util` is
`'28.30%'`, `pub_rec_bankruptcies` uses `'NA'`, and `issue_d` is `'Dec-11'`.

**A number pretending to be a category.** `risk_appetite` looks like it should
be Conservative or Aggressive. It is a float from 0.17 to 0.68. Staging renames
it `risk_appetite_score` and adds a banded `risk_appetite_band` next to it, so
nobody groups by the wrong one.

## Headline metrics

Average risk score, risk-score volatility, average fraud probability, anomaly
rate, approval and denial rate, deterioration rate, total and average exposure,
total risk-weighted exposure, average risk-adjusted return, average customer
value score, average credit score, average debt-to-income, prior bankruptcy
rate, unassessed collateral rate.

Sliced by institution type, size, region, regulatory rating and risk appetite;
by customer segment, income bracket, credit score range, education and
employment sector; and by product type, risk tier, exposure band, relationship
stage and month.
