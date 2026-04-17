section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "flrk_driver_bronze_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "drv_username", DestinationColumnName = "drv_username"], [SourceColumnName = "drv_last_name", DestinationColumnName = "drv_last_name"], [SourceColumnName = "drv_first_name", DestinationColumnName = "drv_first_name"], [SourceColumnName = "drv_street_address", DestinationColumnName = "drv_street_address"], [SourceColumnName = "drv_zip_code", DestinationColumnName = "drv_zip_code"], [SourceColumnName = "drv_city", DestinationColumnName = "drv_city"], [SourceColumnName = "drv_state", DestinationColumnName = "drv_state"], [SourceColumnName = "drv_vin", DestinationColumnName = "drv_vin"], [SourceColumnName = "drv_odometer_miles", DestinationColumnName = "drv_odometer_miles"], [SourceColumnName = "drv_escrow_balance", DestinationColumnName = "drv_escrow_balance"], [SourceColumnName = "drv_start_date", DestinationColumnName = "drv_start_date"], [SourceColumnName = "drv_end_date", DestinationColumnName = "drv_end_date"], [SourceColumnName = "drv_status", DestinationColumnName = "drv_status"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared flrk_driver_bronze = let
  Source = Lakehouse.Contents(null){[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data]{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  #"Navigation 1" = Source{[Id = "flrk_driver_bronze", ItemKind = "Table"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 1", {{"username", "drv_username"}, {"last_name", "drv_last_name"}, {"first_name", "drv_first_name"}, {"street_address", "drv_street_address"}, {"zip_code", "drv_zip_code"}, {"city", "drv_city"}, {"state", "drv_state"}, {"vin", "drv_vin"}, {"odometer_miles", "drv_odometer_miles"}, {"escrow_balance", "drv_escrow_balance"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"drv_odometer_miles", Int64.Type}, {"drv_escrow_balance", type number}}),
  #"Renamed columns 1" = Table.RenameColumns(#"Changed column type", {{"start_date", "drv_start_date"}, {"end_date", "drv_end_date"}}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Renamed columns 1", {{"drv_start_date", type date}, {"drv_end_date", type date}}),
  #"Renamed columns 2" = Table.RenameColumns(#"Changed column type 1", {{"status", "drv_status"}})
in
  #"Renamed columns 2";
shared flrk_driver_bronze_DataDestination = let
  Pattern = Fabric.Warehouse([HierarchicalNavigation = null, CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  TableNavigation = Navigation_2{[Schema = "silver", Item = "flrk_driver"]}[Data]
in
  TableNavigation;
