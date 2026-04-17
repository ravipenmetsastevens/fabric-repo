-- Auto Generated (Do not modify) 96C4CFD064D003943A8FA5422A53330F790D18B7CD16AA02C62BF73C765F3BDF
CREATE   VIEW gold.vw_truck_positions_latest AS
WITH r AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY plt_truck_id
           ORDER BY ts_utc DESC, heartbeat_id DESC
         ) AS rn
  FROM gold.vw_truck_positions
  WHERE is_valid_gps = 1
)
SELECT * FROM r WHERE rn = 1;