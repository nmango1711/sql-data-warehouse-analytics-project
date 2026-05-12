/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency, 
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

/***************************
-Checking Data Quality of Silver layer & Validations of Gold Layer-
*/

-- ====================================================================
-- gold.dim_customers
-- ====================================================================
-- Search for duplicates after the JOIN
SELECT
    cst_id, COUNT(*) as duplicate_count
FROM
(SELECT
    ci.cst_id,
    ci.cst_key,
    ci.cst_firstname,
    ci.cst_lastname,
    ci.cst_marital_status,
    ci.cst_gndr,
    ci.cst_create_date,
    ca.bdate,
    ca.gen,
    la.cntry
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca ON ca.cid = ci.cst_key
LEFT JOIN silver.erp_loc_a101 AS la ON la.cid = ci.cst_key)t
GROUP BY cst_id HAVING COUNT(*) > 1;

-->>> Checking gold.dim_customers
SELECT * FROM gold.dim_customers;
SELECT DISTINCT gender FROM gold.dim_customers;

SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- gold.dim_products
-- ====================================================================
-- Check for duplicates after the JOIN
SELECT prd_id, COUNT(*)
FROM
(SELECT
    pi.prd_id,
    pi.cat_id,
    pi.prd_key,
    pi.prd_nm,
    pi.prd_cost,
    pi.prd_line,
    pi.prd_start_dt,
    pcg.cat,
    pcg.subcat,
    pcg.maintenance
FROM silver.crm_prd_info AS pi
LEFT JOIN silver.erp_px_cat_g1v2 AS pcg ON pcg.id = pi.cat_id
WHERE pi.prt_end_dt IS NULL)t GROUP BY prd_id HAVING COUNT(*) > 1

-->>> Checking gold.dim_products
SELECT * FROM gold.dim_products;

SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- gold.fact_sales
-- ====================================================================
-->>> Checking gold.fact_sales
SELECT * FROM gold.fact_sales;
SELECT * FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL;
