/***************************************************************************************************
Procedure:          dbo.usp_ibmi_tlb_tlbinv_silver
Create Date:        2025-10-02
Author:             Jeremy Shahan
Description:        Truncate and load of TLBINV to Silver
Called by:          Fabric
					Pipeline: ibmi_tlb_tlbinv
Affected table(s):  silver.ibmi_tlb_tlbinv
Usage:              EXEC dbo.usp_ibmi_tlb_tlbinv_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_tlb_tlbinv_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_tlb_tlbinv

INSERT INTO silver.ibmi_tlb_tlbinv

SELECT
	    TRIM(a.TNSTAT)															AS tlb_tlbinv_status_code
      , TRIM(a.TNCARR)															AS tlb_tlbinv_carrier_code
      , TRIM(a.TNDIV)															AS tlb_tlbinv_division_code
      , TRIM(a.TNORD)															AS tlb_tlbinv_load_number
      , TRIM(a.TNDISP)															AS tlb_tlbinv_dispatch
      , TRIM(a.TNOORD)															AS tlb_tlbinv_original_load_number
      , TRIM(a.TNODIS)															AS tlb_tlbinv_original_dispatch
      , TRIM(a.TNINV)															AS tlb_tlbinv_carrier_invoice_number
      , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),CONVERT(INT,a.TNIDAT)))				AS tlb_tlbinv_invoice_date
	  , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),CONVERT(INT,a.TNUDAT)))				AS tlb_tlbinv_due_date
      , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),CONVERT(INT,a.TNPDAT)))				AS tlb_tlbinv_to_pay_date
	  , CONVERT(DECIMAL(18,2), a.TNIAMT)												AS tlb_tlbinv_invoice_amount
      , TRIM(a.TNREF)															AS tlb_tlbinv_reference
      , TRIM(a.TNFC)															AS tlb_tlbinv_fund_code
      , CONVERT(INT, a.TNCHK)													AS tlb_tlbinv_check_number
	  , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),CONVERT(INT,a.TNCDAT)))				AS tlb_tlbinv_check_date
      , CONVERT(DECIMAL(18,2), a.TNCAMT)												AS tlb_tlbinv_check_amount
      --, a.TNDBGL
      --, a.TNCRGL
      --, a.TNDBCC
      --, a.TNCRCC
      --, a.TNHANF
      , CASE TRIM(a.TNEXPF)
			WHEN 'Y' THEN 'TRUE'
			ELSE 'FALSE'	END													AS is_expensed
      , CASE TRIM(a.TNVOID)
			WHEN 'Y' THEN 'TRUE'
			ELSE 'FALSE'	END													AS is_voided
      , TRIM(a.TNBKMO)															AS tlb_tlbinv_expensed_month
      , TRIM(a.TNBKYR)															AS tlb_tlbinv_expensed_year
      , TRIM(a.TNVBKM)															AS tlb_tlbinv_voided_month
      , TRIM(a.TNVBKY)															AS tlb_tlbinv_voided_year
      , TRIM(a.TNPBKM)															AS tlb_tlbinv_paid_month
      , TRIM(a.TNPBKY)															AS tlb_tlbinv_paid_year
      , TRIM(a.TNEUSE)															AS tlb_tlbinv_create_user_code
	  , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),CONVERT(INT,a.TNEDAT)))				AS tlb_tlbinv_create_date
      , CASE 
			WHEN LEN(CAST(a.TNETIM AS INT)) = 3 
				THEN TIMEFROMPARTS(
					SUBSTRING(CONVERT(VARCHAR(12),a.TNETIM), 1, 1),
					SUBSTRING(CONVERT(VARCHAR(12),a.TNETIM), 2, 2),
					0,
					0,
					0)
			WHEN LEN(CAST(a.TNETIM AS INT)) = 4 
				THEN TIMEFROMPARTS(
					SUBSTRING(CONVERT(VARCHAR(12),a.TNETIM), 1, 2),
					SUBSTRING(CONVERT(VARCHAR(12),a.TNETIM), 3, 2),
					0,
					0,
					0) ELSE NULL	END											AS tlb_tlbinv_create_time
      , TRIM(a.TNMUSE)															AS tlb_tlbinv_maint_user_code
	  , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),CONVERT(INT,a.TNMDAT)))				AS tlb_tlbinv_maint_date
      , CASE 
			WHEN LEN(CAST(a.TNMTIM AS INT)) = 3 
				THEN TIMEFROMPARTS(
					SUBSTRING(CONVERT(VARCHAR(12),a.TNMTIM), 1, 1),
					SUBSTRING(CONVERT(VARCHAR(12),a.TNMTIM), 2, 2),
					0,
					0,
					0)
			WHEN LEN(CAST(a.TNMTIM AS INT)) = 4 
				THEN TIMEFROMPARTS(
					SUBSTRING(CONVERT(VARCHAR(12),a.TNMTIM), 1, 2),
					SUBSTRING(CONVERT(VARCHAR(12),a.TNMTIM), 3, 2),
					0,
					0,
					0) ELSE NULL	END											AS tlb_tlbinv_maint_time
FROM data_central_lh.dbo.ibmi_tlb_tlbinv_bronze a