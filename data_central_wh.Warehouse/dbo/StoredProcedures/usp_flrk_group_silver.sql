/***************************************************************************************************
Procedure:          dbo.usp_flrk_group_silver
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        Add data for Fleetrock groups from bronze to silver
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_group
Affected table(s):  silver.flrk_group
Usage:              EXEC dbo.usp_flrk_group_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE dbo.usp_flrk_group_silver
AS

DELETE FROM silver.flrk_group

INSERT INTO silver.flrk_group
SELECT DISTINCT
	    a.group_name
      , a.group_label
      , a.approval_over
      , a.approval_buffer
      , a.group_hierarchy
      , a.group_parent
FROM data_central_lh.dbo.flrk_group_bronze a