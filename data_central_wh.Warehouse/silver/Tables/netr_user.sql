CREATE TABLE [silver].[netr_user] (

	[user_username] varchar(8000) NULL, 
	[user_firstname] varchar(8000) NULL, 
	[user_lastname] varchar(8000) NULL, 
	[user_email] varchar(8000) NULL, 
	[user_status] varchar(8000) NULL, 
	[data.roleId] varchar(8000) NULL, 
	[user_role] varchar(8000) NULL, 
	[user_twofastatus] varchar(8) NULL, 
	[user_create_date] date NULL, 
	[user_create_time] time(0) NULL, 
	[user_update_date] date NULL, 
	[user_update_time] time(0) NULL
);