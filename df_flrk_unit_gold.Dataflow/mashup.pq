section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "silver flrk_unit_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "unit_vin", DestinationColumnName = "unit_vin"], [SourceColumnName = "unit_group", DestinationColumnName = "unit_group"], [SourceColumnName = "unit_number", DestinationColumnName = "unit_number"], [SourceColumnName = "unit_custom_id", DestinationColumnName = "unit_custom_id"], [SourceColumnName = "unit_type", DestinationColumnName = "unit_type"], [SourceColumnName = "unit_year", DestinationColumnName = "unit_year"], [SourceColumnName = "unit_make", DestinationColumnName = "unit_make"], [SourceColumnName = "unit_model", DestinationColumnName = "unit_model"], [SourceColumnName = "unit_manufacturer", DestinationColumnName = "unit_manufacturer"], [SourceColumnName = "unit_odometer_miles", DestinationColumnName = "unit_odometer_miles"], [SourceColumnName = "unit_engine_hours", DestinationColumnName = "unit_engine_hours"], [SourceColumnName = "unit_in_service_date", DestinationColumnName = "unit_in_service_date"], [SourceColumnName = "unit_tag", DestinationColumnName = "unit_tag"], [SourceColumnName = "unit_status", DestinationColumnName = "unit_status"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared #"silver flrk_unit" = let
  Source = Fabric.Warehouse(null){[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data]{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  #"Navigation 1" = Source{[Schema = "silver", Item = "flrk_unit"]}[Data],
  #"Removed columns" = Table.RemoveColumns(#"Navigation 1", {"unit_cost_center"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Removed columns", {{"unit_in_service_date", type date}})
in
  #"Changed column type";
shared #"silver flrk_unit_DataDestination" = let
  Pattern = Fabric.Warehouse([HierarchicalNavigation = null, CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  TableNavigation = Navigation_2{[Schema = "gold", Item = "dim_maint_unit"]}[Data]
in
  TableNavigation;
