[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_INCR_DRIVER_HOME_HISTORY_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared VW_INCR_DRIVER_HOME_HISTORY = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation2" = #"Navigation 1"{[Name = "VW_DRIVER_HOME_HISTORY"]}[Data],
    AddRecordNumber = Table.AddIndexColumn(Navigation2, "recordNumber", 1, 1, Int64.Type),
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)

in
    AddSourceSystem;
shared VW_INCR_DRIVER_HOME_HISTORY_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_driver_home_history_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
