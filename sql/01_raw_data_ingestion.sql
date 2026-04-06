SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('raw', 'analytics');

-- CREATING THE CUSTOMERS TABLE IN RAW SCHEMA

CREATE TABLE raw.customers (
    customer_id              TEXT,
    customer_unique_id       TEXT,
    customer_zip_code_prefix INTEGER,
    customer_city            TEXT,
    customer_state           TEXT
);

SELECT * FROM raw.customers;

-- LOADING THE DATA INTO raw.customers

COPY raw.customers
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_customers_dataset.csv'
DELIMITER ','
CSV HEADER;

-- CREATING raw.orders TABLE

CREATE TABLE raw.orders (
	order_id TEXT,
	customer_id TEXT,
	order_status TEXT,
	order_purchase_timestamp TIMESTAMP,
	order_approved_at TIMESTAMP,
	order_delivered_carrier_date TIMESTAMP,
	order_delivered_customer_date TIMESTAMP,
	order_estimated_delivery_date TIMESTAMP
);

SELECT * FROM raw.orders;

-- LOADING THE DATA INTO raw.orders

COPY raw.orders
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_orders_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.orders
LIMIT 5;


SELECT COUNT(*) FROM raw.orders;


-- CREATING THE TABLE raw.order_items

CREATE TABLE raw.order_items (
	order_id TEXT,
	order_item_id INTEGER,
	product_id TEXT,
	seller_id TEXT,
	shipping_limit_date TIMESTAMP,
	price NUMERIC(10, 2),
	freight_value NUMERIC(10, 2)
);

SELECT * FROM raw.order_items;

-- LOADING THE DATA INTO raw.order_items

COPY raw.order_items
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_order_items_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.order_items;

SELECT COUNT(*) FROM raw.order_items;

-- CREATING THE TABLE raw.sellers

CREATE TABLE raw.sellers (
	seller_id TEXT,
	seller_zip_code_prefix INTEGER,
	seller_city TEXT,
	seller_state TEXT
);

SELECT * FROM raw.sellers;

-- LOADING THE DATA INTO raw.sellers

COPY raw.sellers
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_sellers_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.sellers;

SELECT COUNT(*) FROM raw.sellers;


-- CREATING THE TABLE raw.products

CREATE TABLE raw.products (
	product_id TEXT,
	product_category_name TEXT,
	product_name_lenght INTEGER,
	product_description_lenght INTEGER,
	product_photos_qty INTEGER,
	product_weight_g INTEGER,
	product_length_cm INTEGER,
	product_height_cm INTEGER,
	product_width_cm INTEGER
);

SELECT * FROM raw.products;

SELECT COUNT(*) FROM raw.products;

-- LOADING THE DATA INTO raw.products

COPY raw.products
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_products_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.products
LIMIT 5;

SELECT COUNT(*) FROM raw.products;



-- CREATING THE TABLE raw.order_payments

CREATE TABLE raw.order_payments (
	order_id TEXT,
	payment_sequential INTEGER,
	payment_type TEXT,
	payment_installments INTEGER,
	payment_value NUMERIC(10,2)
);

-- LOADING THE DATA INTO THE TABLE raw.order_payments

COPY raw.order_payments
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_order_payments_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.order_payments
LIMIT 5;

SELECT COUNT(*) FROM raw.order_payments;


-- CREATING THE TABLE raw.order_reviews

CREATE TABLE raw.order_reviews (
    review_id TEXT,
    order_id TEXT,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- LOADING THE DATA INTO raw.order_reviews

COPY raw.order_reviews
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_order_reviews_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.order_reviews
LIMIT 5;

SELECT
    MIN(review_score),
    MAX(review_score)
FROM raw.order_reviews;


-- CREATING THE TABLE raw.geolocation

CREATE TABLE raw.geolocation (
	geolocation_zip_code_prefix INTEGER,
	geolocation_lat NUMERIC(10, 2),
	geolocation_lng NUMERIC(10, 2),
	geolocation_city TEXT,
	geolocation_state TEXT
);

-- LOADING THE DATA INTO raw.geolocation

COPY raw.geolocation
FROM 'C:\Materials\Projects\Olist\olist_dataset\olist_geolocation_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.geolocation
LIMIT 5;

SELECT COUNT(*) FROM raw.geolocation;


-- CREATING THE TABLE raw.product_category_translation

CREATE TABLE raw.product_category_translation (
	product_category_name TEXT,
	product_category_name_english TEXT
);


COPY raw.product_category_translation
FROM 'C:\Materials\Projects\Olist\olist_dataset\product_category_name_translation.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.product_category_translation
LIMIT 5;


--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

-- LOADING THE MARKETING FUNNEL DATA

/* 
	olist_marketing_qualified_leads_dataset.csv # 1ST TABLE

	This represents top-of-funnel seller leads.

	Each row = a potential seller identified by marketing.

	Key concepts:

	Lead exists

	Has attributes (origin, landing page, etc.)

	Has NOT necessarily become a seller

*/

-- CREATING raw.marketing_leads TABLE

CREATE TABLE raw.marketing_leads (
	mql_id TEXT,
	first_contact_date DATE,
	landing_page_id TEXT,
	origin TEXT
);

SELECT * FROM raw.marketing_leads;

-- LOADING THE DATA INTO raw.marketing_leads

COPY raw.marketing_leads 
FROM 'C:\Materials\Projects\Olist\mkt_funnel\olist_marketing_qualified_leads_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.marketing_leads
LIMIT 5;

SELECT COUNT(*) FROM raw.marketing_leads;

SELECT DISTINCT date_part('year', first_contact_date) AS year
FROM raw.marketing_leads;

/* 
	olist_closed_deals_dataset.csv # 2ND TABLE
	
	This represents successful seller acquisitions.
	
	Each row = a seller who signed a deal with Olist.
	
	Critical point:
	
	This table is the bridge between marketing and sellers
	
	It contains seller_id → which connects to your existing seller tables
*/

-- CREATING raw.closed_deals TABLE

CREATE TABLE raw.closed_deals (
	mql_id TEXT,
	seller_id TEXT,
	sdr_id TEXT,
	sr_id TEXT,
	won_date DATE,
	business_segment TEXT,
	lead_type TEXT,
	lead_behaviour_profile TEXT,
	has_company BOOLEAN,
	has_gtin BOOLEAN,
	average_stock TEXT,
	business_type TEXT,
	declared_product_catalog_size NUMERIC(10,2),
	declared_monthly_revenue NUMERIC(10,2)
);

SELECT * FROM raw.closed_deals;

-- LOADING THE DATA INTO raw.closed_deals

COPY raw.closed_deals
FROM 'C:\Materials\Projects\Olist\mkt_funnel\olist_closed_deals_dataset.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM raw.closed_deals
LIMIT 5;


