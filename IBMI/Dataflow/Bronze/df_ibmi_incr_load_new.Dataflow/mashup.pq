[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_INCR_LOAD_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "DIARA", DestinationColumnName = "DIARA"], [SourceColumnName = "DIODR", DestinationColumnName = "DIODR"], [SourceColumnName = "DIDISP", DestinationColumnName = "DIDISP"], [SourceColumnName = "DILDST", DestinationColumnName = "DILDST"], [SourceColumnName = "DIRCST", DestinationColumnName = "DIRCST"], [SourceColumnName = "DIDATE", DestinationColumnName = "DIDATE"], [SourceColumnName = "DITIME", DestinationColumnName = "DITIME"], [SourceColumnName = "DIUNIT", DestinationColumnName = "DIUNIT"], [SourceColumnName = "DITRLR", DestinationColumnName = "DITRLR"], [SourceColumnName = "DIDR1", DestinationColumnName = "DIDR1"], [SourceColumnName = "DIDR2", DestinationColumnName = "DIDR2"], [SourceColumnName = "DIROUT", DestinationColumnName = "DIROUT"], [SourceColumnName = "DIRTST", DestinationColumnName = "DIRTST"], [SourceColumnName = "DIEMIL", DestinationColumnName = "DIEMIL"], [SourceColumnName = "DITMIL", DestinationColumnName = "DITMIL"], [SourceColumnName = "DISMNF", DestinationColumnName = "DISMNF"], [SourceColumnName = "DIMTAF", DestinationColumnName = "DIMTAF"], [SourceColumnName = "DIMIFL", DestinationColumnName = "DIMIFL"], [SourceColumnName = "DIINIT", DestinationColumnName = "DIINIT"], [SourceColumnName = "DIAREA", DestinationColumnName = "DIAREA"], [SourceColumnName = "DITRIP", DestinationColumnName = "DITRIP"], [SourceColumnName = "DICONT", DestinationColumnName = "DICONT"], [SourceColumnName = "DIMULT", DestinationColumnName = "DIMULT"], [SourceColumnName = "DIPORD", DestinationColumnName = "DIPORD"], [SourceColumnName = "DIPDSP", DestinationColumnName = "DIPDSP"], [SourceColumnName = "DIETAD", DestinationColumnName = "DIETAD"], [SourceColumnName = "DIETAT", DestinationColumnName = "DIETAT"], [SourceColumnName = "DIMTRL", DestinationColumnName = "DIMTRL"], [SourceColumnName = "DISTST", DestinationColumnName = "DISTST"], [SourceColumnName = "DIAPRV", DestinationColumnName = "DIAPRV"], [SourceColumnName = "DIUFMG", DestinationColumnName = "DIUFMG"], [SourceColumnName = "DIUDMG", DestinationColumnName = "DIUDMG"], [SourceColumnName = "DIDFMG", DestinationColumnName = "DIDFMG"], [SourceColumnName = "DIDDMG", DestinationColumnName = "DIDDMG"], [SourceColumnName = "DITJR", DestinationColumnName = "DITJR"], [SourceColumnName = "DITJD", DestinationColumnName = "DITJD"], [SourceColumnName = "DIBHUB", DestinationColumnName = "DIBHUB"], [SourceColumnName = "DIEHUB", DestinationColumnName = "DIEHUB"], [SourceColumnName = "DIBODO", DestinationColumnName = "DIBODO"], [SourceColumnName = "DIEODO", DestinationColumnName = "DIEODO"], [SourceColumnName = "DIOWNR", DestinationColumnName = "DIOWNR"], [SourceColumnName = "DITRN2", DestinationColumnName = "DITRN2"], [SourceColumnName = "recordNumber", DestinationColumnName = "recordNumber"], [SourceColumnName = "loadDate", DestinationColumnName = "loadDate"], [SourceColumnName = "refreshDate", DestinationColumnName = "refreshDate"], [SourceColumnName = "sourceSystem", DestinationColumnName = "sourceSystem"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_INCR_LOAD = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_INCR_LOAD"]}[Data],
  #"Renamedcolumns" = Table.RenameColumns(#"Navigation 2", {{"DIODR#", "DIODR"}}),
    AddRecordNumber = Table.AddIndexColumn(Renamedcolumns, "recordNumber", 1, 1, Int64.Type),
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)

in
    AddSourceSystem;
shared NavigationQuery = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false])
in
  Source;
shared VW_INCR_LOAD_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_load_bronze_new", ItemKind = "Table"]}[Data]
in
  TableNavigation;
