#!/usr/bin/env python3
"""
Generate seed CSVs for the three industry tracks (cpg, energy, financial_services).

This replaces the live Fivetran sync: every raw table each track used to land
via a connector now ships as a dbt seed, generated here deterministically
(fixed RNG seed) so re-running this script reproduces byte-identical output.

Every documented quirk in BUILD-NOTES.md that a seeded bug, a contract, or a
data-quality view depends on is reproduced on purpose (see the comment above
each generator). CPG and energy are generated at their original documented
row counts. Financial services is trimmed to a representative scale (see
BUILD-NOTES.md) -- same relationships, same quirks, fewer rows.

Run: python3 scripts/generate_seed_data.py
"""

import csv
import os
import random
from datetime import date, timedelta

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RNG = random.Random(42)


def seed_path(track, filename):
    return os.path.join(REPO_ROOT, "projects", track, "seeds", filename)


def write_csv(path, header, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    return path


def daterange_business_days(start, count):
    """count business days starting at (and including) start."""
    out = []
    d = start
    while len(out) < count:
        if d.weekday() < 5:
            out.append(d)
        d += timedelta(days=1)
    return out


def iso(d):
    return d.isoformat()


# ===========================================================================
# CPG: cpg_records.csv -- 750 rows, full original scale
# ===========================================================================
def generate_cpg():
    categories = [
        ("Beverages", "Carbonated Soft Drinks"),
        ("Snacks", "Salty Snacks"),
        ("Personal Care", "Oral Care"),
        ("Household", "Laundry Care"),
        ("Baby Care", "Diapers"),
        ("Pet Care", "Dry Food"),
        ("Health & Wellness", "Vitamins"),
        ("Frozen Foods", "Frozen Meals"),
        ("Dairy", "Yogurt"),
        ("Cleaning Supplies", "Surface Cleaners"),
    ]
    n = 750
    n_categories = len(categories)
    per_cat = n // n_categories  # 75

    # HOL_BUG_CPG_03 / vw_cpg_data_quality depends on exact counts:
    #   192 cancelled orders that still carry order_total > 0
    #   8 rows with product_rating > 4.5 and product_review_count < 10
    #   373 rows where order_date > price_optimization_date
    n_cancelled_with_value = 192
    n_low_confidence = 8
    n_predates = 373

    order_start = date(2024, 4, 28)
    order_end = date(2024, 12, 31)
    order_span = (order_end - order_start).days

    def even_quotas(total, buckets):
        """Split `total` into `buckets` integers as evenly as possible."""
        base, remainder = divmod(total, buckets)
        return [base + 1 if b < remainder else base for b in range(buckets)]

    cancelled_quotas = even_quotas(n_cancelled_with_value, n_categories)
    low_conf_quotas = even_quotas(n_low_confidence, n_categories)
    predates_quotas = even_quotas(n_predates, n_categories)

    rows = []
    row_idx = 0
    for cat_idx, (category, subcategory) in enumerate(categories):
        # Within each 75-row category, randomly pick which specific rows carry
        # each quirk, so the three failure counts land evenly across every
        # category rather than clustering (a row can carry more than one).
        cancelled_positions = set(RNG.sample(range(per_cat), cancelled_quotas[cat_idx]))
        low_conf_positions = set(RNG.sample(range(per_cat), low_conf_quotas[cat_idx]))
        predates_positions = set(RNG.sample(range(per_cat), predates_quotas[cat_idx]))

        for pos in range(per_cat):
            i = row_idx
            row_idx += 1
            record_id = f"CPG-{i + 1:05d}"
            order_id = f"ORD-{i + 1:05d}"
            customer_id = f"CUST-{(i % 500) + 1:05d}"
            product_id = f"PROD-{(i % 200) + 1:05d}"

            order_date = order_start + timedelta(days=RNG.randint(0, order_span))

            if pos in cancelled_positions:
                order_status = "Cancelled"
            else:
                order_status = RNG.choice(["Delivered", "Shipped", "Pending"])

            order_total = round(RNG.uniform(15, 900), 2)  # always > 0, even when cancelled

            if pos in low_conf_positions:
                product_rating = round(RNG.uniform(4.6, 5.0), 2)
                product_review_count = RNG.randint(1, 9)
            else:
                product_rating = round(RNG.uniform(1.0, 4.5), 2)
                product_review_count = RNG.randint(10, 500)

            if pos in predates_positions:
                price_optimization_date = order_date - timedelta(days=RNG.randint(1, 60))
            else:
                price_optimization_date = order_date + timedelta(days=RNG.randint(0, 60))

            product_price = round(RNG.uniform(2, 60), 2)
            inventory_level = RNG.randint(0, 5000)
            customer_segment = RNG.choice(["High-Value", "Medium-Value", "Low-Value"])
            customer_ltv = round(RNG.uniform(50, 5000), 2)
            order_frequency = RNG.randint(1, 24)
            average_order_value = round(RNG.uniform(20, 400), 2)
            price_optimization_flag = RNG.choice(["TRUE", "FALSE"])
            price_elasticity = round(RNG.uniform(0.1, 2.5), 4)
            demand_forecast = RNG.randint(1, 5000)
            inventory_turnover = round(RNG.uniform(0.5, 12), 4)
            stockout_rate = round(RNG.uniform(0.0, 0.15), 6)
            overstock_rate = round(RNG.uniform(0.0, 0.20), 6)
            revenue_growth_rate = round(RNG.uniform(-0.3, 0.5), 6)
            customer_satisfaction_rate = round(RNG.uniform(0.5, 1.0), 6)
            price_optimization_result = RNG.choice(["Implemented", "Pending Review", "Rejected"])
            price_optimization_recommendation = RNG.choice(
                ["Increase price", "Decrease price", "Hold price", "Bundle with promotion"]
            )
            rows.append([
                record_id, order_id, customer_id, product_id, iso(order_date),
                order_total, product_price, inventory_level, customer_segment,
                order_status, category, subcategory, customer_ltv, order_frequency,
                average_order_value, product_rating, product_review_count,
                price_optimization_flag, price_elasticity, demand_forecast,
                inventory_turnover, stockout_rate, overstock_rate, revenue_growth_rate,
                customer_satisfaction_rate, iso(price_optimization_date),
                price_optimization_result, price_optimization_recommendation,
            ])

    header = [
        "record_id", "order_id", "customer_id", "product_id", "order_date",
        "order_total", "product_price", "inventory_level", "customer_segment",
        "order_status", "product_category", "product_subcategory", "customer_ltv",
        "order_frequency", "average_order_value", "product_rating",
        "product_review_count", "price_optimization_flag", "price_elasticity",
        "demand_forecast", "inventory_turnover", "stockout_rate", "overstock_rate",
        "revenue_growth_rate", "customer_satisfaction_rate", "price_optimization_date",
        "price_optimization_result", "price_optimization_recommendation",
    ]
    path = write_csv(seed_path("cpg", "cpg_records.csv"), header, rows)
    return {"path": path, "rows": rows, "header": header}


# ===========================================================================
# Energy: commodity_prices.csv (5,898 rows incl. the all-null row),
#         fts_records.csv + loglynx.csv (750 rows each, byte-identical)
# ===========================================================================
COMMODITIES = [
    ("natural_gas", "Energy"), ("wti_crude", "Energy"), ("brent_crude", "Energy"),
    ("low_sulphur_gas_oil", "Energy"), ("uls_diesel", "Energy"), ("gasoline", "Energy"),
    ("gold", "Metals"), ("silver", "Metals"), ("copper", "Metals"),
    ("aluminium", "Metals"), ("nickel", "Metals"), ("zinc", "Metals"),
    ("corn", "Grains and softs"), ("wheat", "Grains and softs"), ("hrw_wheat", "Grains and softs"),
    ("soybeans", "Grains and softs"), ("soybean_oil", "Grains and softs"),
    ("soybean_meal", "Grains and softs"), ("sugar", "Grains and softs"),
    ("coffee", "Grains and softs"), ("cotton", "Grains and softs"),
    ("live_cattle", "Livestock"), ("lean_hogs", "Livestock"),
]
COMMODITY_BASE_PRICE = {
    "natural_gas": 3, "wti_crude": 60, "brent_crude": 65, "low_sulphur_gas_oil": 550,
    "uls_diesel": 200, "gasoline": 180, "gold": 1500, "silver": 20, "copper": 3,
    "aluminium": 2000, "nickel": 15000, "zinc": 2500, "corn": 400, "wheat": 550,
    "hrw_wheat": 500, "soybeans": 1000, "soybean_oil": 35, "soybean_meal": 350,
    "sugar": 15, "coffee": 120, "cotton": 70, "live_cattle": 120, "lean_hogs": 70,
}


def generate_energy():
    # ---- commodity_prices: 5,898 rows including the fully-null id=1 row ----
    real_rows_needed = 5898 - 1  # 5,897 real trading days
    trading_dates = daterange_business_days(date(2000, 1, 4), real_rows_needed)
    gasoline_start_idx = 1480  # gasoline starts ~1,480 rows later than the rest

    price_rows = []
    # id=1: the fully-null row, dated 2000-01-03 (before the real series starts)
    null_row = [1, "2000-01-03"] + [""] * len(COMMODITIES)
    price_rows.append(null_row)

    walk = dict(COMMODITY_BASE_PRICE)
    for idx, d in enumerate(trading_dates):
        row_id = idx + 2  # ids 2..5898
        values = []
        for name, _group in COMMODITIES:
            if name == "gasoline" and idx < gasoline_start_idx:
                values.append("")
                continue

            if name == "wti_crude" and d == date(2020, 4, 20):
                walk[name] = -37.63
                values.append(-37.63)
                continue

            drift = RNG.uniform(-0.02, 0.02)
            walk[name] = max(0.5, walk[name] * (1 + drift))
            values.append(round(walk[name], 4))
        price_rows.append([row_id, iso(d)] + values)

    price_header = ["id", "date"] + [c for c, _g in COMMODITIES]
    price_path = write_csv(seed_path("energy", "commodity_prices.csv"), price_header, price_rows)

    # ---- fts_records / loglynx: 750 identical maintenance events ----------
    n = 750
    n_cancelled = 165  # HOL_BUG_ENERGY_03 depends on 'Cancelled' being present
    maintenance_types = [
        "Preventive Maintenance", "Predictive Maintenance", "Corrective Maintenance",
        "Condition-Based Maintenance", "Reliability-Centered Maintenance",
    ]
    other_statuses = ["Completed", "In Progress", "Scheduled", "Delayed"]
    log_start = date(2024, 6, 27)
    log_end = date(2026, 7, 16)
    log_span = (log_end - log_start).days

    maint_rows = []
    cancelled_budget = n_cancelled
    for i in range(n):
        record_id = f"MTN-{i + 1:05d}"
        log_date = log_start + timedelta(days=RNG.randint(0, log_span))
        equipment_id = f"EQ-{(i % 150) + 1:04d}"
        technician_id = f"TECH-{(i % 40) + 1:03d}"
        customer_id = f"ECUST-{(i % 300) + 1:04d}"
        erp_order_id = f"ERP-{i + 1:05d}"
        maintenance_type = maintenance_types[i % len(maintenance_types)]

        is_cancelled = cancelled_budget > 0 and (i % (n // n_cancelled) == 0)
        if is_cancelled:
            cancelled_budget -= 1
            maintenance_status = "Cancelled"
        else:
            maintenance_status = RNG.choice(other_statuses)

        failure_rate = round(RNG.uniform(0.0, 1.0), 4)
        maintenance_cost = round(RNG.uniform(100, 15000), 2)
        downtime_hours = RNG.randint(1, 200)
        summarization_time_saved = RNG.randint(0, 8)
        log_description = f"Technician note for {equipment_id} on {iso(log_date)}."
        summarized_log = f"AI summary: {maintenance_type} on {equipment_id}."

        maint_rows.append([
            record_id, iso(log_date), equipment_id, technician_id, customer_id,
            erp_order_id, maintenance_type, maintenance_status, log_description,
            summarized_log, failure_rate, maintenance_cost, downtime_hours,
            summarization_time_saved,
        ])

    maint_header = [
        "record_id", "log_date", "equipment_id", "technician_id", "customer_id",
        "erp_order_id", "maintenance_type", "maintenance_status", "log_description",
        "summarized_log", "failure_rate", "maintenance_cost", "downtime_hours",
        "summarization_time_saved",
    ]
    fts_path = write_csv(seed_path("energy", "fts_records.csv"), maint_header, maint_rows)
    # loglynx mirrors fts_records byte-for-byte -- write the identical rows.
    loglynx_path = write_csv(seed_path("energy", "loglynx.csv"), maint_header, maint_rows)

    return {
        "commodity_prices": {"path": price_path, "rows": price_rows, "header": price_header},
        "fts_records": {"path": fts_path, "rows": maint_rows, "header": maint_header},
        "loglynx": {"path": loglynx_path, "rows": maint_rows, "header": maint_header},
    }


# ===========================================================================
# Financial services: trimmed scale, all documented quirks/joins preserved
# ===========================================================================
def generate_financial_services():
    n_customers = 250
    n_institutions = 20
    n_relationships = 700
    n_months = 36
    n_loans = 3000
    n_deposits = 3000
    n_fpr = 750

    segments = ["Retail", "Small Business", "Corporate", "High Net Worth", "Institutional"]
    income_brackets = ["Low", "Middle", "High", "Ultra-High"]
    education_levels = ["High School", "Bachelor's", "Master's", "Doctorate", "Trade School"]
    employment_sectors = [
        "Technology", "Healthcare", "Manufacturing", "Retail", "Government",
        "Finance", "Education", "Construction",
    ]

    def credit_band(score):
        if score >= 800:
            return "Excellent (800-850)"
        if score >= 740:
            return "Very Good (740-799)"
        if score >= 670:
            return "Good (670-739)"
        if score >= 580:
            return "Fair (580-669)"
        return "Poor (300-579)"

    # ---- customers ----------------------------------------------------------
    customer_ids = [f"CUST-C{i + 1:04d}" for i in range(n_customers)]
    customer_rows = []
    for cid in customer_ids:
        credit_score = RNG.randint(300, 850)
        customer_rows.append([
            cid, "Stable Prime Customer", RNG.choice(segments), RNG.choice(income_brackets),
            credit_band(credit_score), RNG.choice(education_levels), RNG.choice(employment_sectors),
            round(RNG.uniform(20000, 350000), 2), credit_score, round(RNG.uniform(0.0, 1.0), 4),
            RNG.randint(1, 40), RNG.randint(1, 20), RNG.randint(0, 5), RNG.randint(0, 8),
            RNG.choice(["True", "False"]), RNG.choice(["True", "False"]),
        ])
    customer_header = [
        "customer_id", "customer_name", "segment", "income_bracket", "credit_score_range",
        "education_level", "employment_sector", "annual_income", "credit_score",
        "debt_to_income_ratio", "years_of_credit_history", "num_credit_accounts",
        "num_delinquencies_last_2_years", "num_recent_inquiries", "is_homeowner",
        "has_previous_bankruptcy",
    ]
    customer_path = write_csv(seed_path("financial_services", "risk_assess_customers.csv"), customer_header, customer_rows)

    # ---- institutions ---------------------------------------------------------
    institution_ids = [f"INST-{i + 1:03d}" for i in range(n_institutions)]
    inst_types = ["Bank", "Credit Union", "Insurance Company", "Investment Firm"]
    inst_sizes = ["Small", "Medium", "Large", "Global"]
    regions = ["North America", "Europe", "Asia Pacific", "Latin America", "Middle East & Africa", "International"]
    inst_rows = []
    for iid in institution_ids:
        risk_appetite = round(RNG.uniform(0.17, 0.68), 4)
        inst_rows.append([
            iid, f"{iid} Financial Group", RNG.choice(inst_types), RNG.choice(inst_sizes),
            RNG.choice(regions), RNG.choice(["Model A", "Model B", "Model C"]),
            round(RNG.uniform(1, 500), 4), round(RNG.uniform(0.1, 20), 4), RNG.randint(2, 120),
            round(RNG.uniform(2, 15), 4), risk_appetite, RNG.randint(1, 5), RNG.randint(1, 100),
            round(RNG.uniform(0.1, 5), 4), round(RNG.uniform(0.5, 8), 4),
        ])
    inst_header = [
        "institution_id", "institution_name", "institution_type", "institution_size", "region",
        "primary_risk_model", "assets_under_management_billions", "customer_base_millions",
        "years_in_operation", "avg_customer_lifetime_years", "risk_appetite", "regulatory_rating",
        "digital_maturity_score", "fraud_loss_percentage", "default_rate_percentage",
    ]
    inst_path = write_csv(seed_path("financial_services", "risk_assess_financial_institutions.csv"), inst_header, inst_rows)

    # ---- risk_profiles (relationships) + performance_metrics (1:1) -----------
    product_types = ["Personal Loan", "Mortgage", "Credit Card", "Business Loan", "Line of Credit"]
    risk_patterns = ["Stable", "Improving", "Deteriorating", "Volatile"]
    n_very_high = max(1, n_relationships // 8)  # keep 'Very High' tier present (HOL_BUG_FS_03)
    n_unassessed_target = round(n_relationships * 2 / 3)  # ~two thirds blank, as documented

    relationships = []  # (risk_profile_id, customer_id, institution_id, product_type)
    risk_rows = []
    perf_rows = []
    unassessed_budget = n_unassessed_target
    very_high_budget = n_very_high
    used_keys = set()

    for i in range(n_relationships):
        rpid = i + 1
        # (customer_id, institution_id, product_type) must be unique across
        # relationships -- it's the join key performance_metrics matches 1:1.
        while True:
            cid = RNG.choice(customer_ids)
            iid = RNG.choice(institution_ids)
            ptype = RNG.choice(product_types)
            key = (cid, iid, ptype)
            if key not in used_keys:
                used_keys.add(key)
                break
        relationships.append((rpid, cid, iid, ptype))

        if very_high_budget > 0 and (i % max(1, n_relationships // n_very_high) == 0):
            very_high_budget -= 1
            base_risk_score = round(RNG.uniform(0.80, 0.99), 4)
        else:
            base_risk_score = round(RNG.uniform(0.0, 0.79), 4)

        total_exposure = round(RNG.choice([
            RNG.uniform(1000, 9999), RNG.uniform(10000, 99999),
            RNG.uniform(100000, 999999), RNG.uniform(1000000, 5000000),
        ]), 2)
        relationship_length_months = RNG.randint(1, 120)
        products_held = RNG.randint(1, 5)
        repayment_history_score = RNG.randint(1, 10)
        recent_transaction_volatility = round(RNG.uniform(0.0, 1.0), 4)
        primary_risk_factors = "Debt-to-income;Payment history"
        risk_factor_weights = "{'income': 0.3, 'credit_history': 0.4, 'collateral': 0.3}"

        is_unassessed = unassessed_budget > 0 and (i % max(1, n_relationships // n_unassessed_target) != 0)
        if is_unassessed:
            unassessed_budget -= 1
            collateral_quality_score = ""
            liquidity_ratio = ""
            projected_cash_flow_rating = ""
        else:
            collateral_quality_score = round(RNG.uniform(0.0, 1.0), 4)
            liquidity_ratio = round(RNG.uniform(0.0, 2.0), 4)
            projected_cash_flow_rating = round(RNG.uniform(0.0, 1.0), 4)

        risk_rows.append([
            rpid, cid, iid, ptype, RNG.choice(risk_patterns), base_risk_score, total_exposure,
            relationship_length_months, products_held, repayment_history_score,
            recent_transaction_volatility, collateral_quality_score, liquidity_ratio,
            projected_cash_flow_rating, primary_risk_factors, risk_factor_weights,
        ])

        perf_rows.append([
            rpid, cid, iid, ptype, round(RNG.uniform(0.0, 1.0), 4), round(RNG.uniform(0.0, 0.3), 4),
            RNG.choice(["Improving", "Stable", "Worsening"]), round(RNG.uniform(-10, 10), 4),
            round(RNG.uniform(0.0, 0.2), 4), round(RNG.uniform(0.0, 15), 4), round(RNG.uniform(60, 99), 4),
            round(RNG.uniform(40, 99), 4), RNG.choice(["Approve", "Approve with Conditions", "Deny"]),
            round(RNG.uniform(1000, 50000), 2), round(RNG.uniform(10000, 500000), 2),
            round(RNG.uniform(0.0, 1.0), 4), total_exposure, round(RNG.uniform(-0.1, 0.3), 4),
            RNG.randint(18, 161), RNG.choice(["Bronze", "Silver", "Gold", "Platinum"]),
            RNG.choice(["Cross-sell", "Upsell", "Retention", "None"]),
            RNG.choice(["Low", "Medium", "High"]),
        ])

    risk_header = [
        "risk_profile_id", "customer_id", "institution_id", "product_type", "risk_pattern",
        "base_risk_score", "total_exposure", "relationship_length_months", "products_held",
        "repayment_history_score", "recent_transaction_volatility", "collateral_quality_score",
        "liquidity_ratio", "projected_cash_flow_rating", "primary_risk_factors",
        "risk_factor_weights",
    ]
    risk_path = write_csv(seed_path("financial_services", "risk_assess_risk_profiles.csv"), risk_header, risk_rows)

    perf_header = [
        "performance_id", "customer_id", "institution_id", "product_type", "avg_risk_score",
        "risk_score_volatility", "risk_trend", "risk_trend_percentage", "avg_fraud_probability",
        "anomaly_percentage", "risk_assessment_accuracy", "approval_percentage",
        "most_common_recommendation", "avg_monthly_transaction_volume", "total_transaction_volume",
        "transaction_volatility", "total_exposure", "risk_adjusted_return", "customer_value_score",
        "customer_value_category", "optimization_opportunity", "optimization_priority",
    ]
    perf_path = write_csv(seed_path("financial_services", "risk_assess_performance_metrics.csv"), perf_header, perf_rows)

    # ---- monthly_assessments: 700 relationships x 36 months ------------------
    month_start = date(2022, 1, 1)
    approval_choices_low_risk = ["Approve", "Approve with Conditions", "Approve with Strict Conditions"]
    anomaly_types = ["Unusual Transaction Pattern", "Rapid Score Change", "Behavioral Deviation"]
    monthly_rows = []
    assessment_id = 0
    for (rpid, cid, iid, ptype) in relationships:
        current_score = round(RNG.uniform(0.1, 0.6), 4)
        for m in range(n_months):
            assessment_id += 1
            month_num = ((month_start.month - 1 + m) % 12) + 1
            year_num = month_start.year + (month_start.month - 1 + m) // 12
            assessment_date = date(year_num, month_num, 1)

            if m == 0:
                risk_change_str = ""  # blank on the first assessment of every relationship
            else:
                delta = round(RNG.uniform(-0.05, 0.05), 4)
                new_score = min(0.99, max(0.01, current_score + delta))
                risk_change_str = f"{round(new_score - current_score, 4)}"
                current_score = new_score

            if current_score >= 0.80:
                risk_level = "Very High"
            elif current_score >= 0.60:
                risk_level = "High"
            elif current_score >= 0.40:
                risk_level = "Moderate"
            elif current_score >= 0.20:
                risk_level = "Low"
            else:
                risk_level = "Very Low"

            is_anomaly = RNG.random() < 0.05
            anomaly_type = RNG.choice(anomaly_types) if is_anomaly else "None"

            if current_score < 0.20:
                approval_recommendation = RNG.choice(approval_choices_low_risk)
            else:
                approval_recommendation = RNG.choice(approval_choices_low_risk + ["Deny"])

            monthly_rows.append([
                assessment_id, cid, iid, iso(assessment_date), month_num, year_num,
                round(current_score, 4), risk_level, round(RNG.uniform(0.0, 0.3), 4),
                risk_change_str, "True" if is_anomaly else "False", anomaly_type,
                round(RNG.uniform(500, 50000), 2), RNG.randint(1, 200), approval_recommendation,
                round(RNG.uniform(0.5, 1.0), 4), "Income stability;Payment history",
            ])

    monthly_header = [
        "assessment_id", "customer_id", "institution_id", "date", "month", "year",
        "current_risk_score", "risk_level", "fraud_probability", "risk_change_from_previous",
        "is_anomaly", "anomaly_type", "monthly_transaction_volume", "transaction_count",
        "approval_recommendation", "approval_confidence", "primary_explanation_factors",
    ]
    monthly_path = write_csv(
        seed_path("financial_services", "risk_assess_monthly_assessments.csv"), monthly_header, monthly_rows
    )

    # ---- loan.csv: 3,000 rows, PII redundancy preserved -----------------------
    grades = ["A", "B", "C", "D", "E", "F", "G"]
    purposes = [
        "debt_consolidation", "credit_card", "home_improvement", "major_purchase",
        "small_business", "car", "medical", "moving", "vacation", "house",
        "wedding", "renewable_energy", "educational", "other",
    ]
    home_ownerships = ["MORTGAGE", "RENT", "OWN", "OTHER", "NONE"]
    verification_statuses = ["Verified", "Source Verified", "Not Verified"]
    states = ["CA", "TX", "NY", "FL", "IL", "PA", "OH", "GA", "NC", "MI"]
    months_abbrev = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    loan_rows = []
    for i in range(n_loans):
        loan_id = i + 1
        ssn_value = f"{100000000 + i}"  # shared across ssn / social_security_number / ssnumber
        ssnumber1_value = f"{900000000 + i}"  # deliberately different
        dl_value = f"DL{500000 + i}"  # shared across dl / drivers_license
        grade = RNG.choice(grades)
        sub_grade = f"{grade}{RNG.randint(1, 5)}"
        loan_status = RNG.choices(
            ["Fully Paid", "Current", "Charged Off"], weights=[55, 31, 14]
        )[0]
        pub_rec_bankruptcies = "NA" if RNG.random() < 0.3 else str(RNG.randint(0, 2))
        issue_year = RNG.randint(8, 18)  # 'YY' -> 2008-2018

        loan_rows.append([
            loan_id, round(RNG.uniform(500, 35000), 2), f" {RNG.choice(['36', '60'])} months",
            f"{round(RNG.uniform(5.42, 24.59), 2)}%", grade, sub_grade,
            round(RNG.uniform(20000, 200000), 2), round(RNG.uniform(0, 29.99), 2),
            RNG.choice(home_ownerships), RNG.choice(states), RNG.choice(purposes), loan_status,
            RNG.randint(0, 4), RNG.randint(0, 3), pub_rec_bankruptcies,
            f"{round(RNG.uniform(0, 99.9), 2)}%", RNG.randint(1, 30), RNG.randint(2, 60),
            RNG.choice(verification_statuses), f"{RNG.choice(months_abbrev)}-{issue_year:02d}",
            # deliberately-excluded-upstream PII columns, kept in the seed for fidelity:
            ssn_value, ssn_value, ssn_value, ssnumber1_value, dl_value, dl_value,
            f"MEMBER-{loan_id}", RNG.choice(["Retail Associate", "Software Engineer", "Nurse", "Driver"]),
            "Debt consolidation loan", "Borrower-written description of the loan purpose.",
            f"{RNG.randint(100, 999)}", f"https://example.com/loan/{loan_id}",
        ])

    loan_header = [
        "id", "funded_amnt", "term", "int_rate", "grade", "sub_grade", "annual_inc", "dti",
        "home_ownership", "addr_state", "purpose", "loan_status", "delinq_2yrs", "pub_rec",
        "pub_rec_bankruptcies", "revol_util", "open_acc", "total_acc", "verification_status",
        "issue_d", "social_security_number", "ssn", "ssnumber", "ssnumber1", "drivers_license",
        "dl", "member_id", "emp_title", "title", "c_desc", "zip_code", "c_url",
    ]
    loan_path = write_csv(seed_path("financial_services", "loan.csv"), loan_header, loan_rows)

    # ---- predict_term_deposit.csv: 3,000 rows, age sentinels preserved -------
    jobs = [
        "management", "technician", "blue-collar", "admin.", "services", "retired",
        "self-employed", "entrepreneur", "unemployed", "housemaid", "student", "unknown",
    ]
    months_lower = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    deposit_rows = []
    for i in range(n_deposits):
        contact_id = i + 1
        if i == 0:
            age = 999
        elif i in (1, 2, 3):
            age = -1
        else:
            age = RNG.randint(18, 95)
        pdays = -1 if RNG.random() < 0.4 else RNG.randint(1, 400)
        y = "yes" if RNG.random() < 0.117 else "no"

        poutcome = RNG.choice(["success", "failure", "other", "unknown"])
        deposit_rows.append([
            contact_id, RNG.choice(jobs), RNG.choice(["married", "single", "divorced"]),
            RNG.choice(["primary", "secondary", "tertiary", "unknown"]), age,
            round(RNG.uniform(-2000, 50000), 2), RNG.choice(["yes", "no"]), RNG.choice(["yes", "no"]),
            RNG.choice(["yes", "no"]), RNG.choice(["cellular", "telephone", "unknown"]),
            RNG.choice(months_lower), RNG.randint(1, 28), RNG.randint(5, 2000), RNG.randint(1, 20),
            RNG.randint(0, 10), poutcome, pdays, y,
        ])

    deposit_header = [
        "id", "job", "marital", "education", "age", "balance", "housing", "loan", "c_default",
        "contact", "month", "day", "duration", "campaign", "previous", "poutcome", "pdays", "y",
    ]
    deposit_path = write_csv(
        seed_path("financial_services", "predict_term_deposit.csv"), deposit_header, deposit_rows
    )

    # ---- fpr_records.csv: 750 rows -------------------------------------------
    product_names = ["Premium Savings", "Rewards Credit Card", "Auto Loan", "Wealth Advisory", "Term Life"]
    product_types_fpr = ["Deposit", "Credit", "Lending", "Advisory", "Insurance"]
    rec_statuses = ["Accepted", "Approved", "Rejected", "Declined", "Pending", "Open"]

    fpr_rows = []
    rec_start = date(2024, 1, 1)
    for i in range(n_fpr):
        record_id = f"FPR-{i + 1:05d}"
        cid = RNG.choice(customer_ids)
        status = RNG.choice(rec_statuses)
        rec_date = rec_start + timedelta(days=RNG.randint(0, 700))
        sold_date = rec_date + timedelta(days=RNG.randint(1, 60)) if status in ("Accepted", "Approved") else ""

        fpr_rows.append([
            record_id, cid, round(RNG.uniform(0, 100000), 2), RNG.choice(segments),
            RNG.choice(["Onboarding", "Growth", "Mature", "At Risk", "Churned"]),
            round(RNG.uniform(1, 5), 4), round(RNG.uniform(0.0, 1.0), 6), RNG.randint(0, 500),
            round(RNG.uniform(0, 200000), 2), f"PROD-FS-{(i % 50) + 1:03d}",
            RNG.choice(product_names), RNG.choice(product_types_fpr), RNG.choice(product_names),
            status, iso(rec_date), round(RNG.uniform(0.0, 1.0), 6),
            round(RNG.uniform(0, 20000), 2), iso(sold_date) if sold_date else "",
            f"Persona Customer {i + 1}", f"customer{i + 1}@example.com",
        ])

    fpr_header = [
        "record_id", "customer_id", "account_balance", "customer_segment",
        "customer_lifecycle_stage", "customer_satisfaction_score", "customer_churn_probability",
        "customer_transaction_count", "customer_transaction_value", "product_id", "product_name",
        "product_type", "product_recommendation", "product_recommendation_status",
        "product_recommendation_date", "recommendation_score", "product_sales_amount",
        "product_sales_date", "customer_name", "customer_email",
    ]
    fpr_path = write_csv(seed_path("financial_services", "fpr_records.csv"), fpr_header, fpr_rows)

    return {
        "customers": {"path": customer_path, "rows": customer_rows, "header": customer_header},
        "institutions": {"path": inst_path, "rows": inst_rows, "header": inst_header},
        "risk_profiles": {"path": risk_path, "rows": risk_rows, "header": risk_header},
        "performance_metrics": {"path": perf_path, "rows": perf_rows, "header": perf_header},
        "monthly_assessments": {"path": monthly_path, "rows": monthly_rows, "header": monthly_header},
        "loan": {"path": loan_path, "rows": loan_rows, "header": loan_header},
        "predict_term_deposit": {"path": deposit_path, "rows": deposit_rows, "header": deposit_header},
        "fpr_records": {"path": fpr_path, "rows": fpr_rows, "header": fpr_header},
        "relationships": relationships,
        "customer_ids": customer_ids,
        "institution_ids": institution_ids,
    }


# ===========================================================================
# Sanity assertions
# ===========================================================================
def run_assertions(cpg, energy, fs):
    errors = []

    # --- CPG -------------------------------------------------------------
    if len(cpg["rows"]) != 750:
        errors.append(f"cpg_records: expected 750 rows, got {len(cpg['rows'])}")

    # --- Energy ------------------------------------------------------------
    price_rows = energy["commodity_prices"]["rows"]
    if len(price_rows) != 5898:
        errors.append(f"commodity_prices: expected 5898 rows, got {len(price_rows)}")

    wti_idx = energy["commodity_prices"]["header"].index("wti_crude")
    date_idx = energy["commodity_prices"]["header"].index("date")
    wti_found = any(r[date_idx] == "2020-04-20" and r[wti_idx] == -37.63 for r in price_rows)
    if not wti_found:
        errors.append("commodity_prices: no row with date=2020-04-20 and wti_crude=-37.63")

    null_row_found = any(r[date_idx] == "2000-01-03" and r[wti_idx] == "" for r in price_rows)
    if not null_row_found:
        errors.append("commodity_prices: no fully-null row for id=1 / date=2000-01-03")

    fts_path = energy["fts_records"]["path"]
    loglynx_path = energy["loglynx"]["path"]
    with open(fts_path, "rb") as f1, open(loglynx_path, "rb") as f2:
        if f1.read() != f2.read():
            errors.append("fts_records.csv and loglynx.csv are not byte-identical")

    # --- Financial services -------------------------------------------------
    if len(fs["customers"]["rows"]) != 250:
        errors.append(f"risk_assess_customers: expected 250 rows, got {len(fs['customers']['rows'])}")
    if len(fs["institutions"]["rows"]) != 20:
        errors.append(f"risk_assess_financial_institutions: expected 20 rows, got {len(fs['institutions']['rows'])}")
    if len(fs["risk_profiles"]["rows"]) != 700:
        errors.append(f"risk_assess_risk_profiles: expected 700 rows, got {len(fs['risk_profiles']['rows'])}")
    if len(fs["performance_metrics"]["rows"]) != 700:
        errors.append(f"risk_assess_performance_metrics: expected 700 rows, got {len(fs['performance_metrics']['rows'])}")
    if len(fs["monthly_assessments"]["rows"]) != 700 * 36:
        errors.append(
            f"risk_assess_monthly_assessments: expected {700*36} rows, "
            f"got {len(fs['monthly_assessments']['rows'])}"
        )
    if len(fs["loan"]["rows"]) != 3000:
        errors.append(f"loan: expected 3000 rows, got {len(fs['loan']['rows'])}")
    if len(fs["predict_term_deposit"]["rows"]) != 3000:
        errors.append(f"predict_term_deposit: expected 3000 rows, got {len(fs['predict_term_deposit']['rows'])}")
    if len(fs["fpr_records"]["rows"]) != 750:
        errors.append(f"fpr_records: expected 750 rows, got {len(fs['fpr_records']['rows'])}")

    # Zero-orphan referential integrity: every relationship's customer_id and
    # institution_id must exist in the dimension tables.
    customer_id_set = set(fs["customer_ids"])
    institution_id_set = set(fs["institution_ids"])
    orphans = [
        (cid, iid) for (_rpid, cid, iid, _ptype) in fs["relationships"]
        if cid not in customer_id_set or iid not in institution_id_set
    ]
    if orphans:
        errors.append(f"risk_assess_risk_profiles: {len(orphans)} orphaned relationships found")

    # performance_metrics must be 1:1 with risk_profiles on (customer_id, institution_id, product_type)
    risk_keys = {(r[1], r[2], r[3]) for r in fs["risk_profiles"]["rows"]}
    perf_keys = [(r[1], r[2], r[3]) for r in fs["performance_metrics"]["rows"]]
    perf_keys_set = set(perf_keys)
    if len(perf_keys) != len(perf_keys_set):
        errors.append("risk_assess_performance_metrics: duplicate (customer,institution,product) keys -- not 1:1")
    if perf_keys_set != risk_keys:
        errors.append("risk_assess_performance_metrics: key set does not match risk_profiles exactly (1:1 join broken)")

    # monthly_assessments: every relationship has exactly 36 rows, no fanout/no loss
    from collections import Counter
    monthly_keys = Counter(
        (r[1], r[2]) for r in fs["monthly_assessments"]["rows"]
    )
    # Multiple relationships can share the same (customer,institution) pair if a
    # customer holds >1 product at the same institution; monthly rows are keyed
    # by (customer,institution) only, so a pair should have a multiple of 36 rows.
    distinct_customer_institution_pairs = {(cid, iid) for (_r, cid, iid, _p) in fs["relationships"]}
    for pair in distinct_customer_institution_pairs:
        if monthly_keys.get(pair, 0) % 36 != 0 or monthly_keys.get(pair, 0) == 0:
            errors.append(f"risk_assess_monthly_assessments: pair {pair} does not have a clean multiple of 36 rows")
            break

    # loan.csv PII redundancy
    loan_header = fs["loan"]["header"]
    i_ssn = loan_header.index("ssn")
    i_ssnum = loan_header.index("ssnumber")
    i_social = loan_header.index("social_security_number")
    i_ssnum1 = loan_header.index("ssnumber1")
    i_dl = loan_header.index("dl")
    i_drivers = loan_header.index("drivers_license")
    for r in fs["loan"]["rows"][:5]:
        if not (r[i_ssn] == r[i_ssnum] == r[i_social]):
            errors.append("loan: ssn/ssnumber/social_security_number are not identical")
            break
        if r[i_ssnum1] == r[i_ssn]:
            errors.append("loan: ssnumber1 should differ from ssn/ssnumber/social_security_number")
            break
        if r[i_dl] != r[i_drivers]:
            errors.append("loan: dl/drivers_license are not identical")
            break

    # predict_term_deposit age sentinels present
    deposit_header = fs["predict_term_deposit"]["header"]
    i_age = deposit_header.index("age")
    ages = [r[i_age] for r in fs["predict_term_deposit"]["rows"]]
    if 999 not in ages:
        errors.append("predict_term_deposit: no row with age=999")
    if ages.count(-1) < 2:
        errors.append("predict_term_deposit: fewer than 2 rows with age=-1")

    return errors


def main():
    cpg = generate_cpg()
    energy = generate_energy()
    fs = generate_financial_services()

    errors = run_assertions(cpg, energy, fs)
    if errors:
        print("FAILED sanity assertions:")
        for e in errors:
            print(f"  - {e}")
        raise SystemExit(1)

    print("Seed data generated and verified:")
    print(f"  cpg_records.csv                         {len(cpg['rows']):>7} rows")
    print(f"  energy/commodity_prices.csv             {len(energy['commodity_prices']['rows']):>7} rows")
    print(f"  energy/fts_records.csv                  {len(energy['fts_records']['rows']):>7} rows")
    print(f"  energy/loglynx.csv                      {len(energy['loglynx']['rows']):>7} rows  (byte-identical to fts_records)")
    print(f"  fs/risk_assess_customers.csv             {len(fs['customers']['rows']):>7} rows")
    print(f"  fs/risk_assess_financial_institutions.csv {len(fs['institutions']['rows']):>5} rows")
    print(f"  fs/risk_assess_risk_profiles.csv         {len(fs['risk_profiles']['rows']):>7} rows")
    print(f"  fs/risk_assess_performance_metrics.csv   {len(fs['performance_metrics']['rows']):>7} rows")
    print(f"  fs/risk_assess_monthly_assessments.csv   {len(fs['monthly_assessments']['rows']):>7} rows")
    print(f"  fs/loan.csv                              {len(fs['loan']['rows']):>7} rows")
    print(f"  fs/predict_term_deposit.csv              {len(fs['predict_term_deposit']['rows']):>7} rows")
    print(f"  fs/fpr_records.csv                       {len(fs['fpr_records']['rows']):>7} rows")


if __name__ == "__main__":
    main()
