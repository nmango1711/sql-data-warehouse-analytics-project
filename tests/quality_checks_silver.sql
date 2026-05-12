/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- bronze.crm_cust_info
-- ====================================================================
SELECT * FROM bronze.crm_cust_info;
SELECT cst_id, COUNT(*) FROM bronze.crm_cust_info GROUP BY cst_id HAVING COUNT(*) > 1 OR cst_id IS NULL;
SELECT * FROM bronze.crm_cust_info WHERE cst_id = 29466;

SELECT cst_firstname FROM bronze.crm_cust_info WHERE cst_firstname != TRIM(cst_firstname);
SELECT cst_lastname FROM bronze.crm_cust_info WHERE cst_lastname != TRIM(cst_lastname);
SELECT cst_gndr FROM bronze.crm_cust_info WHERE cst_gndr != TRIM(cst_gndr);
SELECT cst_marital_status FROM bronze.crm_cust_info WHERE cst_marital_status != TRIM(cst_marital_status);

SELECT DISTINCT cst_gndr FROM bronze.crm_cust_info;
SELECT DISTINCT cst_marital_status FROM bronze.crm_cust_info;

-->>> Checking silver.crm_cust_info
SELECT cst_id, COUNT(*) FROM SILVER.crm_cust_info GROUP BY cst_id HAVING COUNT(*) > 1 OR cst_id IS NULL;

SELECT cst_firstname FROM silver.crm_cust_info WHERE cst_firstname != TRIM(cst_firstname);
SELECT cst_lastname FROM silver.crm_cust_info WHERE cst_lastname != TRIM(cst_lastname);
SELECT cst_gndr FROM silver.crm_cust_info WHERE cst_gndr != TRIM(cst_gndr);
SELECT cst_marital_status FROM silver.crm_cust_info WHERE cst_marital_status != TRIM(cst_marital_status);

SELECT DISTINCT cst_gndr FROM silver.crm_cust_info;
SELECT DISTINCT cst_marital_status FROM silver.crm_cust_info;

SELECT * FROM silver.crm_cust_info;

-- ====================================================================
-- bronze.crm_prd_info
-- ====================================================================
SELECT * FROM bronze.crm_prd_info;
SELECT prd_id, COUNT(*) FROM bronze.crm_prd_info GROUP BY prd_id HAVING COUNT(*) > 1 OR prd_id IS NULL;

SELECT
    prd_key,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id
FROM bronze.crm_prd_info
WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') NOT IN
(SELECT DISTINCT id FROM bronze.erp_px_cat_g1v2) -- Check which category is not in other table and determine what to do with that info

SELECT DISTINCT id FROM bronze.erp_px_cat_g1v2; -- (Change cat_id from CO-RF to CO_RF to match table id from bronze.erp_px_cat_g1v2)

SELECT prd_nm FROM bronze.crm_prd_info WHERE prd_nm != TRIM(prd_nm);
SELECT prd_cost FROM bronze.crm_prd_info WHERE prd_cost < 0 OR prd_cost IS NULL;
SELECT DISTINCT prd_line FROM bronze.crm_prd_info;

SELECT * FROM bronze.crm_prd_info WHERE prt_end_dt < prd_start_dt;
SELECT * FROM bronze.crm_prd_info WHERE prd_key = 'AC-HE-HL-U509';

SELECT
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    prt_end_dt,
    LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS LEAD2,
    RANK() over (PARTITION BY prd_key ORDER BY prd_start_dt) AS RANK
FROM bronze.crm_prd_info;

-->>> Checking silver.crm_prd_info
SELECT prd_id, COUNT(*) FROM silver.crm_prd_info GROUP BY prd_id HAVING COUNT(*) > 1 OR prd_id IS NULL;
SELECT prd_nm FROM silver.crm_prd_info WHERE prd_nm != TRIM(prd_nm);
SELECT prd_cost FROM silver.crm_prd_info WHERE prd_cost < 0 OR prd_cost IS NULL;
SELECT DISTINCT prd_line FROM silver.crm_prd_info;
SELECT * FROM silver.crm_prd_info WHERE prt_end_dt < prd_start_dt;

-- ====================================================================
-- bronze.crm_sales_details
-- ====================================================================
SELECT * FROM bronze.crm_sales_details;
SELECT * FROM bronze.crm_sales_details WHERE sls_ord_num != TRIM(sls_ord_num);
SELECT * FROM bronze.crm_sales_details WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);
SELECT * FROM bronze.crm_sales_details WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);
SELECT
    NULLIF(sls_order_dt, 0) AS sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
OR LEN(sls_order_dt) != 8
OR sls_order_dt > 20500101 OR sls_order_dt < 19000101;

SELECT * FROM bronze.crm_sales_details WHERE sls_order_dt > sls_due_dt OR sls_order_dt > sls_ship_dt;

SELECT DISTINCT sls_sales, sls_quantity, sls_price FROM bronze.crm_sales_details WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

--Raw Format of Sales, Quantity, Price
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

SELECT DISTINCT
    sls_sales AS old_sls_sales,
    sls_quantity,
    sls_price AS old_sls_price,
    CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
         ELSE sls_sales
    END AS sls_sales,
    CASE WHEN sls_price <= 0 OR sls_price IS NULL THEN sls_sales / NULLIF(sls_quantity, 0)
         ELSE sls_price
    END AS sls_price
FROM bronze.crm_sales_details WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-->>> Checking silver.crm_sales_details
SELECT * FROM silver.crm_sales_details;
SELECT * FROM silver.crm_sales_details WHERE sls_ord_num != TRIM(sls_ord_num);
SELECT * FROM silver.crm_sales_details WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);
SELECT * FROM silver.crm_sales_details WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);
SELECT * FROM silver.crm_sales_details WHERE sls_order_dt > sls_due_dt OR sls_order_dt > sls_ship_dt;

SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- ====================================================================
--  bronze.erp_cust_az12
-- ====================================================================
SELECT * FROM bronze.erp_cust_az12;
SELECT
    cid AS old_cid,
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4 , LEN(cid))
            ELSE cid
    END AS cid,
    bdate,
    gen
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4 , LEN(cid))
    ELSE cid
END NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info); -- Checking matching with PK from other Table

SELECT DISTINCT bdate FROM bronze.erp_cust_az12 WHERE BDATE < '1924-01-01' OR bdate > GETDATE();

SELECT DISTINCT gen, LEN(gen) FROM bronze.erp_cust_az12;
SELECT DISTINCT
    gen,
    CASE WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('F', 'FEMALE') THEN 'Female'
         WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('M', 'MALE') THEN 'Male'
         ELSE 'n/a'
    END AS cleaned_gen
FROM bronze.erp_cust_az12;

-->>> Checking silver.erp_cust_az12
SELECT DISTINCT bdate FROM silver.erp_cust_az12 WHERE BDATE < '1924-01-01' OR bdate > GETDATE() ORDER BY bdate DESC;
SELECT DISTINCT gen, LEN(gen) FROM silver.erp_cust_az12;

-- ====================================================================
-- bronze.erp_cust_az12
-- ====================================================================
SELECT * FROM BRONZE.erp_loc_a101
SELECT cid FROM bronze.erp_loc_a101;
SELECT cst_key FROM silver.crm_cust_info; -- Another table for JOIN

SELECT DISTINCT cntry FROM bronze.erp_loc_a101;

SELECT DISTINCT
    cntry AS old_country,
    CASE WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) = 'DE' THEN 'Germany'
         WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) IN ('US', 'USA') THEN 'United States'
         WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) = '' OR cntry IS NULL THEN 'n/a'
         ELSE TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''))
    END AS cntry
FROM bronze.erp_loc_a101;

-->>> Checking silver.erp_cust_az12
SELECT DISTINCT cntry FROM silver.erp_loc_a101;

-- ====================================================================
-- bronze.erp_px_cat_g1v2
-- ====================================================================
SELECT * FROM bronze.erp_px_cat_g1v2;
SELECT * FROM bronze.erp_px_cat_g1v2 WHERE cat != TRIM(cat);
SELECT * FROM bronze.erp_px_cat_g1v2 WHERE subcat != TRIM(subcat);
SELECT * FROM bronze.erp_px_cat_g1v2 WHERE maintenance != TRIM(maintenance);

SELECT DISTINCT cat FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT subcat FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT maintenance, LEN(maintenance) FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT TRIM(REPLACE(REPLACE(maintenance, CHAR(13), ''), CHAR(10), '')) AS cleaned_value FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT
    '[' + maintenance + ']' AS visible_value,
    LEN(maintenance) AS len_value,
    DATALENGTH(maintenance) AS data_length,
    ASCII(RIGHT(maintenance, 1)) AS last_char
FROM bronze.erp_px_cat_g1v2;

-->>> Checking silver.erp_px_cat_g1v2
SELECT DISTINCT cat FROM silver.erp_px_cat_g1v2;
SELECT DISTINCT subcat FROM silver.erp_px_cat_g1v2;
SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2;
