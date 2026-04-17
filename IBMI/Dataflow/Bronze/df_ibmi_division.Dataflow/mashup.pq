section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_DIVISION_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "DIVCDE", DestinationColumnName = "DIVCDE"], [SourceColumnName = "DIVSTT", DestinationColumnName = "DIVSTT"], [SourceColumnName = "DIVNME", DestinationColumnName = "DIVNME"], [SourceColumnName = "DIVFC", DestinationColumnName = "DIVFC"], [SourceColumnName = "DIVFLE", DestinationColumnName = "DIVFLE"], [SourceColumnName = "DIVWRK", DestinationColumnName = "DIVWRK"], [SourceColumnName = "DIVSAV", DestinationColumnName = "DIVSAV"], [SourceColumnName = "DIVCO", DestinationColumnName = "DIVCO"], [SourceColumnName = "DIVCOU", DestinationColumnName = "DIVCOU"], [SourceColumnName = "DIVMET", DestinationColumnName = "DIVMET"], [SourceColumnName = "DIVAMT", DestinationColumnName = "DIVAMT"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_DIVISION = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_DIVISION"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"DIVCO#", "DIVCO"}})
in
  #"Renamed columns";
shared VW_DIVISION_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_division_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
