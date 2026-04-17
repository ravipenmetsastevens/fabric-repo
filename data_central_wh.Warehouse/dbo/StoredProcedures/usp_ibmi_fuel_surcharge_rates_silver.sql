/***************************************************************************************************
Procedure:          dbo.usp_ibmi_fuel_surcharge_rates_silver
Create Date:        2024-05-07
Author:             Jeremy Shahan
Description:        Truncate and load of Fuel Surcharge Rates Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_fuel_surcharge_rates
Affected table(s):  silver.ibmi_fuel_surcharge_rates
Usage:              EXEC dbo.usp_ibmi_fuel_surcharge_rates_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_fuel_surcharge_rates_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_fuel_surcharge_rates

INSERT INTO silver.ibmi_fuel_surcharge_rates
SELECT
	  TRIM(a.FSCODE)																		AS fuel_surcharge_rates_customer_code
	, TRIM(a.FSTYPE)																		AS fuel_surcharge_rates_customer_type_code
	, a.FSRATE																				AS fuel_surcharge_rates_dry_rate
	, FSEFDT.date_key_pk																	AS fuel_surcharge_rates_effective_date																	
	, a.FSRATER																				AS fuel_surcharge_rates_reefer_rate
	, a.FSRATEI																				AS fuel_surcharge_rates_intermodal_rate
	--, TRIM(a.FSMNMLS)																		Unused
FROM data_central_lh.dbo.ibmi_fuel_surcharge_rates_bronze a
LEFT JOIN gold.dim_date FSEFDT ON a.FSEFDT = FSEFDT.date_ordinal