-- Auto Generated (Do not modify) A61E74DBEE7D597A765B235BF352D3BA8AFBB473AC70FFC89CD838B93666C36A
create view gold.Customer as
SELECT -- intuitively picked columns. Can evolve as requirements dictate
	[customer_code] -- key for relationships in model
    ,[cust_name]   
    ,[cust_city_code]
    ,[bill_to_code]
    --,[cust_territory]
    ,[cust_salesperson] -- is there a table of Salespeople we can join to? These are initials only
    ,[cust_shipper_code]
    ,[last_activity_date]   
    ,[cust_country]    
    ,[customer_rank] -- I am unsure if these are maintained but good value
    ,[cust_create_date]      
    ,[cust_service_rep] -- same as above, where can we translate and is it maintained?
    ,[company_code] -- Is there a company table
    ,[division_code] -- there is a division table, worth as a sub dim?
FROM 
	[silver].[ibmi_customer] -- need to confirm correct silver layer table to load to Gold
where
	[is_deleted] = 'FALSE' and	-- this is an assumption and needs to be verified
	[last_activity_date] > '2020-01-01' -- unsure of this field is maintained so is also an assumption