-- SELLER FUNNEL ANALYTICS

-- CREATING OUR FIRST ANALYTICS VIEW

-- CREATING THE VIEW anlytics.orders_sellers

CREATE VIEW analytics.orders_sellers AS
SELECT 
	o.order_id,
	o.order_purchase_timestamp,
	o.order_status,
	oi.seller_id,
	oi.product_id,
	oi.price,
	oi.freight_value
FROM raw.orders o
JOIN raw.order_items oi
	ON o.order_id = oi.order_id;

SELECT * FROM analytics.orders_sellers
LIMIT 5;

SELECT COUNT(*) FROM analytics.orders_sellers;

-- Seller Activity Timeline
-- CREATING analytics.seller_activity VIEW 

CREATE VIEW analytics.seller_activity AS
SELECT
	seller_id,
	MIN(order_purchase_timestamp) AS first_order_date,
	MAX(order_purchase_timestamp) AS last_order_date,
	COUNT(DISTINCT order_id) AS total_orders,
	SUM(price + freight_value) AS total_revenue
FROM analytics.orders_sellers
GROUP BY seller_id;

SELECT * FROM analytics.seller_activity
ORDER BY total_orders DESC
LIMIT 5;


-- Seller Lifecycle & Churn Definition
-- Which sellers are active, retained, or churned — and why?
-- CHURN RULE: A seller is churned if they have no orders for 90 days after their last order

-- Creating a Dataset Reference Date View

CREATE VIEW analytics.dataset_reference AS
SELECT
	MAX(order_purchase_timestamp)::DATE AS dataset_end_date
FROM raw.orders;


SELECT * FROM analytics.dataset_reference;


-- CREATING SELLER CHURN STATUS LOGIC

/* LIFECYCLE STATE
	- Active → seller has sold recently (within 90 days)

	- Churned → seller inactive for ≥ 90 days

	- Retained → seller active AND has more than 1 order historically
*/


/* 
	CREATING A CTE WITH ONLY THE DATASET END DATE AND 
    COMPARING WITH ALL THE OTHER RECORDS TO UNDERSTAND THE CHURN AND THE RETENTION STATUS
*/

-- VIEW FOR seller_churn_status

CREATE VIEW analytics.seller_churn_status AS

WITH ref AS                                 -- CREATING A CTE WITH ONLY ONE RECORD OF THE dataset end date
	(
		SELECT dataset_end_date
		FROM analytics.dataset_reference
	)

SELECT
	sa.seller_id,
	sa.first_order_date,
	sa.last_order_date,
	sa.total_orders,
	sa.total_revenue,
	(ref.dataset_end_date - sa.last_order_date::DATE) AS days_since_last_order,

	CASE
		WHEN (ref.dataset_end_date - sa.last_order_date::DATE) >= 90
			THEN 'churned'
		ELSE 'active'
	END AS churn_status,

	CASE
		WHEN sa.total_orders > 1
			AND (ref.dataset_end_date - sa.last_order_date::DATE) < 90
			THEN 'retained'
		ELSE 'not_retained'
	END AS retention_status

FROM analytics.seller_activity sa
CROSS JOIN ref;


SELECT * FROM analytics.seller_churn_status
LIMIT 100;

-- FETCHING THE DISTIBUTION OF churn status

SELECT churn_status, COUNT(*) 
FROM analytics.seller_churn_status
GROUP BY churn_status;

SELECT *
FROM analytics.seller_churn_status
ORDER BY days_since_last_order DESC
LIMIT 5;


-- Create Unified Seller Funnel View

CREATE VIEW analytics.seller_funnel AS
SELECT
    ml.mql_id,
    ml.first_contact_date,
    ml.origin,
    cd.won_date,
    cd.business_segment,
    cd.lead_type,
    cd.lead_behaviour_profile,

    cd.seller_id,

    -- Funnel flags
    1 AS is_lead,
    1 AS is_mql,
    CASE WHEN cd.mql_id IS NOT NULL THEN 1 ELSE 0 END AS is_closed_deal,
    CASE WHEN s.seller_id IS NOT NULL THEN 1 ELSE 0 END AS is_activated,

    -- Seller lifecycle (nullable if not activated)
    sc.churn_status,
    sc.retention_status,
    sc.total_orders,
    sc.total_revenue,
    sc.days_since_last_order

FROM raw.marketing_leads ml
LEFT JOIN raw.closed_deals cd
    ON ml.mql_id = cd.mql_id
LEFT JOIN raw.sellers s
    ON cd.seller_id = s.seller_id
LEFT JOIN analytics.seller_churn_status sc
    ON cd.seller_id = sc.seller_id;


SELECT * FROM analytics.seller_funnel;

SELECT COUNT(*) FROM analytics.seller_funnel;


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- MARKETPLACE ANALYTICS VIEWS

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 1. CREATING analytics.order_fact
--    CENTRAL TRANSACTION TABLE


/* 
CREATE OR REPLACE VIEW analytics.order_fact AS
SELECT
    o.order_id,
    o.customer_id,
    oi.seller_id,
    o.order_purchase_timestamp,
    
    DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,

    oi.price,
    oi.freight_value,
    op.payment_value,
    op.payment_type,

    o.order_status,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date

FROM raw.orders o
JOIN raw.order_items oi
    ON o.order_id = oi.order_id
JOIN raw.order_payments op
    ON o.order_id = op.order_id;

SELECT * FROM analytics.order_fact
LIMIT 100;

*/

CREATE OR REPLACE VIEW analytics.order_fact AS

WITH order_items_agg AS (
    SELECT
        order_id,
        SUM(price) AS total_price,
        SUM(freight_value) AS total_freight
    FROM raw.order_items
    GROUP BY order_id
),

payments_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment
    FROM raw.order_payments
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,

    oi.total_price,
    oi.total_freight,
    p.total_payment,

    o.order_status,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date

FROM raw.orders o
LEFT JOIN order_items_agg oi ON o.order_id = oi.order_id
LEFT JOIN payments_agg p ON o.order_id = p.order_id;


SELECT * FROM analytics.order_fact;

SELECT * FROM information_schema.view_table_usage
WHERE view_name = 'order_fact';

-- 2. CREATING analytics.customer_orders

CREATE OR REPLACE VIEW analytics.customer_orders AS

SELECT
    c.customer_unique_id,
    f.order_id,
    f.order_purchase_timestamp,
    f.order_month,
    f.total_payment AS order_value

FROM analytics.order_fact f
JOIN raw.customers c
    ON f.customer_id = c.customer_id;

SELECT * FROM analytics.customer_orders;


-- 3. CREATING analytics.gmv_trend

CREATE OR REPLACE VIEW analytics.gmv_trend AS

SELECT
    order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_value) AS total_gmv,
    SUM(order_value) / COUNT(DISTINCT order_id) AS avg_order_value

FROM analytics.customer_orders
GROUP BY order_month;

SELECT * FROM analytics.gmv_trend;


-- 4. CREATING analytics.clv

CREATE OR REPLACE VIEW analytics.clv AS

SELECT
    customer_unique_id,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_value) AS total_revenue,
    AVG(order_value) AS avg_order_value

FROM analytics.customer_orders
GROUP BY customer_unique_id;

SELECT * FROM analytics.clv;



-- 5. CREATING analytics.rfm_segments

CREATE OR REPLACE VIEW analytics.rfm_segments AS

WITH max_date AS (
    -- Compute once (important optimization)
    SELECT MAX(order_purchase_timestamp) AS max_dt
    FROM analytics.customer_orders
),

rfm_base AS (
    SELECT
        co.customer_unique_id,

        -- Recency (days since last purchase)
        DATE_PART('day', md.max_dt - MAX(co.order_purchase_timestamp))::INT AS recency,

        -- Frequency (distinct orders)
        COUNT(DISTINCT co.order_id) AS frequency,

        -- Monetary (total spend)
        SUM(co.order_value) AS monetary

    FROM analytics.customer_orders co
    CROSS JOIN max_date md
    GROUP BY co.customer_unique_id, md.max_dt
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency,
        frequency,
        monetary,

        -- Scoring (correct directions)
        NTILE(5) OVER (ORDER BY recency ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score

    FROM rfm_base
)

SELECT
    customer_unique_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,

    -- Segmentation logic
    CASE
	    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
	    WHEN r_score >= 4 AND f_score >= 4 THEN 'Loyal Customers'
	    WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
	    WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
	    WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
	    ELSE 'Potential'
	END AS segment 

FROM rfm_scores;

SELECT segment, COUNT(*) 
FROM analytics.rfm_segments
GROUP BY segment
ORDER BY COUNT(*) DESC;


-- 6. CREATING analytics.delivery_performance

CREATE OR REPLACE VIEW analytics.delivery_performance AS

SELECT
    o.order_id,

    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Delay in days
    DATE_PART('day',
        o.order_delivered_customer_date - o.order_estimated_delivery_date
    )::INT AS delay_days,

    r.review_score,

    -- Categorization (useful for dashboard)
    CASE
        WHEN o.order_delivered_customer_date < o.order_estimated_delivery_date THEN 'Early'
        WHEN o.order_delivered_customer_date = o.order_estimated_delivery_date THEN 'On Time'
        WHEN o.order_delivered_customer_date - o.order_estimated_delivery_date <= INTERVAL '3 days' THEN 'Slight Delay'
        ELSE 'Heavy Delay'
    END AS delivery_status

FROM raw.orders o
JOIN raw.order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;

SELECT * FROM analytics.delivery_performance;


-- 7. CREATING analytics.customer_cohort_retention


CREATE OR REPLACE VIEW analytics.customer_cohort_retention AS

WITH customer_monthly_activity AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', order_purchase_timestamp) AS activity_month
    FROM analytics.customer_orders
    GROUP BY customer_unique_id, activity_month
),

customer_cohort AS (
    SELECT
        customer_unique_id,
        MIN(activity_month) AS cohort_month
    FROM customer_monthly_activity
    GROUP BY customer_unique_id
),

cohort_data AS (
    SELECT
        cma.customer_unique_id,
        cc.cohort_month,
        cma.activity_month,

        (
            EXTRACT(YEAR FROM age(cma.activity_month, cc.cohort_month)) * 12 +
            EXTRACT(MONTH FROM age(cma.activity_month, cc.cohort_month))
        ) AS cohort_index

    FROM customer_monthly_activity cma
    JOIN customer_cohort cc
        ON cma.customer_unique_id = cc.customer_unique_id
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohort
    GROUP BY cohort_month
),

-- Generate full timeline (0 --> 24 months)
month_series AS (
    SELECT generate_series(0, 24) AS cohort_index
),

cohort_full AS (
    SELECT
        cs.cohort_month,
        ms.cohort_index,
        cs.cohort_size
    FROM cohort_size cs
    CROSS JOIN month_series ms
),

cohort_retention AS (
    SELECT
        cf.cohort_month,
        cf.cohort_index,
        cf.cohort_size,
        COUNT(DISTINCT cd.customer_unique_id) AS active_users
    FROM cohort_full cf
    LEFT JOIN cohort_data cd
        ON cf.cohort_month = cd.cohort_month
        AND cf.cohort_index = cd.cohort_index
    GROUP BY cf.cohort_month, cf.cohort_index, cf.cohort_size
)

SELECT
    cohort_month,
    cohort_index,
    cohort_size,
    active_users,
    ROUND(100.0 * active_users / cohort_size, 2) AS retention_rate

FROM cohort_retention
ORDER BY cohort_month, cohort_index;

SELECT * FROM analytics.customer_cohort_retention;
















