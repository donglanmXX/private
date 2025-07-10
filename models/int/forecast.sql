 {{ config(
    materialized = 'table'
) }}

-- Clean table
WITH cleaned_data AS (
  SELECT
    DATE(date) AS date,
    sessions,
    lead_cvr,
    (sessions * lead_cvr) AS leads
  FROM {{ ref('forecast_stage') }}
  WHERE sessions IS NOT NULL AND lead_cvr IS NOT NULL
),

-- Sum leads for May so far and extrapolate (0520 excluded)
may_projection AS (
  SELECT
    SUM(leads) AS may_leads_so_far,
    COUNT(DISTINCT date) AS days_so_far
  FROM cleaned_data
  WHERE EXTRACT(YEAR FROM date) = 2025 
    AND EXTRACT(MONTH FROM date) = 5
    AND date != DATE '2025-05-20'  
),

full_may_estimate AS (
  SELECT
    DATE '2025-05-01' AS forecast_month,
    ROUND(may_leads_so_far / days_so_far * 31, 0) AS forecasted_leads
  FROM may_projection
),

-- Build monthly data for Jan–May
monthly_data AS (
  SELECT
    DATE_TRUNC(date, MONTH) AS month,
    SUM(leads) AS leads
  FROM cleaned_data
  WHERE date < '2025-05-01'
  GROUP BY month
  UNION ALL
  SELECT forecast_month, forecasted_leads FROM full_may_estimate
),

-- Add row numbers for regression
training_data AS (
  SELECT
    *,
    ROW_NUMBER() OVER (ORDER BY month) - 1 AS month_num
  FROM monthly_data
),

-- Linear regression coefficients
coefficients AS (
  SELECT
    COUNT(*) AS n,
    SUM(month_num) AS sum_x,
    SUM(leads) AS sum_y,
    SUM(month_num * leads) AS sum_xy,
    SUM(POW(month_num, 2)) AS sum_xx
  FROM training_data
),

regression AS (
  SELECT
    (n * sum_xy - sum_x * sum_y) / (n * sum_xx - POW(sum_x, 2)) AS slope,
    (sum_y - ((n * sum_xy - sum_x * sum_y) / (n * sum_xx - POW(sum_x, 2))) * sum_x) / n AS intercept
  FROM coefficients
),

-- Forecast June only
forecast_june AS (
  SELECT 5 AS month_num, DATE '2025-06-01' AS forecast_month
)

-- final
SELECT * FROM full_may_estimate
UNION ALL
SELECT
  forecast_month,
  ROUND(slope * month_num + intercept, 0) AS forecasted_leads
FROM forecast_june, regression
