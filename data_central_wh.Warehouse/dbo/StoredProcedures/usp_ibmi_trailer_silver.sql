/***************************************************************************************************
Procedure:          dbo.usp_ibmi_trailer_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of trailer Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_trailer_master
Affected table(s):  silver.ibmi_trailer_master
Usage:              EXEC dbo.usp_ibmi_trailer_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_trailer_silver]
AS

SET NOCOUNT ON

DELETE FROM  silver.ibmi_trailer

INSERT INTO silver.ibmi_trailer
SELECT
	  TRIM(a.TRTRLR)
    , TRIM(a.TROWNR)
    , trcred.date_key_pk																		AS trailer_record_create_date
	, CASE WHEN CONVERT(INT, a.TRCRET) < 2400 AND LEN(TRIM(a.TRCRET)) = 4
		THEN CONVERT(TIME,CONCAT(LEFT(a.TRCRET,2),':',RIGHT(a.TRCRET,2)))
		ELSE NULL END																		AS trailer_record_create_time
    , TRIM(a.TRCREI)
    , trupdd.date_key_pk																		AS trailer_record_update_date	
	, CASE WHEN CONVERT(INT, a.TRUPDT) < 2400 AND LEN(TRIM(a.TRUPDT)) = 4
		THEN CONVERT(TIME,CONCAT(LEFT(a.TRUPDT,2),':',RIGHT(a.TRUPDT,2)))
		ELSE NULL END																		AS trailer_record_update_time											
    , TRIM(a.TRUPDI)		
    , TRIM(a.TRCO) 
    , TRIM(a.TRDV)
    , TRIM(a.TRTM)
    , TRIM(a.TRYEAR)
    , TRIM(a.TRMAKE)
    , TRIM(a.TRSER)
    , TRIM(a.TRMNPR)
    , TRIM(a.TRBAST)
    , TRIM(a.TRNY)
    , TRIM(a.TRTYPE)
    , TRIM(a.TRTRST)
    , trpdat.date_key_pk																		AS trailer_purchase_date
    , TRIM(a.TRARA)
    , TRIM(a.TRORD)
    , TRIM(a.TRDISP)
    , TRIM(a.TRUNIT)
    , TRIM(a.TRDCTY)
    , TRIM(a.TRDST)
    , treta.date_key_pk																			AS trailer_eta_date
    , TRIM(a.TRCCTY)
    , TRIM(a.TRCST)
    , trcdat.date_key_pk																		AS trailer_last_contact_date
    , TRIM(a.TRMSG)
    , TRIM(a.TRDLT)
    , TRIM(a.TRFLET)
    , TRIM(a.TRAXLE)
    , a.TREMWT
    , a.TRGRWT
    , a.TRHEIG
    , a.TRLENG
    , a.TRCOST
    , TRIM(a.TRPRLD)
    , TRIM(a.TRCONT)
    , a.TRHOUR
    , a.TRHUB
    , TRIM(a.TRMULT)
    , a.TRWIDE
    , a.TRCUBE
    , a.TRIDIM
    , a.TRDDIM
    , TRIM(a.TRTSIZ)
    , TRIM(a.TRTTYP)
    , TRIM(a.TRMISC)
    , a.TRPERC
    , a.TRLRAT
    , a.TRERAT
    , TRIM(a.TRLFLG)
    , a.TRL_PL
    , TRIM(a.TRLTMP)
    , TRIM(a.TRLCOD)
    , TRIM(a.TRCUST)
    , TRIM(a.TRGATE)
    , TRIM(a.TRTYP2)
FROM data_central_lh.dbo.ibmi_trailer_bronze a
LEFT JOIN gold.dim_date trcred ON a.TRCRED = trcred.date_ordinal
LEFT JOIN gold.dim_date trupdd ON a.TRUPDD = trupdd.date_ordinal
LEFT JOIN gold.dim_date trpdat ON a.TRPDAT = trpdat.date_ordinal
LEFT JOIN gold.dim_date treta ON a.TRETA = treta.date_ordinal
LEFT JOIN gold.dim_date trcdat ON a.TRCDAT = trcdat.date_ordinal