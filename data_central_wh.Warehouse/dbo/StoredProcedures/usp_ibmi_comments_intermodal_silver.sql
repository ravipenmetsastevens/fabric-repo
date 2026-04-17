/***************************************************************************************************
Procedure:          dbo.usp_ibmi_comments_intermodal_silver
Create Date:        2024-06-14
Author:             Jeremy Shahan
Description:        Truncate and load of CD Billing Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_comments_intermodal
Affected table(s):  silver.ibmi_comments_intermodal
Usage:              EXEC dbo.usp_ibmi_comments_intermodal_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_comments_intermodal_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_comments_intermodal

INSERT INTO silver.ibmi_comments_intermodal
SELECT
	    a.[CDATE]																			AS comments_intermodal_record_date
      , TRIM(a.[OCORD])																		AS comments_intermodal_load_number
      , TRIM(a.[OCREC])																		AS comments_intermodal_record_number
      , TRIM(a.[OCTYP])																		AS comments_intermodal_record_type
      , TRIM(a.[OCLOC])																		AS comments_intermodal_location
      , TRIM(a.[OCDESC])																	AS comments_intermodal_description
      ,	TRIM(a.[OCDLT])																		AS comments_intermodal_delete_code
      --, TRIM(a.[OCFIL])																	Unused
      --, a.[OCDATE]																		Unused (converted)
      , TRIM(a.[OCINIT])																	AS comments_intermodal_user_initials
FROM data_central_lh.dbo.ibmi_comments_intermodal_bronze a