select
    order_id,
    customer_id,
    order_date,
    status
 FROM {{ source('jaffle_shop', 'jaffle_shop_orders') }}