/***************************************************************************************************
Procedure:          dbo.usp_ibmi_edi_processing_history_silver
Create Date:        2026-01-06
Author:             Jeremy Shahan
Description:        Truncate and load of EDI Processing Records to Silver
Called by:          Fabric
					Pipeline: ibmi_edi_processing_history
Affected table(s):  silver.ibmi_edi_processing_history
Usage:              EXEC dbo.usp_ibmi_edi_processing_history_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_edi_processing_history_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_edi_processing_history

INSERT INTO silver.ibmi_edi_processing_history
SELECT 
		TRIM(a.ATEDCD)													AS edi_proc_hist_customer_code
      , TRIM(a.ATSHIP)													AS edi_proc_hist_customer_ship_number
      , a.ATSEQ															AS edi_proc_hist_sequence_number
      , TRIM(a.ATORDN)													AS edi_proc_hist_stv_load_number
      , CASE TRIM(a.ATACTN)
			WHEN 'A' THEN 'ACCEPTED'
			WHEN 'R' THEN 'REJECTED'
			WHEN 'D' THEN 'REJECTED'
			ELSE 'unknown' END											AS edi_proc_hist_action
      , ATDATE.date_key_pk												AS edi_proc_hist_action_date
	  , CASE 
			WHEN a.ATTIME <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATTIME))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ATTIME),2),RIGHT(CONVERT(INT,a.ATTIME),2),0,0,0)
			WHEN a.ATTIME <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATTIME))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ATTIME),1),RIGHT(CONVERT(INT,a.ATTIME),2),0,0,0)
			WHEN a.ATTIME <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATTIME))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.ATTIME),0,0,0)
			ELSE NULL END												AS edi_proc_hist_action_time     
      , TRIM(a.ATEVCD)													AS edi_proc_hist_event_code
      , ATEVDT.date_key_pk												AS edi_proc_hist_event_date
	  , CASE 
			WHEN a.ATEVTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATEVTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ATEVTM),2),RIGHT(CONVERT(INT,a.ATEVTM),2),0,0,0)
			WHEN a.ATEVTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATEVTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ATEVTM),1),RIGHT(CONVERT(INT,a.ATEVTM),2),0,0,0)
			WHEN a.ATEVTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATEVTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.ATEVTM),0,0,0)
			ELSE NULL END												AS edi_proc_hist_event_time     
      , TRIM(a.ATEDES)													AS edi_proc_hist_event_description
      , ATTRDT.date_key_pk												AS edi_proc_hist_trasmit_date
	  , CASE 
			WHEN a.ATTRTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATTRTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ATTRTM),2),RIGHT(CONVERT(INT,a.ATTRTM),2),0,0,0)
			WHEN a.ATTRTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATTRTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ATTRTM),1),RIGHT(CONVERT(INT,a.ATTRTM),2),0,0,0)
			WHEN a.ATTRTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ATTRTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.ATTRTM),0,0,0)
			ELSE NULL END												AS edi_proc_hist_transmit_time     
      , TRIM(a.ATOCON)													AS edi_proc_hist_pillsbury_load_number	
--INTO data_central_wh.silver.ibmi_edi_processing_history
FROM data_central_lh.dbo.ibmi_edi_processing_history_bronze a
LEFT JOIN gold.dim_date ATDATE ON a.ATDATE = ATDATE.date_ordinal
LEFT JOIN gold.dim_date ATEVDT ON a.ATEVDT = ATEVDT.date_ordinal
LEFT JOIN gold.dim_date ATTRDT ON a.ATTRDT = ATTRDT.date_ordinal