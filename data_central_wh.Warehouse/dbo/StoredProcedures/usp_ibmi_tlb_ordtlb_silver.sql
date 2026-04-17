/***************************************************************************************************
Procedure:          dbo.usp_ibmi_tlb_ordtlb_silver
Create Date:        2025-10-16
Author:             Jeremy Shahan
Description:        Truncate and load of Truck Pay to Silver
Called by:          Fabric
					Pipeline: ibmi_tlb_ordtlb
Affected table(s):  silver.ibmi_tlb_ordtlb
Usage:              EXEC dbo.usp_ibmi_tlb_ordtlb_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_tlb_ordtlb_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_tlb_ordtlb

INSERT INTO silver.ibmi_tlb_ordtlb
SELECT
		TRIM(a.ORLM)														AS tlb_ordtlb_load_number
      , TRIM(a.ORCARR)														AS tlb_ordtlb_carrier_code
      , TRIM(a.ORBROK)														AS tlb_ordtlb_broker_code
      , TRIM(a.ORDRVN)														AS tlb_ordtlb_driver_full_name
      , TRIM(a.ORLTRK)														AS tlb_ordtlb_truck_number
      , TRIM(a.ORLTRL)														AS tlb_ordtlb_trailer_number
      , a.ORTRKP															AS tlb_ordtlb_truck_pay_amount
      --, a.ORMSC1
      --, a.ORMSC2
      --, a.ORMSC3
      --, a.ORMSC4
      --, a.ORMSC5
      --, a.ORMSC6
      --, a.ORMSC7
      --, a.ORMSC8
      --, a.ORMSC9
      --, a.ORMSCA
      --, a.ORMFL
      , CASE TRIM(a.ORSETT)
			WHEN 'Y' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_trip_settled
      , CASE TRIM(a.ORACCF)
			WHEN 'Y' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_expense_accrued
      , a.ORACCA														AS tlb_ordtlb_expense_accrual_amount
      , TRY_CONVERT(DATE, CAST(CONVERT(INT,a.ORCKDT) AS VARCHAR(8)), 112)	AS tlb_ordtlb_check_date
--INTO data_central_wh.silver.ibmi_tlb_ordtlb
FROM data_central_lh.dbo.ibmi_tlb_ordtlb_bronze a