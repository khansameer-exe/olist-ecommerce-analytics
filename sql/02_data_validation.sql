-- STRUCTURAL VALIDATION


-- Referential Sanity Check: To verify that every seller_id that is there in raw.order_items also exists in raw.sellers table

SELECT COUNT(DISTINCT oi.seller_id)
FROM raw.order_items oi
LEFT JOIN raw.sellers s
  ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- Referential Sanity Check: To verify that every product_id that is there in raw.order_items also exists in raw.products table

SELECT COUNT(DISTINCT oi.product_id)
FROM raw.order_items oi
LEFT JOIN raw.products p
	ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- Revenue Consistency Check: we check if the amount in raw.order_payments is similar to the sum(price + freight_value)
-- Because this indicates that If customers paid money, there must be something roughly equivalent that was sold.


SELECT
    ROUND(SUM(payment_value),2) AS total_payments
FROM raw.order_payments;

SELECT ROUND(SUM(price + freight_value), 2)
FROM raw.order_items;


-- STRUCTURAL VALIDATION


SELECT COUNT(*) AS orphan_orders
FROM raw.orders o
LEFT JOIN raw.customers c
  ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


SELECT COUNT(*) AS orphan_order_items
FROM raw.order_items oi
LEFT JOIN raw.orders o
  ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS orphan_sellers
FROM raw.order_items oi
LEFT JOIN raw.sellers s
  ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- MARKETING FUNNEL DROP OFF CHECK

-- CHECKING COUNT OF LEADS, CLOSED_DEALS AND ACTIVE_SELLERS

SELECT SUM(is_lead) AS leads,
	   SUM(is_closed_deal) AS closed_deals,
	   SUM(is_activated) AS activated_sellers
FROM analytics.seller_funnel;

-- CHECKING THE DISTRIBUTION OF churn_status

SELECT churn_status, COUNT(*)
FROM analytics.seller_funnel
WHERE is_activated = 1
GROUP BY churn_status;





