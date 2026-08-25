-- ---------------------------------------------------------------------------
-- sv_cpg_commercial_performance
--
-- A Snowflake Semantic View, defined as a dbt model.
--
-- This is one of the two ways this lab defines meaning. Here the metric
-- definitions live inside Snowflake as a native object, and Cortex Analyst
-- reads them directly. The other way is the `semantic_model:` and `metrics:`
-- blocks in _cpg__marts.yml, where the same ideas are expressed as dbt
-- Semantic Layer (MetricFlow) specs and served through the dbt MCP Server.
-- Read that file alongside this one to compare them.
--
-- The `semantic_view` materialization comes from the Snowflake-Labs
-- dbt_semantic_view package. It is a direct passthrough to Snowflake's
-- CREATE SEMANTIC VIEW syntax:
-- https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view
--
-- FACTS are row-level expressions. METRICS are aggregations over those facts.
-- DIMENSIONS are what you group by. Synonyms and comments are not decoration:
-- they are what Cortex Analyst reads to map a plain-English question onto the
-- right column.
-- ---------------------------------------------------------------------------

{{ config(materialized='semantic_view') }}

TABLES (

    orders AS {{ ref('cpg_order_performance') }}
        PRIMARY KEY (record_id)
        WITH SYNONYMS = ('orders', 'sales', 'order lines', 'transactions')
        COMMENT = 'One row per order line, with the commercial measures for that line.',

    inventory AS {{ ref('cpg_product_inventory_health') }}
        PRIMARY KEY (record_id)
        WITH SYNONYMS = ('inventory', 'stock', 'supply', 'product availability')
        COMMENT = 'One row per product occurrence, with stockout and overstock risk.'

)

RELATIONSHIPS (

    orders_to_inventory AS
        orders (record_id) REFERENCES inventory (record_id)

)

FACTS (

    -- ---- order-line facts ---------------------------------------------------
    orders.line_order_total AS orders.order_total
        COMMENT = 'Gross value of the order line in USD, including cancelled orders.',

    orders.line_recognised_revenue AS orders.recognised_revenue
        COMMENT = 'Value of the order line in USD, zero for cancelled orders.',

    orders.line_customer_lifetime_value AS orders.customer_lifetime_value
        COMMENT = 'Modelled lifetime value of the customer on this order line.',

    orders.line_product_rating AS orders.product_rating
        COMMENT = 'Average product rating on this order line, 1 to 5.',

    orders.line_units AS orders.implied_units
        COMMENT = 'Units implied by dividing order value by unit price.',

    orders.fulfilled_flag AS CASE WHEN orders.is_fulfilled_order THEN 1 ELSE 0 END
        COMMENT = 'One when the order shipped or was delivered, otherwise zero.',

    orders.cancelled_flag AS CASE WHEN orders.is_cancelled_order THEN 1 ELSE 0 END
        COMMENT = 'One when the order was cancelled, otherwise zero.',

    -- ---- inventory facts ----------------------------------------------------
    inventory.product_stockout_rate AS inventory.stockout_rate
        COMMENT = 'Share of periods the product was out of stock, 0 to 1.',

    inventory.product_overstock_rate AS inventory.overstock_rate
        COMMENT = 'Share of periods the product was overstocked, 0 to 1.',

    inventory.product_inventory_turnover AS inventory.inventory_turnover
        COMMENT = 'Inventory turns per period for the product.',

    inventory.product_inventory_level AS inventory.inventory_level
        COMMENT = 'Units on hand for the product.',

    inventory.product_coverage_ratio AS inventory.inventory_coverage_ratio
        COMMENT = 'Units on hand divided by forecast demand.',

    inventory.planner_review_flag AS CASE WHEN inventory.needs_planner_review THEN 1 ELSE 0 END
        COMMENT = 'One when the product is high stockout or high overstock risk.'

)

DIMENSIONS (

    -- ---- time ----------------------------------------------------------------
    orders.order_date AS orders.order_date
        WITH SYNONYMS = ('order date', 'date', 'when the order was placed')
        COMMENT = 'Date the order was placed.',

    -- ---- commercial dimensions -----------------------------------------------
    orders.order_status AS orders.order_status
        WITH SYNONYMS = ('status', 'order state', 'fulfilment status')
        COMMENT = 'Delivered, Shipped, Pending or Cancelled.',

    orders.customer_segment AS orders.customer_segment
        WITH SYNONYMS = ('segment', 'customer tier', 'customer value tier')
        COMMENT = 'High-Value, Medium-Value or Low-Value.',

    orders.product_category AS orders.product_category
        WITH SYNONYMS = ('category', 'merchandising category', 'product group')
        COMMENT = 'Top-level merchandising category, for example Grocery or Beauty.',

    orders.product_subcategory AS orders.product_subcategory
        WITH SYNONYMS = ('subcategory', 'sub category')
        COMMENT = 'Merchandising subcategory.',

    orders.order_value_band AS orders.order_value_band
        WITH SYNONYMS = ('order size', 'basket size band', 'value band')
        COMMENT = 'Large, Medium or Small, based on order value.',

    -- ---- inventory dimensions -------------------------------------------------
    inventory.stockout_risk_level AS inventory.stockout_risk_level
        WITH SYNONYMS = ('stockout risk', 'out of stock risk', 'availability risk')
        COMMENT = 'High, Elevated or Low risk of running out of stock.',

    inventory.overstock_risk_level AS inventory.overstock_risk_level
        WITH SYNONYMS = ('overstock risk', 'excess stock risk')
        COMMENT = 'High, Elevated or Low risk of holding excess stock.',

    inventory.inventory_product_category AS inventory.product_category
        WITH SYNONYMS = ('inventory category', 'category of the product in stock')
        COMMENT = 'Merchandising category, as seen from the inventory table.'

)

METRICS (

    -- ---- commercial metrics ---------------------------------------------------
    orders.total_order_value AS SUM(orders.line_order_total)
        WITH SYNONYMS = ('total sales', 'gross order value', 'total order value')
        COMMENT = 'Sum of order value across all order lines, including cancellations.',

    orders.total_recognised_revenue AS SUM(orders.line_recognised_revenue)
        WITH SYNONYMS = ('revenue', 'net revenue', 'recognised revenue')
        COMMENT = 'Sum of order value excluding cancelled orders. Use this for revenue.',

    orders.order_count AS COUNT(orders.record_id)
        WITH SYNONYMS = ('number of orders', 'order volume', 'how many orders')
        COMMENT = 'Number of order lines.',

    orders.average_order_value AS SUM(orders.line_order_total) / NULLIF(COUNT(orders.record_id), 0)
        WITH SYNONYMS = ('AOV', 'average basket', 'average order value')
        COMMENT = 'Total order value divided by the number of order lines.',

    orders.average_customer_lifetime_value AS AVG(orders.line_customer_lifetime_value)
        WITH SYNONYMS = ('average LTV', 'average customer lifetime value', 'CLV')
        COMMENT = 'Average modelled lifetime value of the customers on these orders.',

    orders.average_product_rating AS AVG(orders.line_product_rating)
        WITH SYNONYMS = ('average rating', 'product rating', 'customer rating')
        COMMENT = 'Average product rating across order lines, 1 to 5.',

    orders.fulfilment_rate AS SUM(orders.fulfilled_flag) / NULLIF(COUNT(orders.record_id), 0)
        WITH SYNONYMS = ('fulfilment rate', 'fill rate', 'share of orders shipped')
        COMMENT = 'Share of order lines that shipped or were delivered, 0 to 1.',

    orders.cancellation_rate AS SUM(orders.cancelled_flag) / NULLIF(COUNT(orders.record_id), 0)
        WITH SYNONYMS = ('cancellation rate', 'cancel rate', 'share of orders cancelled')
        COMMENT = 'Share of order lines that were cancelled, 0 to 1.',

    -- ---- inventory metrics ------------------------------------------------------
    inventory.average_stockout_rate AS AVG(inventory.product_stockout_rate)
        WITH SYNONYMS = ('stockout rate', 'average stockout rate', 'out of stock rate')
        COMMENT = 'Average share of periods products were out of stock, 0 to 1.',

    inventory.average_overstock_rate AS AVG(inventory.product_overstock_rate)
        WITH SYNONYMS = ('overstock rate', 'average overstock rate', 'excess stock rate')
        COMMENT = 'Average share of periods products were overstocked, 0 to 1.',

    inventory.average_inventory_turnover AS AVG(inventory.product_inventory_turnover)
        WITH SYNONYMS = ('inventory turnover', 'stock turns', 'turnover')
        COMMENT = 'Average inventory turns per period.',

    inventory.total_inventory_units AS SUM(inventory.product_inventory_level)
        WITH SYNONYMS = ('units on hand', 'total stock', 'inventory units')
        COMMENT = 'Total units on hand across products.',

    inventory.products_needing_review AS SUM(inventory.planner_review_flag)
        WITH SYNONYMS = ('products at risk', 'products needing review', 'planner worklist')
        COMMENT = 'Number of products flagged as high stockout or high overstock risk.'

)

COMMENT = 'Commercial and inventory performance for the consumer packaged goods track of the Openflow, Snowflake and dbt hands-on lab.'
