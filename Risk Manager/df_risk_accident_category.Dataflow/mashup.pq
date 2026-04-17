[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Sheet1_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared Sheet1 = let
  Source = Excel.Workbook(Web.Contents("https://stevenstransport-my.sharepoint.com/personal/jeremy_shahan_stevenstransport_com/Documents/Apps/Microsoft Power Query/Uploaded Files/T_Accident_Categories.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"Column1", type text}, {"Column2", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"Column1", "accident_type_description"}, {"Column2", "accident_category"}}),
  #"Removed top rows" = Table.Skip(#"Renamed columns", 1)
in
  #"Removed top rows";
shared Sheet1_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "risk_accident_categories_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
