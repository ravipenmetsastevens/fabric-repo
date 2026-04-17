/***************************************************************************************************
Procedure:          dbo.usp_ibmi_load_extension_silver
Create Date:        2025-10-07
Author:             Jeremy Shahan
Description:        Truncate and load of Load Extension to Silver
Called by:          Fabric
					Pipeline: ibmi_load_extension
Affected table(s):  silver.ibmi_load_extension
Usage:              EXEC dbo.usp_ibmi_load_extension_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            2025-11-17        Jeremy Shahan       Added Business Class/Description
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_load_extension_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_load_extension

INSERT INTO silver.ibmi_load_extension
SELECT 
		TRIM(a.LEORD#)					AS load_ext_load_number
      , TRIM(a.LEDISP)					AS load_ext_dispatch
      , TRIM(a.LEBUNT)					AS load_ext_business_unit_code
      , TRIM(a.LERES1)                  AS load_ext_business_class
      , TRIM(a.LERES2)                  AS load_ext_business_description
      --, a.LERES3
      --, a.LERES4
      --, a.LERES5
--INTO data_central_wh.silver.ibmi_load_extension
FROM data_central_lh.dbo.ibmi_load_extension_bronze a