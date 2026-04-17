/***************************************************************************************************
Procedure:          dbo.usp_update_dim_commodity
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Provides an extract from commodity, division and gl_account silver
					used to update commodity gold.
Called by:            Azure Data Factory
					Pipeline: ibmi_commodity_master
Affected table(s):  gold.dim_commodity
Usage:              EXEC dbo.usp_update_dim_commodity

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_update_dim_commodity]
AS

SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT
	  a.commodity_key
	, a.commodity_code
	, a.division_code						AS commodity_division_code
	, b.division_name						AS commodity_division_name
	, b.division_status						AS commodity_division_status
	, a.is_commodity_deleted
	, a.commodity_short_descr
	, a.commodity_description
	, a.commodity_cost_center				AS commodity_gl_acct
	, c.gl_account_description				AS commodity_gl_acct_description
	, a.commodity_revenue_type     -- this is a code that we might need to expand on
	, a.is_washout_required
FROM [silver].[ibmi_commodity] a
LEFT JOIN [silver].[ibmi_division] b ON a.division_code = b.division_code
LEFT JOIN (SELECT z.* FROM [silver].[ibmi_gl_account] z
           JOIN (SELECT gl_account_number, MAX(gl_account_level) AS max_level
				 FROM [silver].[ibmi_gl_account]
				 GROUP BY gl_account_number) y ON z.gl_account_number = y.gl_account_number
											  AND z.gl_account_level = y.max_level) c ON a.commodity_cost_center = c.gl_account_number