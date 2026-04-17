section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "flrk_unit_bronze_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "unit_vin", DestinationColumnName = "unit_vin"], [SourceColumnName = "unit_group", DestinationColumnName = "unit_group"], [SourceColumnName = "unit_number", DestinationColumnName = "unit_number"], [SourceColumnName = "unit_custom_id", DestinationColumnName = "unit_custom_id"], [SourceColumnName = "unit_type", DestinationColumnName = "unit_type"], [SourceColumnName = "unit_year", DestinationColumnName = "unit_year"], [SourceColumnName = "unit_make", DestinationColumnName = "unit_make"], [SourceColumnName = "unit_model", DestinationColumnName = "unit_model"], [SourceColumnName = "unit_manufacturer", DestinationColumnName = "unit_manufacturer"], [SourceColumnName = "unit_odometer_miles", DestinationColumnName = "unit_odometer_miles"], [SourceColumnName = "unit_engine_hours", DestinationColumnName = "unit_engine_hours"], [SourceColumnName = "unit_cost_center", DestinationColumnName = "unit_cost_center"], [SourceColumnName = "unit_tag", DestinationColumnName = "unit_tag"], [SourceColumnName = "unit_status", DestinationColumnName = "unit_status"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared flrk_unit_bronze = let
  Source = Lakehouse.Contents(null){[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data]{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  #"Navigation 1" = Source{[Id = "flrk_unit_bronze", ItemKind = "Table"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"year", Int64.Type}, {"odometer_miles", Int64.Type}, {"engine_hours", Int64.Type}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"vin", "unit_vin"}, {"group", "unit_group"}, {"custom_id", "unit_custom_id"}, {"type", "unit_type"}, {"year", "unit_year"}, {"make", "unit_make"}, {"model", "unit_model"}, {"manufacturer", "unit_manufacturer"}, {"odometer_miles", "unit_odometer_miles"}, {"engine_hours", "unit_engine_hours"}, {"cost_center", "unit_cost_center"}, {"in_service_date", "unit_in_service_date"}, {"tag", "unit_tag"}, {"status", "unit_status"}})
in
  #"Renamed columns";
shared flrk_unit_bronze_DataDestination = let
  Pattern = Fabric.Warehouse([HierarchicalNavigation = null, CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  TableNavigation = Navigation_2{[Schema = "silver", Item = "flrk_unit"]}[Data]
in
  TableNavigation;
