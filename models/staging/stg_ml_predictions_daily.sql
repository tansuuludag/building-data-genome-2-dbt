select
    building_id,
    date,
    actual_kwh,
    baseline_kwh,
    ml_kwh,
    expected_kwh,
    use_ml,
    model_run_at
from {{ source('bdg2_ml', 'predictions_daily') }}