/***************************************************************************************************
Procedure:          dbo.usp_ibmi_toll_history_silver
Create Date:        2024-05-07
Author:             Jeremy Shahan
Description:        Truncate and load of Toll History Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_toll_history
Affected table(s):  silver.ibmi_toll_history
Usage:              EXEC dbo.usp_ibmi_toll_history_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_toll_history_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_toll_history

INSERT INTO silver.ibmi_toll_history
SELECT
	  TRIM(TAG)																		AS toll_history_tag_number
	, TRIM(a.UNIT)																		AS toll_history_truck_number
	, TOLLDT																			AS toll_history_toll_date
	, TRIM(TLG)																			AS toll_history_location
	, TLI																				AS toll_history_amount
	, TRIM(UNOWN)																		AS toll_history_owner_code
	, TRIM(UNDV)																		AS toll_history_division_code
	, TRIM(TLODR)																		AS toll_history_load_number
	, TRIM(TLDISP)																		AS toll_history_dispatch_number
	, TRIM(TLBILL)																		AS toll_history_bill_to_code
	, UPLDDT																			AS toll_history_upload_date
FROM data_central_lh.dbo.ibmi_toll_history_bronze a