/***************************************************************************************************
Procedure:          dbo.usp_ibmi_service_exception_codes_edi_silver
Create Date:        2025-12-18
Author:             Jeremy Shahan
Description:        Truncate and load of Service Exception Codes (EDI) to Silver
Called by:          Fabric
					Pipeline: ibmi_service_exception_codes_edi
Affected table(s):  silver.ibmi_service_exception_codes_edi
Usage:              EXEC dbo.usp_ibmi_service_exception_codes_edi_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_service_exception_codes_edi_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_service_exception_codes_edi

INSERT INTO silver.ibmi_service_exception_codes_edi
SELECT 
	    --a.MESSAGE_FILE_LIBRARY
      --, a.MESSAGE_FILE
        SUBSTRING(TRIM(a.MESSAGE_ID),4,2)		AS se_codes_exception_code
        , TRIM(a.MESSAGE_TEXT)			                                        AS se_codes_exception_description													
      --, a.MESSAGE_SECOND_LEVEL_TEXT												
      --, a.SEVERITY
      --, a.MESSAGE_DATA_COUNT
      --, a.MESSAGE_DATA
      --, a.LOG_PROBLEM
      --, a.CREATION_DATE
      --, a.CREATION_LEVEL
      --, a.MODIFICATION_DATE
      --, a.MODIFICATION_LEVEL
      --, a.CCSID
      --, a.DEFAULT_PROGRAM_LIBRARY
      --, a.DEFAULT_PROGRAM
      --, a.REPLY_TYPE
      --, a.REPLY_LENGTH
      --, a.REPLY_DECIMAL_POSITIONS
      --, a.DEFAULT_REPLY
      --, a.VALID_REPLY_VALUES_COUNT
      --, a.VALID_REPLY_VALUES
      --, a.VALID_REPLY_LOWER_LIMIT
      --, a.VALID_REPLY_UPPER_LIMIT
      --, a.VALID_REPLY_RELATIONSHIP_OPERATOR
      --, a.VALID_REPLY_RELATIONSHIP_VALUE
      --, a.SPECIAL_REPLY_VALUES_COUNT
      --, a.SPECIAL_REPLY_VALUES
      --, a.DUMP_LIST_COUNT
      --, a.DUMP_LIST
      --, a.ALERT_OPTION
      --, a.ALERT_INDEX
--INTO data_central_wh.silver.ibmi_service_exception_codes_edi
FROM data_central_lh.dbo.ibmi_service_exception_codes_edi_bronze a