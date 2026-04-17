/***************************************************************************************************
Procedure:          dbo.usp_update_dim_customer
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Provides an extract from customer silver
					used to update customer gold.
Called by:            Azure Data Factory
					Pipeline: ibmi_customer_master
Affected table(s):  gold.dim_customer
Usage:              EXEC dbo.usp_update_dim_customer

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1             10/1/2024			  Tom Wolfenden	      Changed to insert data directly into gold layer.
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_update_dim_customer]
AS

SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DELETE FROM gold.dim_customer

INSERT INTO gold.dim_customer
SELECT
	  --b.city_id_pk											AS city_id_fk
	--, c.area_id_pk											AS pu_area_id_fk
	--, d.division_id_pk										AS division_id_fk
	  a.customer_code
	, a.cust_city_code
	, a.pu_area_code										AS cust_area_code
	, a.division_code										AS cust_division_code
	, a.is_deleted
	, a.cust_name
	, a.cust_address_line_1
	, a.cust_address_line_2
	, a.cust_address_city
	, a.cust_address_state
	, a.cust_address_zip
	, a.cust_address_zip_extn
	, CASE WHEN LEN(a.bill_to_code) = 0 OR a.bill_to_code IS NULL
		THEN 'unknown'
		ELSE a.bill_to_code	END								AS bill_to_code
	, CASE WHEN LEN(e.cust_name) = 0 OR e.cust_name IS NULL
		THEN 'unknown'
		ELSE e.cust_name	END								AS bill_to_name
	, a.cust_salesperson
	, a.cust_shipper_code
	, a.cust_shipper_area_code
	, a.cust_shipper_phone
	, a.cust_country
	, a.controlling_shipper
	, CASE WHEN LEN(f.cust_name) = 0 OR f.cust_name IS NULL
		THEN 'unknown' 
		ELSE f.cust_name	END								AS controlling_shipper_name
	, a.is_allow_as_shipper
	, a.is_allow_as_bill_to
	, a.is_allow_as_load_at
	, a.is_allow_as_consignee
	, CASE WHEN LEN(a.edi_profile_code) = 0 OR a.edi_profile_code IS NULL
		THEN 'unknown'
		ELSE a.edi_profile_code		END						AS edi_profile_code
	--, a.division_code										AS cust_division_code
	, d.division_name										AS cust_division_name
	, a.commodity_code
	, g.commodity_description
	, a.pu_area_code
	, c.area_name											AS pu_area_name
	, a.last_activity_date			
FROM silver.ibmi_customer a

LEFT JOIN gold.dim_city b ON CONCAT(a.cust_address_state, a.cust_city_code) = b.city_code
LEFT JOIN gold.dim_area c ON a.pu_area_code = c.area_code
LEFT JOIN silver.ibmi_division d ON a.division_code = d.division_code
LEFT JOIN silver.ibmi_customer e ON a.bill_to_code = e.customer_code
LEFT JOIN silver.ibmi_customer f ON a.controlling_shipper = f.customer_code
LEFT JOIN (SELECT DISTINCT 
				commodity_code
			  , commodity_description 
			FROM gold.dim_commodity) g ON a.commodity_code = g.commodity_code
WHERE a.is_deleted = 'FALSE'