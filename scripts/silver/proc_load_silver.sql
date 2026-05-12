/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @count_total_rows INT, @start_time DATETIME, @end_time DATETIME, @start_batch_time DATETIME, @end_batch_time DATETIME
    BEGIN TRY
        SET @start_batch_time = GETDATE();
        PRINT '==================================================';
        PRINT 'Loading Silver Layer';
        PRINT '==================================================';

        PRINT '--------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '--------------------------------------------------';


        ----New Table
        SET @start_time = GETDATE()
        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        INSERT INTO silver.crm_cust_info(
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date)
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
            FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL
        )t WHERE flag_last = 1

        PRINT '>> Inserting Data into: silver.crm_cust_info';
        SELECT @count_total_rows = COUNT(*) FROM bronze.crm_cust_info;
        PRINT '>> Insering Data Into: silver.crm_cust_info - ' + CAST(@count_total_rows AS VARCHAR) + ' Rows';
        SET @end_time = GETDATE()
        PRINT '>> Load Duration for silver.crm_cust_info: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '';


        ----New Table
        SET @start_time = GETDATE()
        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prt_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_start_dt
        FROM bronze.crm_prd_info

        PRINT '>> Inserting Data into: silver.crm_prd_info';
        SELECT @count_total_rows = COUNT(*) FROM silver.crm_prd_info;
        PRINT '>> Insering Data Into: silver.crm_prd_info - ' + CAST(@count_total_rows AS VARCHAR) + ' Rows';
        SET @end_time = GETDATE()
        PRINT '>> Load Duration for silver.crm_prd_info: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '';


        ----New Table
        SET @start_time = GETDATE()
        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        INSERT INTO silver.crm_sales_details(
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE WHEN LEN(sls_order_dt) != 8 OR sls_order_dt = 0 THEN NULL
                 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            CASE WHEN LEN(sls_ship_dt) != 8 OR sls_ship_dt = 0 THEN NULL
                 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            CASE WHEN LEN(sls_due_dt) != 8 OR sls_due_dt = 0 THEN NULL
                 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
                    THEN sls_quantity * ABS(sls_price)
                 ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            CASE WHEN sls_price <= 0 OR sls_price IS NULL THEN sls_sales / NULLIF(sls_quantity, 0)
                 ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details

        PRINT '>> Inserting Data into: silver.crm_sales_details';
        SELECT @count_total_rows = COUNT(*) FROM silver.crm_sales_details;
        PRINT '>> Insering Data Into: silver.crm_sales_details - ' + CAST(@count_total_rows AS VARCHAR) + ' Rows';
        SET @end_time = GETDATE()
        PRINT '>> Load Duration for silver.crm_sales_details: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '';


        ----Print
        PRINT '--------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '--------------------------------------------------';


        ----New Table
        SET @start_time = GETDATE()
        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        INSERT INTO silver.erp_cust_az12(
            cid,
            bdate,
            gen)
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4 , LEN(cid))
                ELSE cid
            END AS cid,
            CASE WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,
            CASE WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('F', 'FEMALE') THEN 'Female'
                 WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('M', 'MALE') THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12

        PRINT '>> Inserting Data into: silver.erp_cust_az12';
        SELECT @count_total_rows = COUNT(*) FROM silver.erp_cust_az12;
        PRINT '>> Insering Data Into: silver.erp_cust_az12 - ' + CAST(@count_total_rows AS VARCHAR) + ' Rows';
        SET @end_time = GETDATE()
        PRINT '>> Load Duration for silver.erp_cust_az12: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '';


        ----New Table
        SET @start_time = GETDATE()
        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        INSERT INTO silver.erp_loc_a101(
            cid,
            cntry)
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) = 'DE' THEN 'Germany'
                 WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) IN ('US', 'USA') THEN 'United States'
                 WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) = '' OR cntry IS NULL THEN 'n/a'
                 ELSE TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''))
            END AS cntry
        FROM bronze.erp_loc_a101

        PRINT '>> Inserting Data into: silver.erp_loc_a101';
        SELECT @count_total_rows = COUNT(*) FROM silver.erp_loc_a101;
        PRINT '>> Insering Data Into: silver.erp_loc_a101 - ' + CAST(@count_total_rows AS VARCHAR) + ' Rows';
        SET @end_time = GETDATE()
        PRINT '>> Load Duration for silver.erp_loc_a101: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '';


        ----New Table
        SET @start_time = GETDATE()
        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        INSERT INTO silver.erp_px_cat_g1v2(
            id,
            cat,
            subcat,
            maintenance)
        SELECT
            id,
            cat,
            subcat,
            TRIM(REPLACE(REPLACE(maintenance, CHAR(13), ''), CHAR(10), '')) AS maintenance
        FROM bronze.erp_px_cat_g1v2

        PRINT '>> Inserting Data into: silver.erp_px_cat_g1v2';
        SELECT @count_total_rows = COUNT(*) FROM silver.erp_px_cat_g1v2;
        PRINT '>> Insering Data Into: silver.erp_px_cat_g1v2 - ' + CAST(@count_total_rows AS VARCHAR) + ' Rows';
        SET @end_time = GETDATE()
        PRINT '>> Load Duration for silver.erp_px_cat_g1v2: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '';


    ----Print Batch Load Time
        SET @end_batch_time = GETDATE()
        PRINT '==================================================';
        PRINT 'Loading Silver Later is Completed:';
        PRINT 'Total Load Duration: ' + CAST(DATEDIFF(SECOND, @start_batch_time, @end_batch_time) AS NVARCHAR) + ' seconds';
        PRINT '==================================================';
    END TRY

    ----Print Error
    BEGIN CATCH
        PRINT '==================================================';
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
        PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
        PRINT 'ERROR MESSAGE' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'ERROR MESSAGE' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==================================================';
    END CATCH
END
GO
