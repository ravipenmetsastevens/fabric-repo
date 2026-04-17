-- Auto Generated (Do not modify) 06DACD7829383393EF48B3E4697B42168FF79E5533B4AEA5B2450FDCF374295E
CREATE   VIEW [gold].[vw_ibmi_miles_history]
AS
SELECT
      mile_hist_date                         AS mileage_date
    , mile_hist_driver_code                  AS driver_id
    , mile_hist_truck_number                 AS truck_id
    , mile_hist_load_number                  AS load_id
    , mile_hist_dispatch                     AS dispatch_id
    , mile_hist_distributed_dispatch_miles   AS dispatch_miles
    , mile_hist_hub_miles                    AS hub_miles
    , mile_hist_hub_ratio                    AS hub_mile_ratio
    , mile_hist_adj_dispatch_miles           AS adjusted_dispatch_miles
    , mile_hist_goal_miles                   AS target_miles
FROM [silver].[ibmi_miles_history];