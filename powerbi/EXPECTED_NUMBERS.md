# Expected numbers after the first refresh

Computed with SQL directly on `ANALYTICS_PROD.MARTS` on 2026-11-16, with **both
extract batches loaded** (99,441 orders, 112,650 order items). Use them to check
the cards with no slicer selected. If only batch 1 is loaded the numbers are lower.

## Row counts per table

| Power BI table | Snowflake table | Rows |
|---|---|---|
| Order Items | `fct_order_items` | 112,650 |
| Orders | `fct_orders` | 99,441 |
| Customers | `dim_customers` | 96,096 |
| Products | `dim_products` | 32,951 |
| Sellers | `dim_sellers` | 3,095 |
| Date | `dim_date` | 1,096 (2016-01-01 to 2018-12-31) |

## Measures (no filters)

| Measure | Expected | SQL it mirrors |
|---|---|---|
| Net Revenue | R$ 13,494,401 (13,494,400.74) | `sum(net_revenue)` on `fct_order_items` |
| Orders | 98,199 | `count(distinct order_id) where is_revenue_order` |
| Average Order Value | R$ 137.42 | net revenue / orders |
| Items Sold | 112,101 | `count(*) where is_revenue_order` |
| Freight | R$ 2,241,126 (2,241,126.29) | `sum(freight_value) where is_revenue_order` |
| Customers | 94,983 | `count(distinct customer_key) where is_revenue_order` |
| Repeat Customer % | 3.0% (2,888 of 94,983) | customers with `is_repeat_customer` / customers |
| Delivered Orders | 96,476 | `count_if(is_delivered)` on `fct_orders` |
| Late Orders | 6,535 | `count_if(is_late_delivery)` |
| Late Delivery % | 6.8% (6.77%) | late / delivered |
| Avg Days to Deliver | 12.5 | `avg(days_to_deliver)` |
| Net Revenue Delivered Late | R$ 985,924 (985,924.34) | `sum(net_revenue) where is_late_delivery` |
| Reviewed Orders | 98,673 | `count(review_score)` |
| Avg Review Score | 4.09 (4.086) | `avg(review_score)` |
| Avg Review Score (On time) | 4.29 (4.290) | same, `delivery_status = 'On time'` |
| Avg Review Score (Late) | 2.27 (2.271) | same, `delivery_status = 'Late'` |
| Review Score Gap (Late vs On time) | -2.02 | late minus on time |
| Data Loaded At | 2026-11-16 16:22:57 (UTC) | `max(loaded_at)`; changes on every reload of RAW |

## Time intelligence (pick a year in the Year slicer)

| Year | Net Revenue | Orders | Net Revenue PY | Net Revenue YoY % |
|---|---|---|---|---|
| 2016 | R$ 44,726 | 293 | blank | blank |
| 2017 | R$ 6,108,492 | 44,375 | R$ 44,726 | 13557.6% |
| 2018 | R$ 7,341,182 | 53,531 | R$ 6,108,492 | 20.2% |

With no year selected `Net Revenue PY` is R$ 6,153,218 (2016 + 2017 shifted one
year forward) and the YoY % is not meaningful: always read YoY with a year selected.

## Charts

**Top 10 categories by net revenue** (page 1): Health Beauty 1,255,695 · Watches Gifts
1,198,185 · Bed Bath Table 1,035,964 · Sports Leisure 979,741 · Computers Accessories
904,322 · Furniture Decor 727,465 · Housewares 626,826 · Cool Stuff 620,770 · Auto
586,586 · Garden Tools 481,010.

**Net revenue by customer state** (page 1, first bars): SP 5,165,782 · RJ 1,811,484 ·
MG 1,573,269 · RS 742,640 · PR 675,928.

**Average review score by delivery status** (page 2): On time 4.29 (89,941 orders) ·
Late 2.27 (6,535 orders) · Not delivered 1.75 (2,965 orders).

**Late delivery % by customer state** (page 2, highest): AL 21.4% · MA 17.4% · SE 15.2% ·
PI 13.9% · CE 13.7%.

**Orders by review score** (page 2): 1 star 11,363 · 2 stars 3,131 · 3 stars 8,133 ·
4 stars 19,038 · 5 stars 57,008.
