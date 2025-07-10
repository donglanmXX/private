 {{ config(
    materialized = 'table'
) }}

  SELECT
    DATE(date) AS date,
    sessions,
    lead_cvr,
    (sessions * lead_cvr) AS leads
  FROM `delta-button-464815-v3.test_performance_data.raw`