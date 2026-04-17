[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_INCR_STOPOFF_OG_APPT_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "S2ORD", DestinationColumnName = "S2ORD"], [SourceColumnName = "S2STP", DestinationColumnName = "S2STP"], [SourceColumnName = "S2ADT1", DestinationColumnName = "S2ADT1"], [SourceColumnName = "S2ADT2", DestinationColumnName = "S2ADT2"], [SourceColumnName = "S2ATM1", DestinationColumnName = "S2ATM1"], [SourceColumnName = "S2ATM2", DestinationColumnName = "S2ATM2"], [SourceColumnName = "recordNumber", DestinationColumnName = "recordNumber"], [SourceColumnName = "loadDate", DestinationColumnName = "loadDate"], [SourceColumnName = "refreshDate", DestinationColumnName = "refreshDate"], [SourceColumnName = "sourceSystem", DestinationColumnName = "sourceSystem"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_INCR_STOPOFF_OG_APPT = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_INCR_STOPOFF_OG_APPT"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"S2STP#", "S2STP"}}),
  #"Changedcolumntype" = Table.TransformColumnTypes(#"Renamed columns", {{"S2ADT1", Int64.Type}, {"S2ADT2", Int64.Type}}),
    AddRecordNumber = Table.AddIndexColumn(Changedcolumntype, "recordNumber", 1, 1, Int64.Type),
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)

in
    AddSourceSystem;
shared VW_INCR_STOPOFF_OG_APPT_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_stopoff_og_appt_bronze2", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
