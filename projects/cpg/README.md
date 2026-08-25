# Consumer packaged goods track

Order and product performance for a consumer packaged goods manufacturer.
This is the most self-contained of the three tracks: one source table, two
marts, one clear story.

The full step-by-step walkthrough is
[docs/attendee-guide-cpg.md](../../docs/attendee-guide-cpg.md). This file is the
30-second orientation.

## The business question

> Where are we losing money on this range, and is it a demand problem or a
> supply problem?

The marts answer it from two sides. `cpg_order_performance` says what sold and
at what value. `cpg_product_inventory_health` says whether we could actually
supply it. Put together, they separate "nobody wanted it" from "we ran out."

## Quickstart

1. Open this folder (`projects/cpg`) in dbt Studio.
2. `dbt deps`
3. `dbt seed`, which loads `cpg_records` — the raw feed a real deployment
   would land continuously via Openflow instead.
4. `dbt build --select staging`, which is checkpoint 1 and should be green.
5. `dbt build`, which is where the seeded bugs live. Fix them with dbt Wizard.

Stuck? There's no schema to fall back to any more — the seed is the same for
everyone. Re-fork the repo if you think you've broken something structural.

## What is in here

```
models/
├── staging/
│   ├── _cpg__seeds.yml            seed declaration
│   ├── _cpg__models.yml           staging tests and descriptions
│   └── stg_cpg_records.sql        typed, renamed view over the raw feed
├── intermediate/
│   ├── int_cpg_order_performance.sql   order-grain derived logic
│   └── int_cpg_inventory_health.sql    product-grain risk scoring
├── marts/
│   ├── _cpg__marts.yml            contracts, tests, descriptions
│   ├── cpg_order_performance.sql       governed order fact (contract enforced)
│   ├── cpg_product_inventory_health.sql governed inventory fact (contract enforced)
│   ├── vw_cpg_data_quality.sql         data-quality scorecard by category
│   └── sv_cpg_commercial_performance.sql  Snowflake Semantic View
└── semantic/
    └── README.md                  why the MetricFlow specs live in the marts
                                   YAML under the latest spec
```

## The two semantic definitions

Both describe the same business, in two places, for two consumers:

| | Snowflake Semantic View | dbt Semantic Layer |
|---|---|---|
| File | `models/marts/sv_cpg_commercial_performance.sql` | `models/marts/_cpg__marts.yml` (the `semantic_model:` and `metrics:` blocks) |
| Lives in | Snowflake, as a native object | this repo, served at query time |
| Read by | Cortex Analyst | dbt MCP Server, then Snowflake AI |
| Created by | `dbt build` via the Snowflake-Labs package | no warehouse object created |

## Headline metrics

Total order value, total recognised revenue, average order value, average
customer lifetime value, fulfilment rate, cancellation rate, average product
rating, average stockout rate, average overstock rate, average inventory
turnover, share of products needing review.

Sliced by product category and subcategory, customer segment, order status,
order value band, stockout and overstock risk level, and order date.

## One thing worth noticing

`order_total` and `recognised_revenue` are not the same number. 192 of the 750
order lines are cancelled but still carry a value in the raw feed. Sum the
wrong one and you overstate revenue by roughly a quarter. That gap is why the
mart exists, and it is what `vw_cpg_data_quality` scores as a consistency
failure.
