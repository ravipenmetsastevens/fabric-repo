CREATE TABLE [silver].[ibmi_miles_history] (

	[mile_hist_date] date NULL, 
	[mile_hist_driver_code] varchar(8000) NULL, 
	[mile_hist_truck_number] varchar(8000) NULL, 
	[mile_hist_load_number] varchar(8000) NULL, 
	[mile_hist_dispatch] varchar(8000) NULL, 
	[mile_hist_distributed_dispatch_miles] decimal(34,6) NULL, 
	[mile_hist_hub_miles] decimal(34,6) NULL, 
	[mile_hist_hub_ratio] decimal(34,6) NULL, 
	[mile_hist_adj_dispatch_miles] decimal(34,6) NULL, 
	[mile_hist_goal_miles] decimal(34,6) NULL
);