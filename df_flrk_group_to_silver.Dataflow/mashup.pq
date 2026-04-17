section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "flrk_group_bronze_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "group_name", DestinationColumnName = "group_name"], [SourceColumnName = "group_label", DestinationColumnName = "group_label"], [SourceColumnName = "approval_over", DestinationColumnName = "approval_over"], [SourceColumnName = "approval_buffer", DestinationColumnName = "approval_buffer"], [SourceColumnName = "group_hierarchy", DestinationColumnName = "group_hierarchy"], [SourceColumnName = "group_parent", DestinationColumnName = "group_parent"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared flrk_group_bronze = let
  Source = Lakehouse.Contents(null){[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data]{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  #"Navigation 1" = Source{[Id = "flrk_group_bronze", ItemKind = "Table"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 1", {{"approval_over", type number}, {"approval_buffer", type number}})
in
  #"Changed column type";
shared flrk_group_bronze_DataDestination = let
  Pattern = Fabric.Warehouse([HierarchicalNavigation = null, CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  TableNavigation = Navigation_2{[Schema = "silver", Item = "flrk_group"]}[Data]
in
  TableNavigation;
