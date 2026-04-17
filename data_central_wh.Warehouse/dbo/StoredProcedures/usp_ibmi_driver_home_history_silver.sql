/***************************************************************************************************
Procedure:          dbo.usp_ibmi_driver_home_history_silver
Create Date:        2025-08-26
Author:             Jeremy Shahan
Description:        Truncate and load of Driver Home History to Silver
Called by:          Fabric
					Pipeline: ibmi_driver_home_history
Affected table(s):  silver.ibmi_driver_home_history
Usage:              EXEC dbo.usp_ibmi_driver_home_history_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_driver_home_history_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_driver_home_history

INSERT INTO silver.ibmi_driver_home_history
SELECT 

	    TRIM(a.DPCODE)																	AS drv_home_hist_driver_code
      , DPPHAD.date_key_pk																AS drv_home_hist_previous_arrival_date
      , DPHDDT.date_key_pk																AS drv_home_hist_departure_date
--INTO data_central_wh.silver.ibmi_driver_home_history
FROM data_central_lh.dbo.ibmi_driver_home_history_bronze a
LEFT JOIN data_central_wh.gold.dim_date DPPHAD ON a.DPPHAD = DPPHAD.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date DPHDDT ON a.DPHDDT = DPHDDT.date_ordinal