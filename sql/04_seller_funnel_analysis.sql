-- UNDERSTANDING FUNNEL DISTRIBUTION

/*
	 Lead
       ↓
    Qualified Lead (lead_type NOT NULL)
       ↓
    Closed Deal
       ↓
    Activated
       ↓
    Retained / Churned

*/

# 1. FUNNEL BREAKDOWN

SELECT 
	COUNT(*) AS total_leads,
	SUM(is_closed_deal) AS closed_deals,
	SUM(is_activated) AS activated_sellers,
	COUNT(*) FILTER(WHERE churn_status = 'churned') AS churned_sellers
FROM analytics.seller_funnel;

/*
	The total_leads were 8000 and the closed_leads were 842, so 10.52% conversion rate.
	But out of 842 only 380 are active sellers, which is only 45% of the total sellers who actually registered and started selling
	on the platform, 55% sellers never made a single sale in 90 days.
	93 sellers churned.
*/

# 2. ACTIVATION RATE BY ORIGIN

SELECT
    origin,
	lead_type,
    COUNT(*) AS leads,
    SUM(is_activated) AS activated,
    ROUND(100.0 * SUM(is_activated) / COUNT(*), 2) AS activation_rate_pct
FROM analytics.seller_funnel
GROUP BY origin, lead_type
ORDER BY lead_type DESC, activation_rate_pct DESC;

-- THERE ARE MANY ROWS WHERE THE lead_type IS [null], WE NEED TO FIND WHAT THE ACTUAL SOURCE OF THESE [null] VALUES ARE
-- lead_type COMES FROM raw.closed_deals, IF THE LEAD WAS NEVER CLOSED IT BECOMES [null].

SELECT *
FROM raw.marketing_leads ml
LEFT JOIN raw.closed_deals cd
    ON ml.mql_id = cd.mql_id


SELECT
    COUNT(*) AS total_leads,
    COUNT(*) FILTER (WHERE is_closed_deal = 1) AS closed_deals,
    COUNT(*) FILTER (WHERE lead_type IS NULL) AS null_lead_type
FROM analytics.seller_funnel;

-- SO TOTAL null_lead_type is 7164
-- THESE ARE THE LEADS WHICH WERE NEVER CONVERTED/CLOSED

-- TO ACTIVATE ONE MUST: Lead → Closed Deal → Seller → Orders
-- SINCE MOST OF THE LEADS FROM [null] lead_type WERE NEVER CLOSED, THEIR ACTIVATION_RATE IS CLOSE TO ZERO.

SELECT
    CASE
        WHEN is_closed_deal = 0 THEN 'Not Closed'
        ELSE 'Closed'
    END AS deal_status,
    COUNT(*) AS leads
FROM analytics.seller_funnel
GROUP BY 1;

/*
	Stage 1: Lead

    Stage 2: Closed

    Stage 3: Activated
*/


SELECT
    COUNT(*) FILTER (WHERE is_closed_deal = 0) AS not_closed,
    COUNT(*) FILTER (WHERE is_closed_deal = 1) AS closed
FROM analytics.seller_funnel;

-- WHEN origin IS null

SELECT
    COUNT(*) FILTER (WHERE origin IS NULL) AS null_origin,
    COUNT(*) FILTER (WHERE origin IS NOT NULL) AS valid_origin
FROM analytics.seller_funnel;


SELECT
    CASE
        WHEN is_closed_deal = 0 THEN 'Lead Only'
        WHEN is_closed_deal = 1 AND is_activated = 0 THEN 'Closed Not Activated'
        WHEN is_activated = 1 AND churn_status = 'churned' THEN 'Activated & Churned'
        WHEN is_activated = 1 AND churn_status = 'active' THEN 'Active Seller'
    END AS funnel_stage,
    COUNT(*) 
FROM analytics.seller_funnel
GROUP BY 1;

-- BUT, WE STILL HAVE AN origin = 'unknown' WHICH HAS 1099 LEADS. THIS IS A CLASSIFICATION PROBLEM, 
-- BECAUSE THESE ARE VALID LEADS BUT POORLY CLASSIFIED

/* 
	Qualification tier -> Primary performance driver
	Origin -> Secondary driver
	Unknown origin -> Large volume but classification blind spot
*/

-- UNDERSTANDING THE lead_type SEGMENTATION


SELECT
    lead_type,
    COUNT(*) FILTER (WHERE is_activated = 1) AS activated,
    ROUND(AVG(total_revenue), 2) AS avg_revenue,
	ROUND(100.0 * SUM(is_activated) / COUNT(*), 2) AS activation_rate_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE churn_status = 'churned')
        / NULLIF(COUNT(*) FILTER (WHERE is_activated = 1),0),
        2
    ) AS churn_rate_pct
FROM analytics.seller_funnel
WHERE lead_type IS NOT NULL
GROUP BY lead_type
ORDER BY avg_revenue DESC;


SELECT
    lead_type,
	origin,
    COUNT(*) FILTER (WHERE is_activated = 1) AS activated,
    ROUND(AVG(total_revenue), 2) AS avg_revenue,
	ROUND(100.0 * SUM(is_activated) / COUNT(*), 2) AS activation_rate_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE churn_status = 'churned')
        / NULLIF(COUNT(*) FILTER (WHERE is_activated = 1),0),
        2
    ) AS churn_rate_pct
FROM analytics.seller_funnel
WHERE lead_type IS NOT NULL 
GROUP BY lead_type, origin
ORDER BY avg_revenue DESC;

/* 
	FROM THE ABOVE TABLE WE CAN CREATE 3 SEGMENTS ON THE BASIS OF lead_type

		- TIER A (online_big) (PREMIUM SEGMENT)
		
			- High activation (~63%)
			- Highest avg revenue (~4,100+)
			- Lowest churn (~14%)

		
		- TIER B (online_medium) (HIGH - VOLUMNE OPPORTUNITY)

			- Highest activated count (172)
  			- Moderate revenue (~1,400 avg overall)
			- Moderate churn (~26%)


		- TIER C (online_beginner, offline, industry)

			- Lower revenue
			- High churn (beginner ~48%)
			- Activation lower than top tiers

*/

-- Seller digital maturity → lifecycle quality
-- Origin modifies performance, but tier determines baseline success.



-- **************************************************************************

-- SELLER COHORT RETENTION BY lead_type 


WITH seller_monthly_activity AS (
    SELECT
        oi.seller_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM raw.orders o
    JOIN raw.order_items oi
        ON o.order_id = oi.order_id
    GROUP BY 1,2
),

seller_cohort AS (
    SELECT
        sa.seller_id,
        DATE_TRUNC('month', sa.first_order_date) AS cohort_month,
        sf.lead_type
    FROM analytics.seller_activity sa
    JOIN analytics.seller_funnel sf
        ON sa.seller_id = sf.seller_id
    WHERE sf.lead_type IS NOT NULL
),

cohort_data AS (
    SELECT
        sc.lead_type,
        sc.cohort_month,
        sma.seller_id,
        EXTRACT(YEAR FROM age(sma.activity_month, sc.cohort_month)) * 12 +
        EXTRACT(MONTH FROM age(sma.activity_month, sc.cohort_month)) AS cohort_index
    FROM seller_monthly_activity sma
    JOIN seller_cohort sc
        ON sma.seller_id = sc.seller_id
)

SELECT
    lead_type,
    cohort_index,
    COUNT(DISTINCT seller_id) AS active_sellers
FROM cohort_data
GROUP BY 1,2
ORDER BY lead_type, cohort_index;


-- ---------------------------------------------------------------------------

WITH seller_monthly_activity AS (
    SELECT
        oi.seller_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM raw.orders o
    JOIN raw.order_items oi
        ON o.order_id = oi.order_id
    GROUP BY 1,2
),

seller_cohort AS (
    SELECT
        sa.seller_id,
        DATE_TRUNC('month', sa.first_order_date) AS cohort_month,
        sf.lead_type
    FROM analytics.seller_activity sa
    JOIN (
        SELECT seller_id,
               MAX(lead_type) AS lead_type
        FROM analytics.seller_funnel
        WHERE lead_type IS NOT NULL
        GROUP BY seller_id
    ) sf
    ON sa.seller_id = sf.seller_id
),

cohort_data AS (
    SELECT
        sc.lead_type,
        sc.cohort_month,
        sma.seller_id,
        EXTRACT(YEAR FROM age(sma.activity_month, sc.cohort_month)) * 12 +
        EXTRACT(MONTH FROM age(sma.activity_month, sc.cohort_month)) AS cohort_index
    FROM seller_monthly_activity sma
    JOIN seller_cohort sc
        ON sma.seller_id = sc.seller_id
),

cohort_size AS (
    SELECT
        lead_type,
        cohort_month,
        COUNT(DISTINCT seller_id) AS cohort_size
    FROM seller_cohort
    GROUP BY 1,2
),

final_retention AS (
    SELECT
        cd.lead_type,
        cd.cohort_index,
        COUNT(DISTINCT cd.seller_id) AS active_sellers,
        cs.cohort_size
    FROM cohort_data cd
    JOIN cohort_size cs
        ON cd.lead_type = cs.lead_type
        AND cd.cohort_month = cs.cohort_month
    GROUP BY cd.lead_type, cd.cohort_index, cs.cohort_size
)

SELECT
    lead_type,
    cohort_index,
    ROUND(AVG(100.0 * active_sellers / cohort_size), 2) AS retention_rate_pct
FROM final_retention
GROUP BY lead_type, cohort_index
ORDER BY lead_type, cohort_index;


