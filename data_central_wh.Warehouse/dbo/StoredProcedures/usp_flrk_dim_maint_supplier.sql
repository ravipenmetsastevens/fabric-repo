/***************************************************************************************************
Procedure:          dbo.usp_flrk_dim_maint_supplier
Create Date:        2024-05-18
Author:             Tom Wolfenden
Description:        Add data for Fleetrock suppliers from silver to gold
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_supplier
Affected table(s):  gold.dim_maint_supplier
Usage:              EXEC dbo.usp_flrk_dim_maint_supplier

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_flrk_dim_maint_supplier]
AS

-- update existing suppliers
UPDATE [gold].[dim_maint_supplier] SET
	  [supplier_name]				= s.[supplier_name]
	, [supplier_custom_id]		    = s.[supplier_custom_id]
	, [supplier_street_address_1]	= s.[supplier_street_address_1]
	, [supplier_street_address_2]	= s.[supplier_street_address_2]
	, [supplier_city]				= s.[supplier_city]
	, [supplier_state]				= s.[supplier_state]
	, [supplier_zip_code]			= s.[supplier_zip_code]
	, [supplier_country]			= s.[supplier_country]
	, [supplier_phone]				= s.[supplier_phone]
	, [supplier_email]				= s.[supplier_email]
	, [payment_term_days]			= s.[payment_term_days]
	, [supplier_notes]				= s.[supplier_notes]
	, [supplier_added_datetime]		= s.[supplier_added_datetime]
	, [supplier_added_date]			= CONVERT(DATE, s.[supplier_added_datetime])
	, [supplier_type]				= s.[supplier_type]
FROM [gold].[dim_maint_supplier] t
JOIN [silver].[flrk_supplier] s ON t.supplier_name = s.supplier_name

--insert new suppliers
INSERT INTO [gold].[dim_maint_supplier]
SELECT       s.[supplier_name]
			,s.[supplier_custom_id]
			,s.[supplier_street_address_1]
			,s.[supplier_street_address_2]
			,s.[supplier_city]
			,s.[supplier_state]
			,s.[supplier_zip_code]
			,s.[supplier_country]
			,s.[supplier_phone]
			,s.[supplier_email]
			,s.[payment_term_days]
			,s.[supplier_notes]
			,NULL AS [supplier_latitude]
			,NULL AS [supplier_longitude]
			,s.[supplier_added_datetime]
			,CONVERT(DATE, s.[supplier_added_datetime])
			,s.[supplier_type]
FROM [silver].[flrk_supplier] s
LEFT JOIN [gold].[dim_maint_supplier] t on s.supplier_name = t.supplier_name
WHERE t.supplier_name IS NULL