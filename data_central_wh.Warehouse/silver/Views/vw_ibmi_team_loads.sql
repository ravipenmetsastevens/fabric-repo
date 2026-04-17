-- Auto Generated (Do not modify) F9D149B2FCAC66F7E2442CBA6CA97487E785FC521FE10287713D7147C50B93DF

-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_ibmi_team_loads] AS

SELECT DISTINCT load_load_number
, 'Y' AS 'team_flag'
FROM silver.ibmi_load
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = load_load_number
WHERE load_seat_2_driver_code <> ''