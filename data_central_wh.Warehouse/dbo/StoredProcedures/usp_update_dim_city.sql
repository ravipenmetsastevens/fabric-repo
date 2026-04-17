/***************************************************************************************************
Procedure:          dbo.usp_update_dim_city
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Provides an extract from area and city silver
					used to update city gold.
Called by:            Azure Data Factory
					Pipeline: ibmi_city_master
Affected table(s):  gold.dim_city
Usage:              EXEC dbo.usp_update_dim_city

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1             10/1/2024			Tom Wolfenden		  Aligned column count and selection with dimension
													  so that copy data could be done within SP.
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_update_dim_city]
AS

SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DELETE FROM gold.dim_city

INSERT INTO gold.dim_city
SELECT  
	   row_number() OVER (ORDER BY a.city_code, a.city_record_number) AS city_id_pk
	  ,a.[city_code]
      ,a.[city_state]
      ,a.[city_short_code]
      ,a.[city_country]
	  ,a.county_code
	  ,a.[city_zip]
	  ,a.[city_zip_suffix]
	  ,a.[city_area_code]
	  , CASE WHEN LEN(b.area_name) = 0 OR b.area_name IS NULL
			THEN 'unknown'
			ELSE b.area_name END				AS city_area_name
	  , CASE WHEN LEN(b.area_short_name) = 0 OR b.area_short_name IS NULL
			THEN 'unknown'
			ELSE b.area_short_name END			AS city_area_short_name
	  , CASE WHEN LEN(b.area_zone_code) = 0 OR b.area_zone_code IS NULL
			THEN 'unknown'
			ELSE b.area_zone_code END			AS city_area_zone_code
	  , CASE WHEN LEN(b.area_region_code) = 0 OR b.area_region_code IS NULL
			THEN 'unknown'
			ELSE b.area_region_code END			AS city_area_region_code
	  ,a.[city_timezone]
	  ,a.[direction_from_near_city]
      ,a.[distance_from_near_city]
	  ,a.[is_city_population_est]
	  ,a.[city_population]
	  ,a.[city_name]
	  ,a.[city_short_name]
	  ,a.[city_latitude]
      ,a.[city_longitude]
/*	  --V1
      ,a.[direction_latitude]
      ,a.[direction_longitude]
      ,a.[commercial_zone]
      ,a.[county_code]
      ,a.[bea_code]
      ,a.[gu_code]
      ,a.[smsa_code]    
      ,a.[city_zip_suffix]
      ,a.[splc_code]
      ,a.[city_territory_code]
      ,a.[is_same_state_twice]
      ,a.[is_half_zone]
      ,a.[has_daylight_savings]
      ,a.[is_household_movers]
      ,a.[is_big_city_code]
      ,a.[has_duplicate_city_in_state]
      ,a.[near_city_code]
      ,a.[is_city_in_two_counties]
      ,a.[other_county_code]
      ,a.[city_size_code]
      ,a.[city_level_code]
      ,a.[is_county_qualified]
      ,a.[milemarker_abbrev]
*/
FROM	silver.ibmi_city_master a
LEFT JOIN silver.ibmi_area_master b ON a.city_area_code = b.area_code