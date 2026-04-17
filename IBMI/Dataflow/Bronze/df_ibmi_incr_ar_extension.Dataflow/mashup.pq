[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_INCR_AR_EXTENSION_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared VW_INCR_AR_EXTENSION = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_INCR_AR_EXTENSION"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"ARREC#", "ARREC"}, {"ARSTM#", "ARSTM"}}),
  #"Changedcolumntype" = Table.TransformColumnTypes(#"Renamed columns", {{"ARENDT", Int64.Type}, {"ARENTI", Int64.Type}, {"ARCHDT", Int64.Type}, {"ARCHTI", Int64.Type}, {"ARDEDT", Int64.Type}, {"ARDETI", Int64.Type}}),
    AddRecordNumber = Table.AddIndexColumn(Changedcolumntype, "recordNumber", 1, 1, Int64.Type),
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)

in
    AddSourceSystem;
shared VW_INCR_AR_EXTENSION_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_ar_extension_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
