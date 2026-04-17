[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLTAOORDP_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "PLAOORD", DestinationColumnName = "PLAOORD"], [SourceColumnName = "PLAOMTYPE", DestinationColumnName = "PLAOMTYPE"], [SourceColumnName = "PLAOUNIT", DestinationColumnName = "PLAOUNIT"], [SourceColumnName = "PLAODATE", DestinationColumnName = "PLAODATE"], [SourceColumnName = "PLAOTIME", DestinationColumnName = "PLAOTIME"], [SourceColumnName = "PLAOPRDATE", DestinationColumnName = "PLAOPRDATE"], [SourceColumnName = "PLAOPROC", DestinationColumnName = "PLAOPROC"], [SourceColumnName = "PLAORETY", DestinationColumnName = "PLAORETY"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLTAOORDP = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLTAOORDP"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"PLAOPRDATE", type text}}),
  #"Trimmed text" = Table.TransformColumns(#"Changed column type", {{"PLAOORD", each Text.Trim(_), type text}, {"PLAOMTYPE", each Text.Trim(_), type text}, {"PLAOUNIT", each Text.Trim(_), type text}, {"PLAOTIME", each Text.Trim(_), type text}, {"PLAOPRDATE", each Text.Trim(_), type nullable text}, {"PLAOPROC", each Text.Trim(_), type text}})
in
  #"Trimmed text";
shared VW_PLSC_PLTAOORDP_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLTAOORDP", ItemKind = "Table"]}[Data]
in
  TableNavigation;
