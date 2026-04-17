[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_EDI_ORDER_HISTORY_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared VW_EDI_ORDER_HISTORY = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_INCR_EDI_ORDER_HISTORY"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"EOODR#", "EOODR"}, {"EOCSH#", "EOCSH"}, {"EOCNS#", "EOCNS"}, {"EOMAN#", "EOMAN"}, {"EOCO#", "EOCO"}, {"EODV#", "EODV"}, {"EOTM#", "EOTM"}}),
  #"Changedcolumntype" = Table.TransformColumnTypes(#"Renamed columns", {{"EODATE", Int64.Type}, {"EOPDAT", Int64.Type}, {"EODDAT", Int64.Type}, {"EOAPDT", Int64.Type}, {"EOADDT", Int64.Type}, {"EOSHDT", Int64.Type}, {"EOTNDT", Int64.Type}}),
    AddRecordNumber = Table.AddIndexColumn(Changedcolumntype, "recordNumber", 1, 1, Int64.Type),
    // Add Load Date (timestamp of dataflow run)
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    // Add Refresh Date (just the date part)
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    // Add Source System (static or parametrize later)
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)
in
    AddSourceSystem;
shared VW_EDI_ORDER_HISTORY_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_edi_order_history_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
