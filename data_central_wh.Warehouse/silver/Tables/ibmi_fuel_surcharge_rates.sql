CREATE TABLE [silver].[ibmi_fuel_surcharge_rates] (

	[fuel_surcharge_rates_customer_code] varchar(8000) NULL, 
	[fuel_surcharge_rates_customer_type_code] varchar(8000) NULL, 
	[fuel_surcharge_rates_dry_rate] decimal(2,2) NULL, 
	[fuel_surcharge_rates_effective_date] date NULL, 
	[fuel_surcharge_rates_reefer_rate] decimal(2,2) NULL, 
	[fuel_surcharge_rates_intermodal_rate] decimal(2,2) NULL
);