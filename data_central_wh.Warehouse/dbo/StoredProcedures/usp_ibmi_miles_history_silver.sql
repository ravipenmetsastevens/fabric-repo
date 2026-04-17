/***************************************************************************************************
Procedure:          dbo.usp_ibmi_miles_history_silver
Create Date:        2026-03-27
Author:             Jeremy Shahan
Description:        Truncate and load of Daily Driver Mileage Records to Silver
Called by:          Fabric
					Pipeline: ibmi_miles_history
Affected table(s):  silver.ibmi_miles_history
Usage:              EXEC dbo.usp_miles_history_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_miles_history_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_miles_history

INSERT INTO silver.ibmi_miles_history
SELECT 
        a.DDDATE                                                        AS mile_hist_date
      , TRIM(a.DDDRCODE)                                                AS mile_hist_driver_code
      , TRIM(a.DDUNIT)                                                  AS mile_hist_truck_number
      , TRIM(a.DDORDER)                                                 AS mile_hist_load_number
      , TRIM(a.DDDISP)                                                  AS mile_hist_dispatch
      , a.DDPDMILES                                                     AS mile_hist_distributed_dispatch_miles
      --, a.DDTOTHUB                                                    AS mile_hist_total_hub_miles
      , a.DDHMILES                                                      AS mile_hist_hub_miles
      , a.DDHRATIO                                                      AS mile_hist_hub_ratio
      , a.DDDISPTCH                                                     AS mile_hist_adj_dispatch_miles
      , a.DDGOALMILE                                                    AS mile_hist_goal_miles
      --, a.DDOUTROUT                                                     AS mile_hist_out_of_route_miles
      --, a.DDFUTURE
--INTO data_central_wh.silver.ibmi_miles_history
FROM data_central_lh.dbo.ibmi_miles_history_bronze a