/***************************************************************************************************
Procedure:          dbo.usp_ibmi_paid_loads_silver
Create Date:        2024-05-29
Author:             Jeremy Shahan
Description:        Truncate and load of load Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_paid_loads_master
Affected table(s):  silver.ibmi_paid_loads_master
Usage:              EXEC dbo.usp_ibmi_paid_loads_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_paid_loads_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_paid_load

INSERT INTO silver.ibmi_paid_load
SELECT 
	  paiddate.date_key_pk																	AS paid_loads_paid_date
	, TRIM(a.ORDER_1)																		AS paid_loads_load_number
    , TRIM(a.CUNAME)																		AS paid_loads_customer_name
	, TRIM(a.CINAMEX)																		AS paid_loads_dead_head_origin_city_name
	, TRIM(a.[STATE])																		AS paid_loads_dead_head_origin_state
	, TRIM(a.OROSNM)																		AS paid_loads_origin_city_name
	, TRIM(a.OROST)																			AS paid_loads_origin_state
	, TRIM(a.ORDSNM)																		AS paid_loads_destination_city_name
	, TRIM(a.ORDST)																			AS paid_loads_destination_state
	, orpdatg.date_key_pk																	AS paid_loads_pickup_date
	, orddatg.date_key_pk																	AS paid_loads_delivery_date
	, a.EMILES																				AS paid_loads_miles_dead_head
	, a.ORMILE																				AS paid_loads_miles_loaded
	, a.EMPNMILE																			AS paid_loads_miles_total
	--, a.HUBMILES																			Unused
	--, a.HUBMMILE																			Unused
	, a.ORPREQ																				AS paid_loads_pallet_count
	, TRIM(a.ORSTP)																			AS paid_loads_stop_count
	, a.TOTALBILLE																			AS paid_loads_billed_total
	, a.LINEHAULX																			AS paid_loads_billed_linehaul
	, a.FUELSURCHA																			AS paid_loads_billed_fuel_surcharge
	, a.UNLOADINGX																			AS paid_loads_billed_unloading
	, a.PALLETCHAR																			AS paid_loads_billed_pallet_charge
	, a.OTHERCHARG																			AS paid_loads_billed_other_charge
	, a.MEXICOCHAR																			AS paid_loads_billed_mexico_charge
	, a.STOPOFFCHA																			AS paid_loads_billed_stopoff_charge
	, a.DETENTIONX																			AS paid_loads_billed_detention
	, a.DEADHEADX																			AS paid_loads_billed_dead_head
	, a.DHAMT1																				AS paid_loads_unload_paid_to_driver
	, a.DHAMT2																				AS paid_loads_billed_tolls
	, a.MPH2																				AS paid_loads_mph
	, TRIM(a.ORARA)																			AS paid_loads_origin_area_code
	, TRIM(a.ORINAR)																		AS paid_loads_destination_area_code
	, TRIM(a.CUSLMN)																		AS paid_loads_salesperson_code
	, TRIM(a.D2DM)																			AS paid_loads_dm_code
	, TRIM(a.D2FM)																			AS paid_loads_dmol_code
	, TRIM(a.D2UNIT)																		AS paid_loads_truck_number
	--, a.RPLM																				Unused
	--, a.RPTM																				Unused
	--, a.RPNM																				Unused
	--, a.NETFSC																			Unused
FROM data_central_lh.dbo.ibmi_paid_load_bronze a
LEFT JOIN gold.dim_date paiddate ON a.PAIDDATE = paiddate.yyyymmdd
LEFT JOIN gold.dim_date orpdatg ON a.ORPDATG = orpdatg.yyyymmdd
LEFT JOIN gold.dim_date orddatg ON a.ORDDATG = orddatg.yyyymmdd