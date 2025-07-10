{{ config(
    materialized = 'table'
) }}

select channel_grouping, sum(sessions) as sessions
from delta-button-464815-v3.test_performance_data.raw
group by channel_grouping