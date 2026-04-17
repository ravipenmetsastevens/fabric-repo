[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_SERVICE_EXCEPTIONS_LA_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "LAORD", DestinationColumnName = "LAORD"], [SourceColumnName = "LASEQ", DestinationColumnName = "LASEQ"], [SourceColumnName = "LASTP", DestinationColumnName = "LASTP"], [SourceColumnName = "LAADT2", DestinationColumnName = "LAADT2"], [SourceColumnName = "LAATM2", DestinationColumnName = "LAATM2"], [SourceColumnName = "LAARDT", DestinationColumnName = "LAARDT"], [SourceColumnName = "LAARTM", DestinationColumnName = "LAARTM"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_SERVICE_EXCEPTIONS_LA = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_SERVICE_EXCEPTIONS_LA"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"LAORD#", "LAORD"}, {"LASEQ#", "LASEQ"}, {"LASTP#", "LASTP"}})
in
  #"Renamed columns";
shared VW_SERVICE_EXCEPTIONS_LA_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_service_exceptions_la_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
