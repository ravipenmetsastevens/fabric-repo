section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "silver flrk_supplier_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "supplier_name", DestinationColumnName = "supplier_name"], [SourceColumnName = "supplier_custom_id", DestinationColumnName = "supplier_custom_id"], [SourceColumnName = "supplier_street_address_1", DestinationColumnName = "supplier_street_address_1"], [SourceColumnName = "supplier_street_address_2", DestinationColumnName = "supplier_street_address_2"], [SourceColumnName = "supplier_city", DestinationColumnName = "supplier_city"], [SourceColumnName = "supplier_state", DestinationColumnName = "supplier_state"], [SourceColumnName = "supplier_zip_code", DestinationColumnName = "supplier_zip_code"], [SourceColumnName = "supplier_country", DestinationColumnName = "supplier_country"], [SourceColumnName = "supplier_phone", DestinationColumnName = "supplier_phone"], [SourceColumnName = "supplier_email", DestinationColumnName = "supplier_email"], [SourceColumnName = "payment_term_days", DestinationColumnName = "payment_term_days"], [SourceColumnName = "supplier_notes", DestinationColumnName = "supplier_notes"], [SourceColumnName = "supplier_latitude", DestinationColumnName = "supplier_latitude"], [SourceColumnName = "supplier_longitude", DestinationColumnName = "supplier_longitude"], [SourceColumnName = "supplier_added_datetime", DestinationColumnName = "supplier_added_datetime"], [SourceColumnName = "supplier_added_date", DestinationColumnName = "supplier_added_date"], [SourceColumnName = "supplier_type", DestinationColumnName = "supplier_type"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared #"silver flrk_supplier" = let
  Source = Fabric.Warehouse(null){[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data]{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  #"Navigation 1" = Source{[Schema = "silver", Item = "flrk_supplier"]}[Data],
  #"Replaced value" = Table.ReplaceValue(#"Navigation 1", "", null, Replacer.ReplaceValue, {"supplier_custom_id"}),
  #"Replaced value 1" = Table.ReplaceValue(#"Replaced value", "", null, Replacer.ReplaceValue, {"supplier_street_address_1"}),
  #"Replaced value 2" = Table.ReplaceValue(#"Replaced value 1", "", null, Replacer.ReplaceValue, {"supplier_street_address_2"}),
  #"Replaced value 3" = Table.ReplaceValue(#"Replaced value 2", "", null, Replacer.ReplaceValue, {"supplier_city"}),
  #"Replaced value 4" = Table.ReplaceValue(#"Replaced value 3", "", null, Replacer.ReplaceValue, {"supplier_state"}),
  #"Replaced value 5" = Table.ReplaceValue(#"Replaced value 4", "", null, Replacer.ReplaceValue, {"supplier_zip_code", "supplier_phone", "payment_term_days", "supplier_notes"}),
  #"Inserted date" = Table.AddColumn(#"Replaced value 5", "Date", each DateTime.Date([supplier_added_datetime]), type nullable date),
  #"Renamed columns" = Table.RenameColumns(#"Inserted date", {{"Date", "supplier_added_date"}}),
  #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"supplier_name", "supplier_custom_id", "supplier_street_address_1", "supplier_street_address_2", "supplier_city", "supplier_state", "supplier_zip_code", "supplier_country", "supplier_phone", "supplier_email", "payment_term_days", "supplier_notes", "supplier_added_datetime", "supplier_added_date", "supplier_type"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Reordered columns", "supplier_latitude", each 12.4444444), {{"supplier_latitude", type number}}),
  #"Added custom 1" = Table.AddColumn(#"Added custom", "supplier_longitude", each -12.5555555),
  #"Reordered columns 1" = Table.ReorderColumns(#"Added custom 1", {"supplier_name", "supplier_custom_id", "supplier_street_address_1", "supplier_street_address_2", "supplier_city", "supplier_state", "supplier_zip_code", "supplier_country", "supplier_phone", "supplier_email", "payment_term_days", "supplier_notes", "supplier_latitude", "supplier_longitude", "supplier_added_datetime", "supplier_added_date", "supplier_type"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Reordered columns 1", {{"supplier_longitude", type number}})
in
  #"Changed column type";
shared #"silver flrk_supplier_DataDestination" = let
  Pattern = Fabric.Warehouse([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  TableNavigation = Navigation_2{[Item = "flrk_dim_supplier", Schema = "dbo"]}?[Data]?
in
  TableNavigation;
