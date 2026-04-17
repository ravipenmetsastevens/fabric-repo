CREATE TABLE [silver].[ibmi_tlb_ordtlb] (

	[tlb_ordtlb_load_number] varchar(8000) NULL, 
	[tlb_ordtlb_carrier_code] varchar(8000) NULL, 
	[tlb_ordtlb_broker_code] varchar(8000) NULL, 
	[tlb_ordtlb_driver_full_name] varchar(8000) NULL, 
	[tlb_ordtlb_truck_number] varchar(8000) NULL, 
	[tlb_ordtlb_trailer_number] varchar(8000) NULL, 
	[tlb_ordtlb_truck_pay_amount] decimal(34,6) NULL, 
	[is_trip_settled] varchar(5) NOT NULL, 
	[is_expense_accrued] varchar(5) NOT NULL, 
	[tlb_ordtlb_expense_accrual_amount] decimal(34,6) NULL, 
	[tlb_ordtlb_check_date] date NULL
);