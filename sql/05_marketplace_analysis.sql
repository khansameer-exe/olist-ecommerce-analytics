-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- MARKETPLACE ANALYSIS
-- ----------------------------------------------------------------------------------------------------------------------------------------------

-- WE MUST UNDERSTAND HOW THE MARKETPLACE BEHAVES OVER TIME

-- QUESTIONS TO BE ANSWERED:
-- IS THE BUSINESS GROWING?
-- IS THE REVENUE STABLE?

-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- ORDERS AND GMV (GROSS MERCHANDISE VALUE) TREND (MONTHLY) & MONTHLY AVERAGE ORDER VALUE (AOV)
-- ----------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    TO_CHAR(DATE_TRUNC('month', order_month), 'Mon YYYY') AS month,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(order_value), 2) AS total_gmv,
	ROUND(SUM(order_value) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM analytics.customer_orders
GROUP BY DATE_TRUNC('month', order_month)
ORDER BY DATE_TRUNC('month', order_month);


/*
	The marketplace shows steady growth with GMV closely tracking order volume, 
	indicating that revenue expansion is primarily driven by increased demand rather than changes in order value.
*/


-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- REPEAT PURCHASE RATE
-- ----------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    COUNT(*) FILTER (WHERE order_count > 1) * 100.0 / COUNT(*) AS repeat_purchase_rate
FROM (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM analytics.customer_orders
    GROUP BY customer_unique_id
) t;

-- REPEAT PURCHASE RATE IS CLOSE TO 3.1%
-- THIS MEANS: CLOSE TO 96.9% CUSTOMERS BOUGHT ONLY ONCE AND 3.1% CAME BACK AND PURCHASED AGAIN.

-- KEY INSIGHT
-- THE PLATFORM IS GOOD AT ACQUIRING CUSTOMERS, BUT WEAK AT RETAINING THEM.

/* 
	BUSINESS PICTURE

	Strong acquisition (orders growing)
			+
	Stable order value
			+
	Weak repeat behavior
			=
	Growth depends heavily on new customers
*/


-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- RFM SEGMENTATION
-- ----------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    customer_unique_id,
    
    MAX(order_purchase_timestamp) AS last_purchase_date,
    
    COUNT(DISTINCT order_id) AS frequency,
    
    SUM(order_value) AS monetary
    
FROM analytics.customer_orders
GROUP BY customer_unique_id;

-- MAJORITY OF THE CUSTOMERS HAVE FREQUENCY = 1, THIS MEANS THAT MOST OF THEM ARE ONE-TIME BUYERS.

-- FINDING THE LATEST DATE AS THE REFERENCE DATE

SELECT MAX(order_purchase_timestamp)
FROM analytics.customer_orders;


-- RFM TABLE

WITH rfm_base AS (
    SELECT
        customer_unique_id,
        
        DATE_PART('day', 
            (SELECT MAX(order_purchase_timestamp) FROM analytics.customer_orders)
            - MAX(order_purchase_timestamp)
        ) AS recency,
        
        COUNT(DISTINCT order_id) AS frequency,
        
        SUM(order_value) AS monetary

    FROM analytics.customer_orders
    GROUP BY customer_unique_id
),

rfm_scores AS (
    SELECT
        *,
        
        NTILE(5) OVER (ORDER BY recency ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score

    FROM rfm_base
)

SELECT *
FROM rfm_scores;

/*

EACH ROW = ONE CUSTOMER WITH:
	- recency → days since last purchase
	- frequency → number of orders
	- monetary → total spend
	- r_score, f_score, m_score → relative ranking (1–5)

 | Metric    | Good Behavior | Score      |
 | --------- | ------------- | ---------- |
 | Recency   | LOW (recent)  | HIGH score |
 | Frequency | HIGH          | HIGH score |
 | Monetary  | HIGH          | HIGH score |

*/


WITH rfm_base AS (
    SELECT
        customer_unique_id,
        
        DATE_PART('day', 
            (SELECT MAX(order_purchase_timestamp) FROM analytics.customer_orders)
            - MAX(order_purchase_timestamp)
        ) AS recency,
        
        COUNT(DISTINCT order_id) AS frequency,
        
        SUM(order_value) AS monetary

    FROM analytics.customer_orders
    GROUP BY customer_unique_id
),

rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
)

SELECT
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        ELSE 'Lost'
    END AS segment,
    COUNT(*) AS customers
FROM rfm_scores
GROUP BY segment
ORDER BY customers DESC;

-- another query

WITH rfm_base AS (
    SELECT
        customer_unique_id,

        -- Recency: days since last purchase
        DATE_PART('day',
            (SELECT MAX(order_purchase_timestamp) FROM analytics.customer_orders)
            - MAX(order_purchase_timestamp)
        ) AS recency,

        -- Frequency: number of orders
        COUNT(DISTINCT order_id) AS frequency,

        -- Monetary: total spend
        SUM(order_value) AS monetary

    FROM analytics.customer_orders
    GROUP BY customer_unique_id
),

rfm_scores AS (
    SELECT
        *,

        -- Recency: lower is better
        NTILE(5) OVER (ORDER BY recency ASC) AS r_score,

        -- Frequency: higher is better
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,

        -- Monetary: higher is better
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

    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        ELSE 'Lost'
    END AS segment

FROM rfm_scores;

-- A large portion of customers are either already churned or at risk, 
-- while a smaller but significant segment represents high-value, engaged users.

/*

	FINAL CUSTOMER BEHAVIOUR MODEL
	
		Marketplace Funnel:
	
	Large inflow of customers
		        ↓
	Most make 1 purchase
	    	    ↓
	Many become "Lost" or "At Risk"
	        	↓
	Small subset becomes Loyal / Champions

*/


/* 
	RFM analysis reveals a highly skewed customer base, 
	with a large proportion of users classified as “Lost” or “At Risk”, 
	while a smaller segment of “Champions” and “Loyal Customers” drives sustained engagement. 
	This indicates that the marketplace relies heavily on continuous acquisition, 
	with significant opportunity to improve retention through targeted lifecycle strategies.
*/


-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- CUSTOMER LIFECYCLE VALUE (CLV)
-- TOTAL REVENUE GENERATED BY A CUSTOMER OVER THEIR LIFETIME.
-- ----------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    customer_unique_id,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_value) AS total_revenue,
    ROUND(AVG(order_value),2) AS avg_order_value
FROM analytics.customer_orders
GROUP BY customer_unique_id;

-- total_orders --> FREQUENCY
-- total_revenue --> CLV
-- avg_order_value --> SPENDING BEHAVIOUR


-- CLV METRICS

SELECT
    ROUND(AVG(total_revenue), 2) AS avg_clv,
    ROUND(MAX(total_revenue), 2) AS max_clv,
    ROUND(MIN(total_revenue), 2) AS min_clv
FROM (
    SELECT
        customer_unique_id,
        SUM(order_value) AS total_revenue
    FROM analytics.customer_orders
    GROUP BY customer_unique_id
) t;

-- avg_clv --> AVERAGE CUSTOMER VALUE
-- max_clv --> HIGHEST SPENDING CUSTOMER VALUE
-- min_clv --> MINIMUM A CUSTOMER HAS SPENT


SELECT *
FROM analytics.customer_orders
WHERE order_value = 0
LIMIT 20;

-- THERE ARE 3 CUSTOMERS WHOSE order_value IS ZERO.

SELECT
    ROUND(AVG(total_revenue), 2) AS avg_clv,
    ROUND(MAX(total_revenue), 2) AS max_clv,
    ROUND(MIN(total_revenue), 2) AS min_clv
FROM (
    SELECT
        customer_unique_id,
        SUM(order_value) AS total_revenue
    FROM analytics.customer_orders
	WHERE order_value > 0
    GROUP BY customer_unique_id
) t;


-- CLV BY RFM SEGMENT

WITH rfm_base AS (
    SELECT
        customer_unique_id,
        DATE_PART('day', 
            (SELECT MAX(order_purchase_timestamp) FROM analytics.customer_orders)
            - MAX(order_purchase_timestamp)
        ) AS recency,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(order_value) AS monetary
    FROM analytics.customer_orders
    GROUP BY customer_unique_id
),

rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
    FROM rfm_base
),

rfm_segments AS (
    SELECT
        customer_unique_id,
        monetary,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            ELSE 'Lost'
        END AS segment
    FROM rfm_scores
)

SELECT
    segment,
    COUNT(*) AS customers,
    ROUND(AVG(monetary), 2) AS avg_clv,
    ROUND(SUM(monetary), 2) AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;


/*
	Customer lifetime value analysis reveals that “At Risk” customers contribute the highest total revenue, 
	indicating a critical dependency on users who are likely to churn. 
	While “Champions” represent the highest-value customers on an individual level, 
	retention strategies should prioritize re-engaging “At Risk” users to prevent significant revenue loss.
*/


-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- DELIVERY DELAY ANALYSIS
-- DOES DELIVERY IMPACT CUSTOMER SATISFACTION
-- ----------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    o.order_id,
    
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    
    DATE_PART('day',
        o.order_delivered_customer_date - o.order_estimated_delivery_date
    ) AS delay_days,

    r.review_score

FROM raw.orders o
JOIN raw.order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;

-- NEGATIVE VALUES = DELIEVERED EARLY
-- 0 = ON TIME
-- POSITIVE VALUES = DELAYED DELIEVERY


SELECT
    CASE
        WHEN delay_days < 0 THEN 'Early'
        WHEN delay_days = 0 THEN 'On Time'
        WHEN delay_days BETWEEN 1 AND 3 THEN 'Slight Delay'
        ELSE 'Heavy Delay'
    END AS delivery_status,

    COUNT(*) AS orders,
    ROUND(AVG(review_score), 2) AS avg_review_score

FROM (
    SELECT
        o.order_id,
        DATE_PART('day',
            o.order_delivered_customer_date - o.order_estimated_delivery_date
        ) AS delay_days,
        r.review_score
    FROM raw.orders o
    JOIN raw.order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
) t

GROUP BY delivery_status
ORDER BY avg_review_score DESC;

-- AS DELIVERY DELAYS INCREASES, CUSTOMER SATISFACTION DECREASES.


SELECT
    CAST(delay_days AS INT) AS delay_bucket,
    COUNT(*) AS orders,
    ROUND(AVG(review_score), 2) AS avg_review
FROM (
    SELECT
        DATE_PART('day',
            o.order_delivered_customer_date - o.order_estimated_delivery_date
        ) AS delay_days,
        r.review_score
    FROM raw.orders o
    JOIN raw.order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
) t
GROUP BY delay_bucket
ORDER BY delay_bucket;


-- ----------------------------------------------------------------------------------------------------------------------------------------------
-- COHORT ANALYSIS
-- ----------------------------------------------------------------------------------------------------------------------------------------------


-- MONTHLY CUSTOMER ACTIVITY

WITH customer_monthly_activity AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', order_purchase_timestamp) AS activity_month
    FROM analytics.customer_orders
    GROUP BY 1,2
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
        
        EXTRACT(YEAR FROM age(cma.activity_month, cc.cohort_month)) * 12 +
        EXTRACT(MONTH FROM age(cma.activity_month, cc.cohort_month)) AS cohort_index
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

cohort_retention AS (
    SELECT
        cd.cohort_month,
        cd.cohort_index,
        COUNT(DISTINCT cd.customer_unique_id) AS active_users,
        cs.cohort_size
    FROM cohort_data cd
    JOIN cohort_size cs
        ON cd.cohort_month = cs.cohort_month
    GROUP BY cd.cohort_month, cd.cohort_index, cs.cohort_size
)

SELECT
    cohort_index,
    ROUND(AVG(100.0 * active_users / cohort_size), 2) AS retention_rate
FROM cohort_retention
GROUP BY cohort_index
ORDER BY cohort_index;


/*
	Cohort analysis shows a sharp retention decay, with only ~5% of customers returning in the second month and less than 1% beyond that, 
	indicating that the platform functions primarily as a one-time transaction marketplace rather than a habit-forming ecosystem.
*/






