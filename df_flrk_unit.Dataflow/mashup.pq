section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "GetUnits API_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"GetUnits API" = let
  Source = Json.Document(Web.Contents("https://www.fleetrock.com/API/GetUnits?username=paragon&token=c70314d6-e0f4-44cc-810a-1f39476023ed")),
  Navigation = Source[units],
  #"Converted to table" = Table.FromList(Navigation, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
  #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to table", "Column1", {"vin", "group", "unit_number", "custom_id", "type", "year", "make", "model", "manufacturer", "odometer_miles", "engine_hours", "cost_center", "in_service_date", "tag", "status"}, {"vin", "group", "unit_number", "custom_id", "type", "year", "make", "model", "manufacturer", "odometer_miles", "engine_hours", "cost_center", "in_service_date", "tag", "status"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded Column1", {{"vin", type text}, {"group", type text}, {"unit_number", type text}}),
  #"Removed columns" = Table.RemoveColumns(#"Changed column type", {"custom_id"}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Removed columns", {{"type", type text}, {"year", Int64.Type}, {"make", type text}, {"model", type text}, {"manufacturer", type text}, {"odometer_miles", Int64.Type}, {"engine_hours", Int64.Type}}),
  #"Removed columns 1" = Table.RemoveColumns(#"Changed column type 1", {"cost_center"}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Removed columns 1", {{"in_service_date", type datetime}, {"tag", type text}, {"status", type text}})
in
  #"Changed column type 2";
shared #"GetUnits API_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "flrk_unit_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
