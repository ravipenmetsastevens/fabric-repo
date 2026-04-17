[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_INCR_BILLING_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "BIODR", DestinationColumnName = "BIODR"], [SourceColumnName = "BISEQ", DestinationColumnName = "BISEQ"], [SourceColumnName = "BICNT", DestinationColumnName = "BICNT"], [SourceColumnName = "BIDLT", DestinationColumnName = "BIDLT"], [SourceColumnName = "BICOMM", DestinationColumnName = "BICOMM"], [SourceColumnName = "BIDESC", DestinationColumnName = "BIDESC"], [SourceColumnName = "BIPIEC", DestinationColumnName = "BIPIEC"], [SourceColumnName = "BIAQTY", DestinationColumnName = "BIAQTY"], [SourceColumnName = "BIBQTY", DestinationColumnName = "BIBQTY"], [SourceColumnName = "BIRATE", DestinationColumnName = "BIRATE"], [SourceColumnName = "BIAMT", DestinationColumnName = "BIAMT"], [SourceColumnName = "BIMETH", DestinationColumnName = "BIMETH"], [SourceColumnName = "BIERR", DestinationColumnName = "BIERR"], [SourceColumnName = "BIACCT", DestinationColumnName = "BIACCT"], [SourceColumnName = "BICC", DestinationColumnName = "BICC"], [SourceColumnName = "BIGSTC", DestinationColumnName = "BIGSTC"], [SourceColumnName = "BIGSTA", DestinationColumnName = "BIGSTA"], [SourceColumnName = "recordNumber", DestinationColumnName = "recordNumber"], [SourceColumnName = "loadDate", DestinationColumnName = "loadDate"], [SourceColumnName = "refreshDate", DestinationColumnName = "refreshDate"], [SourceColumnName = "sourceSystem", DestinationColumnName = "sourceSystem"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_INCR_BILLING = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation2" = #"Navigation 1"{[Name = "VW_INCR_BILLING"]}[Data],
    AddRecordNumber = Table.AddIndexColumn(Navigation2, "recordNumber", 1, 1, Int64.Type),
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)

in
    AddSourceSystem;
shared VW_INCR_BILLING_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_billing_bronze_new", ItemKind = "Table"]}[Data]
in
  TableNavigation;
