/***************************************************************************************************
Procedure:          dbo.usp_ibmi_customer_master
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of Customer Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_customer_master
Affected table(s):  silver.ibmi_customer_master
Usage:              EXEC dbo.usp_ibmi_customer_master

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_customer_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_customer

INSERT INTO silver.ibmi_customer
SELECT
	   TRIM(a.CUCODE)											AS customer_code
      ,CASE WHEN TRIM(a.CUDLT) = 'D' THEN
		 'TRUE' ELSE 'FALSE' END								AS is_deleted
      ,TRIM(a.CUNAME)											AS cust_name
      ,TRIM(a.CUBAD1)											AS cust_address_line_1
      ,CASE WHEN LEN(TRIM(a.CUBAD2)) = 0 THEN NULL
		ELSE a.CUBAD2 END										AS cust_address_line_2
      ,TRIM(a.CUBCTY)											AS cust_address_city
      ,TRIM(a.CUBST)											AS cust_address_state
      ,TRIM(a.CUBZIP)											AS cust_address_zip
      ,CASE WHEN LEN(TRIM(a.CUBZP2)) = 0 THEN NULL
		ELSE a.CUBZP2 END										AS cust_address_zip_extn
      ,TRIM(a.CUBCTC)											AS cust_city_code
      ,CASE WHEN LEN(TRIM(a.CUBLCD)) = 0 THEN NULL
		ELSE a.CUBLCD END										AS bill_to_code
      ,CASE WHEN LEN(TRIM(a.CUTERR)) = 0 THEN NULL
		ELSE a.CUTERR END										AS cust_territory
      ,TRIM(a.CUSLMN)											AS cust_salesperson
      ,TRIM(a.CUSHPC)											AS cust_shipper_code
      ,lact.date_key_pk											AS last_activity_date
      ,CASE WHEN TRIM(a.CUTRIP) = 'Y' THEN 'TRUE'
		ELSE 'FALSE' END										AS is_trip_lease 
      ,CONVERT(NVARCHAR, a.CUSAC)								AS cust_shipper_area_code
      ,CONVERT(NVARCHAR, a.CUSPHN)								AS cust_shipper_phone
      ,TRIM(a.CUSNMX)											AS cust_shipper_name
      ,CASE WHEN CONVERT(NVARCHAR, a.CUFAC) = '0' THEN NULL
		ELSE CONVERT(NVARCHAR, a.CUFAC)	END						AS cust_fax_area_code	
      ,CASE WHEN CONVERT(NVARCHAR, a.CUFPHN) = '0' THEN NULL
		ELSE CONVERT(NVARCHAR, a.CUFPHN) END					AS cust_fax_number
      ,TRIM(a.CUCRCD)											AS cust_credit_code
      ,TRIM(a.CUCNTY)											AS cust_country
	  ,CASE a.CUSTMF
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_print_statement
	  ,CASE a.CUINVF
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_print_invoice
      --,a.CUCUR   Fund Code   (no values)
      ,CASE WHEN TRIM(a.CURANK) = '' THEN 'unknown'
		ELSE TRIM(a.CURANK) END									AS customer_rank
      ,CASE WHEN TRIM(a.CUINTR) = '' THEN 'unknown'
		ELSE TRIM(a.CUINTR) END									AS cust_interest
      ,crdt.date_key_pk											AS cust_create_date
      ,CONCAT(LEFT(a.CUCRET,2),':',RIGHT(a.CUCRET,2))			AS cust_create_time
      ,TRIM(a.CUCREI)											AS cust_create_initial
      ,cudt.date_key_pk											AS cust_update_date
      ,CONCAT(LEFT(a.CUUPDT,2),':',RIGHT(a.CUUPDT,2))			AS cust_update_time
      ,TRIM(a.CUUPDI)											AS cust_update_initial
      ,TRIM(a.CUCTLS)											AS controlling_shipper
	  ,CASE a.CUCODS
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_allow_as_shipper
	  ,CASE a.CUCODB
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_allow_as_bill_to
	  ,CASE a.CUCODL
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_allow_as_load_at
	  ,CASE a.CUCODC
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_allow_as_consignee
      ,TRIM(a.CUEDI)											AS edi_profile_code
      ,TRIM(a.CUCOMC)											AS commodity_code
      ,TRIM(a.CUAREA)											AS pu_area_code
      ,TRIM(a.CUSHNM)											AS cust_short_name
      --,a.CUSERB   Service Time Before
      --,a.CUSERA	  Service Time After
	  ,CASE a.CUTARE
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_tare_weight_req
      --,a.CUPAYF   Settle Pay Fund Code 
      --,a.CUCOSC   Cost Center
      ,TRIM(a.CUSVRP)											AS cust_service_rep
      ,TRIM(a.CUCO)												AS company_code
      ,TRIM(a.CUDV)												AS division_code
      --,a.CUTM     Terminal Number  
      ,CASE TRIM(a.CUBLTP)
		 WHEN '1' THEN 'Pre-bill'
		 WHEN '2' THEN 'Post-bill'
		 ELSE 'Other' END										AS cust_billing_type
      --,a.CUEDI2   EDI Code 2 
      --,a.CUEDI3   EDI Code 3 
      --,a.CUEDMB   EDI Message Billing
      --,a.CUBBOC   Bill Before Complete
	  ,CASE a.CUJIT
		   WHEN 'Y' THEN 'True'
		   WHEN 'N' THEN 'False'
		   ELSE 'unknown' END									AS is_cust_jit
      ,a.CUTEST													AS cust_total_est_amt
      --,a.CUGSTC   GST Code
      --,a.CUPBIL   Pre-billing flag
      ,a.CUCCBT													AS ck_cl_begin
      ,a.CUCCET													AS ck_cl_end
      --,a.CUJCHR    JIT CALL HOUR
      --,a.CUCHR     NON JIT CALL HOUR
      ,TRIM(a.CUPLN)											AS cust_planner_initial
      --,a.CUCYL     CITY YARD LOCATION
      --,a.CUCDF     CITY OPERATION DELAY HOUSR
      --,a.CUEFM     EXCLUDE FROM MODEL FLAG
      --,a.CUCARF    CARRY OVER FLAG
      --,a.CUHAZC    HAZARDOUS MATERIAL FLAG
      --,a.CUSF30    SERVICE FAILURE-30 DAYS
      --,a.CUFIL     FILLER
      --,a.CULMRK    LOGISTIC MGMT RANK
      --,a.CULMPO    L.M. ALLOW PARITAL ORDER
  FROM data_central_lh.dbo.ibmi_customer_bronze a
  LEFT JOIN gold.dim_date lact on a.CULACT = lact.date_ordinal
  LEFT JOIN gold.dim_date crdt on a.CUNCUS = crdt.date_db2_julian
  LEFT JOIN gold.dim_date cudt on a.CUUPDD = cudt.date_db2_julian