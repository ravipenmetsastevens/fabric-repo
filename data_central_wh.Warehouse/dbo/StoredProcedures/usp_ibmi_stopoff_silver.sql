/***************************************************************************************************
Procedure:          dbo.usp_ibmi_stopoff_silver
Create Date:        2025-08-22
Author:             Jeremy Shahan
Description:        Truncate and load of Stopoff to Silver
Called by:          Fabric
					Pipeline: ibmi_stopoff
Affected table(s):  silver.ibmi_stopoff
Usage:              EXEC dbo.usp_ibmi_stopoff_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_stopoff_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_stopoff

INSERT INTO silver.ibmi_stopoff
SELECT 
	    TRIM(a.SOORD)																	AS stopoff_load_number
      , a.SOSTP																			AS stopoff_stop_number
      , CASE a.SOTYPE
			WHEN 'D' THEN 'DELIVERY'
			WHEN 'P' THEN 'PICKUP'
			ELSE 'unknown'	END															AS stopoff_stop_type
      , TRIM(a.SOREC)																	AS stopoff_stop_code
      , TRIM(a.SOCUST)																	AS stopoff_customer_code
      , TRIM(a.SOCTYC)																	AS stopoff_city_code
      , TRIM(a.SOST)																	AS stopoff_state
      , a.SOAC																			AS stopoff_customer_area_code
      , a.SOPHNM																		AS stopoff_customer_phone_number
      , TRIM(a.SOCONT)																	AS stopoff_contact_info
      , TRIM(a.SOECD1)																	AS stopoff_shipper_edi_code
      , TRIM(a.SOECD2)																	AS stopoff_consignee_edi_code
      , CASE TRIM(a.SOTYPE)
			WHEN 'E' THEN 'APPT MADE'
			WHEN 'A' THEN 'ARRIVED'
			WHEN 'D' THEN 'DEPARTED'
			ELSE 'unknown'	END															AS stopoff_last_status
      , SOEDA.date_key_pk																AS stopoff_est_arrival_date
	  , CASE 
			WHEN CONVERT(INT, a.SOETA) <= 2359 
				AND LEN(TRIM(a.SOETA)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.SOETA),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.SOETA,2),':',RIGHT(a.SOETA,2)))
			ELSE NULL END																AS stopoff_est_arrival_time
      , SOADT1.date_key_pk																AS stopoff_appt_early_date
      , SOADT2.date_key_pk																AS stopoff_appt_late_date
	  , CASE 
			WHEN CONVERT(INT, a.SOATM1) <= 2359 
				AND LEN(TRIM(a.SOATM1)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.SOATM1),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.SOATM1,2),':',RIGHT(a.SOATM1,2)))
			ELSE NULL END																AS stopoff_appt_early_time
	  , CASE 
			WHEN CONVERT(INT, a.SOATM2) <= 2359 
				AND LEN(TRIM(a.SOATM2)) = 4  
				AND CONVERT(INT,RIGHT(TRIM(a.SOATM2),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.SOATM2,2),':',RIGHT(a.SOATM2,2)))
			ELSE NULL END																AS stopoff_appt_late_time
      , SOARDT.date_key_pk																AS stopoff_arrival_date
	  , CASE 
			WHEN CONVERT(INT, a.SOARTM) <= 2359 
				AND LEN(TRIM(a.SOARTM)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.SOARTM),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.SOARTM,2),':',RIGHT(a.SOARTM,2)))
			ELSE NULL END																AS stopoff_arrival_time
      , SOLUDT.date_key_pk																AS stopoff_load_unload_date
	  , CASE 
			WHEN CONVERT(INT, a.SOLUTM) <= 2359 
				AND LEN(TRIM(a.SOLUTM)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.SOLUTM),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.SOLUTM,2),':',RIGHT(a.SOLUTM,2)))
			ELSE NULL END																AS stopoff_load_unload_time
	  , CASE TRIM(a.SOAPPR)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END															AS is_appt_required
      , TRIM(a.SOCSID)																	AS stopoff_shipper_specific_code
      , TRIM(a.SOSEL1)																	AS stopoff_seal_1_code
      , TRIM(a.SOSEL2)																	AS stopoff_seal_2_code
      , a.SOWGT																			AS stopoff_weight
      , TRIM(a.SOPIEC)																	AS stopoff_pieces																
      , TRIM(a.SOUM)																	AS stopoff_unit_of_measure
      --, a.SOSTR
      --, a.SODEPT
      , a.SOPLON																		AS stopoff_pallets_on
      , a.SOPLOF																		AS stopoff_pallets_off
      , CASE TRIM(a.SODLU)
			WHEN 'D' THEN 'DROP TRAILER'
			WHEN 'W' THEN 'WINDOWED DROP'
			WHEN 'N' THEN 'LIVE LOAD LUMPER'
			WHEN 'Y' THEN 'LIVE LOAD DRIVER'
			ELSE 'unknown'	END															AS stopoff_load_unload_type
      , TRIM(a.SOUNIT)																	AS stopoff_truck_number
      , TRIM(a.SOTRL1)																	AS stopoff_trailer_number
      --, a.SOREAS
      --, a.SOCOMP
      , TRIM(a.SODISP)																	AS stopoff_dispatch
      , TRIM(a.SOAPMI)																	AS stopoff_appt_created_initials
      , SOAPMD.date_key_pk																AS stopoff_appt_created_date
	  , CASE 
			WHEN CONVERT(INT, a.SOAPMT) <= 2359 
				AND LEN(TRIM(a.SOAPMT)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.SOAPMT),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.SOAPMT,2),':',RIGHT(a.SOAPMT,2)))
			ELSE NULL END																AS stopoff_appt_created_time
      , TRIM(a.SOSPEC)																	AS stopoff_message
	  , CASE TRIM(a.SOAPTM)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END															AS is_appt_created
      , SOA@DD.date_key_pk																AS stopoff_appt_date_at_dispatch
	  , CASE 
			WHEN CONVERT(INT, a.SOA@DT) <= 2359 
				AND LEN(TRIM(a.SOA@DT)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.SOA@DT),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.SOA@DT,2),':',RIGHT(a.SOA@DT,2)))
			ELSE NULL END																AS stopoff_appt_time_at_dispatch
--INTO data_central_wh.silver.ibmi_stopoff
FROM data_central_lh.dbo.ibmi_stopoff_bronze a
LEFT JOIN data_central_wh.gold.dim_date SOEDA ON a.SOEDA = SOEDA.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SOADT1 ON a.SOADT1 = SOADT1.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SOADT2 ON a.SOADT2 = SOADT2.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SOARDT ON a.SOARDT = SOARDT.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SOLUDT ON a.SOLUDT = SOLUDT.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SOAPMD ON a.SOAPMD = SOAPMD.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SOA@DD ON a.SOA@DD = SOA@DD.date_ordinal