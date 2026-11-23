# Building Data Genome 2 – Energy Waste by Building

**Question:** How much of the energy bill is wasted, and in which building?

We learn each building's normal electricity use from 2016 and predict what it *should* use in 2017. The gap between actual and expected use shows possible waste, in kWh and in dollars.

## Pipeline

```
GitHub (BDG2 raw CSV)
   │  Colab: load
   ▼
BigQuery  bdg2_raw
   │  dbt: staging → intermediate → marts
   ▼
BigQuery  marts (dim_building, fct_building_daily)
   │  Colab: LightGBM model
   ▼
BigQuery  bdg2_ml.predictions_daily
   │  dbt
   ▼
BigQuery  fct_building_scorecard  ──►  Power BI / Data Studio
```

## dbt layers

| Layer | Models | What it does |
|---|---|---|
| **Sources** | `bdg2_raw` (4 tables), `bdg2_ml` (1 table) | Raw data and model output |
| **Seeds** | `holidays`, `site_locations`, `electricity_prices` | Public holidays (US, GB, IE, CA-ON), site cities, commercial electricity prices |
| **Staging** | `stg_metadata`, `stg_weather`, `stg_electricity_raw`, `stg_electricity_clean`, `stg_ml_predictions_daily` | Rename columns, fix codes, wide → long (UNPIVOT) |
| **Intermediate** | `int_electricity_cleaned`, `int_weather_daily`, `int_building_daily` | Cleaning rule, hourly → daily, join weather, holidays and prices |
| **Marts** | `dim_building`, `fct_building_daily`, `fct_building_scorecard` | Star schema for analysis and dashboards |

### Cleaning rule

The ready-made "clean" version of BDG2 only removes all zero readings. We use our own rule:

- Zero runs of **24 hours or more** → NULL (meter or data failure). Shorter zero runs are kept (the building may really be closed).
- Readings above **5 × the building's 99th percentile** → NULL (spikes).
- A day counts only if **at least 20 of 24 hours** have data.

### Prices

| Region | Source |
|---|---|
| US states | EIA Electric Power Annual, Table 2.10 (commercial) |
| GB | BEIS Quarterly Energy Prices, Table 3.4.1 (non-domestic, excl. CCL) |
| IE | SEAI / Eurostat (non-household, excl. VAT) |
| CA-ON (Ottawa) | Hydro-Québec, Comparison of Electricity Prices (2017 = average of 2016 and 2018) |

Local currencies are converted to USD with yearly average exchange rates.

## Model

- **Baseline:** the building's 2016 average for the same day of the week.
- **LightGBM:** corrects the baseline for weather, holidays and season. One model learns all buildings together.
- **Model choice per building:** tested on 2016 Q4 before looking at 2017.
- **Metric:** CV(RMSE) (ASHRAE Guideline 14). Daily threshold: 25%.

## Results (2017)

| | |
|---|---|
| Buildings | 1,636 (1,505 with predictions, 1,423 with a full year) |
| Daily rows | 1,054,259 |
| Median CV(RMSE) | 19.7% |
| Flagged buildings | 40 (reliable model and more than 10% above expected) |
| Extra use in flagged buildings | 6.8 GWh ≈ $0.86 million |

A flagged building is a **candidate for review**, not proven waste. The use of the building may have changed.

## How to run

```bash
dbt deps
dbt seed
dbt build
```

`fct_building_scorecard` needs `bdg2_ml.predictions_daily`. Run the Colab notebook (section 9) before building it.

## Data

Miller, C. et al. (2020). *The Building Data Genome Project 2.* Scientific Data. [GitHub](https://github.com/buds-lab/building-data-genome-project-2)