CREATE TABLE [silver].[ibmi_payclass] (

	[payclass_class_code] varchar(8000) NULL, 
	[payclass_unit_type_code] varchar(8000) NULL, 
	[payclass_pay_rate_factor] decimal(34,6) NULL, 
	[payclass_description] varchar(8000) NULL, 
	[payclass_unbank_overtime_code] varchar(8000) NULL, 
	[payclass_bucket_code] decimal(34,6) NULL, 
	[is_income_taxable] varchar(7) NOT NULL, 
	[has_unemployment_insurance] varchar(7) NOT NULL, 
	[has_cpp_pension_pay] varchar(7) NOT NULL, 
	[has_union_dues] varchar(7) NOT NULL, 
	[has_401k_pay] varchar(7) NOT NULL, 
	[has_cafeteria_pay] varchar(7) NOT NULL, 
	[has_employee_workers_comp] varchar(7) NOT NULL, 
	[has_employer_workers_comp] varchar(7) NOT NULL, 
	[payclass_truck_expense_account_number] varchar(8000) NULL, 
	[payclass_expense_account_number] varchar(8000) NULL
);