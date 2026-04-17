[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_EDI_STATUS_HISTORY_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared VW_EDI_STATUS_HISTORY = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_EDI_STATUS_HISTORY"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"EREDAT", Int64.Type}, {"ERETIM", Int64.Type}, {"ERSDAT", Int64.Type}, {"ERSTIM", Int64.Type}, {"ERTDAT", Int64.Type}, {"ERTTIM", Int64.Type}, {"ERADAT", Int64.Type}, {"ERATIM", Int64.Type}}),
  #"Renamed columns" = Table.RenameColumns(#"Changed column type", {{"ERORD#", "ERORD"}})
in
  #"Renamed columns";
shared VW_EDI_STATUS_HISTORY_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_edi_status_history_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
