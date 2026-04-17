CREATE TABLE [silver].[netr_geofence] (

	[geofence_id] bigint NULL, 
	[geofence_name] varchar(8000) NULL, 
	[geofence_type] varchar(8000) NULL, 
	[geofence_sub_type] varchar(8000) NULL, 
	[geofence_shape] varchar(8000) NULL, 
	[geofence_country] varchar(8000) NULL, 
	[geofence_state] varchar(8000) NULL, 
	[geofence_city] varchar(8000) NULL, 
	[geofence_street] varchar(8000) NULL, 
	[geofence_zipcode] varchar(8000) NULL, 
	[geofence_radius] float NULL, 
	[geofence_duration] bigint NULL, 
	[data.center] varchar(8000) NULL, 
	[geofence_center_latitude] float NULL, 
	[geofence_center_longitude] float NULL, 
	[data.polygon] varchar(8000) NULL, 
	[geofence_polygon_latitude] float NULL, 
	[geofence_polygon_longitude] float NULL, 
	[data.status] varchar(8000) NULL
);