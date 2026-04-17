section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_INCR_ARFILE_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "ARRECC", DestinationColumnName = "ARRECC"], [SourceColumnName = "ARCUST", DestinationColumnName = "ARCUST"], [SourceColumnName = "ARINVN", DestinationColumnName = "ARINVN"], [SourceColumnName = "ARCUS#", DestinationColumnName = "ARCUS#"], [SourceColumnName = "ARTYPE", DestinationColumnName = "ARTYPE"], [SourceColumnName = "ARREC#", DestinationColumnName = "ARREC#"], [SourceColumnName = "ARINVD", DestinationColumnName = "ARINVD"], [SourceColumnName = "ARORD", DestinationColumnName = "ARORD"], [SourceColumnName = "ARDPDT", DestinationColumnName = "ARDPDT"], [SourceColumnName = "ARCORD", DestinationColumnName = "ARCORD"], [SourceColumnName = "ARBOMO", DestinationColumnName = "ARBOMO"], [SourceColumnName = "ARBOYR", DestinationColumnName = "ARBOYR"], [SourceColumnName = "ARAMT", DestinationColumnName = "ARAMT"], [SourceColumnName = "ARBFWD", DestinationColumnName = "ARBFWD"], [SourceColumnName = "ARFC", DestinationColumnName = "ARFC"], [SourceColumnName = "ARDPRO", DestinationColumnName = "ARDPRO"], [SourceColumnName = "ARWPRO", DestinationColumnName = "ARWPRO"], [SourceColumnName = "ARMPRO", DestinationColumnName = "ARMPRO"], [SourceColumnName = "ARNCUR", DestinationColumnName = "ARNCUR"], [SourceColumnName = "ARNAME", DestinationColumnName = "ARNAME"], [SourceColumnName = "ARSEQ", DestinationColumnName = "ARSEQ"], [SourceColumnName = "ARSTM#", DestinationColumnName = "ARSTM#"], [SourceColumnName = "ARDSPD", DestinationColumnName = "ARDSPD"], [SourceColumnName = "ARSTMF", DestinationColumnName = "ARSTMF"], [SourceColumnName = "ARGSTA", DestinationColumnName = "ARGSTA"], [SourceColumnName = "ARGLNO", DestinationColumnName = "ARGLNO"], [SourceColumnName = "recordNumber", DestinationColumnName = "recordNumber"], [SourceColumnName = "loadDate", DestinationColumnName = "loadDate"], [SourceColumnName = "refreshDate", DestinationColumnName = "refreshDate"], [SourceColumnName = "sourceSystem", DestinationColumnName = "sourceSystem"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_INCR_ARFILE = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation2" = #"Navigation 1"{[Name = "VW_INCR_ARFILE"]}[Data],
    AddRecordNumber = Table.AddIndexColumn(Navigation2, "recordNumber", 1, 1, Int64.Type),
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)

in
    AddSourceSystem;
shared VW_INCR_ARFILE_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_arfile_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
