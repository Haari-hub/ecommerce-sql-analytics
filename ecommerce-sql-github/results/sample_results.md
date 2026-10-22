# Sample Query Results

Representative output from running the analysis scripts against the included
dataset (20,000 customers, 42,877 orders, 89,136 order items, 370,502 events).

## Revenue: YoY growth by month (from 01_revenue_trends.sql, Q2)
```
 calendar_month |  yr  |  revenue   | yoy_growth_pct 
----------------+------+------------+----------------
 Jan            | 2025 |  159002.65 |               
 Feb            | 2025 |  181458.19 |               
 Mar            | 2025 |  215514.09 |               
 Apr            | 2025 |  262015.26 |               
 May            | 2025 |  295037.13 |               
 Jun            | 2025 |  338021.47 |               
 Jul            | 2025 |  326088.09 |               
 Aug            | 2025 |  354907.01 |               
 Sep            | 2025 |  408520.92 |               
 Oct            | 2025 |  515330.31 |               
 Nov            | 2025 |  797468.29 |               
 Dec            | 2025 | 1173071.94 |               
(12 rows)

```

## RFM segments (from 03_rfm_segmentation.sql, Q2)
```
        segment         | customers | pct_cust | revenue | pct_rev 
------------------------+-----------+----------+---------+---------
 Champions              |      3307 |     25.8 | 3302554 |    51.6
 Loyal                  |      2760 |     21.5 | 1348430 |    21.1
 At Risk (was valuable) |       702 |      5.5 |  521904 |     8.1
 Needs Attention        |      1699 |     13.2 |  418098 |     6.5
 Hibernating / Churned  |      3156 |     24.6 |  382686 |     6.0
 Cannot Lose Them       |       347 |      2.7 |  232734 |     3.6
 New / Promising        |       861 |      6.7 |  199122 |     3.1
(7 rows)

```

## Conversion funnel (from 05_funnel_conversion.sql, Q1)
```
    stage    | sessions | pct_of_top | step_conv_pct 
-------------+----------+------------+---------------
 View        |   150000 |      100.0 |              
 Add to Cart |    44138 |       29.4 |          29.4
 Checkout    |    26358 |       17.6 |          59.7
 Purchase    |    18048 |       12.0 |          68.5
(4 rows)

```

## Category scorecard: revenue vs margin vs returns (from 06_product_abc_pareto.sql, Q3)
```
   category_name   | revenue | margin_pct | return_rate_pct 
-------------------+---------+------------+-----------------
 Electronics       | 1976315 |        5.6 |             4.1
 Home & Kitchen    |  926694 |       35.8 |             6.2
 Apparel           |  692782 |       52.3 |            17.7
 Health            |  645254 |       34.9 |             4.2
 Accessories       |  612481 |       47.2 |             9.0
 Sports & Outdoors |  593087 |       39.1 |             8.6
 Beauty            |  328906 |       57.6 |             5.4
 Grocery           |  253348 |       19.2 |             2.1
 Toys & Games      |  224715 |       41.4 |             7.6
 Books             |  151944 |       31.1 |             3.2
(10 rows)

```

## Market basket: category affinity by lift (from 07_market_basket.sql, Q1)
```
 category_a  |    category_b     | orders_together | lift 
-------------+-------------------+-----------------+------
 Electronics | Accessories       |            1335 | 1.44
 Apparel     | Accessories       |            2920 | 1.32
 Grocery     | Health            |            3746 | 1.27
 Beauty      | Health            |            2784 | 1.26
 Apparel     | Sports & Outdoors |            1447 | 1.22
 Books       | Toys & Games      |             898 | 0.90
(6 rows)

```

## Churn: lifecycle status & revenue at risk (from 08_retention_and_churn.sql, Q1)
```
  lifecycle_status   | customers | pct_cust | revenue_in_group | pct_of_revenue 
---------------------+-----------+----------+------------------+----------------
 1. Active (<=90d)   |      6715 |     52.3 |          4558337 |           71.2
 2. Lapsed (91-180d) |      1850 |     14.4 |           810501 |           12.7
 3. Churned (>180d)  |      4267 |     33.3 |          1036689 |           16.2
(3 rows)

```
