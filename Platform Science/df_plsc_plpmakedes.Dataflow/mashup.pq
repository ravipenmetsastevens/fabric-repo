[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLPMAKEDES_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "MAKENAME", DestinationColumnName = "MAKENAME"], [SourceColumnName = "MAKEDESC", DestinationColumnName = "MAKEDESC"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLPMAKEDES = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLPMAKEDES"]}[Data],
  #"Trimmed text" = Table.TransformColumns(#"Navigation 2", {{"MAKENAME", each Text.Trim(_), type text}}),
  #"Trimmed text 1" = Table.TransformColumns(#"Trimmed text", {{"MAKEDESC", each Text.Trim(_), type text}})
in
  #"Trimmed text 1";
shared VW_PLSC_PLPMAKEDES_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLPMAKEDES", ItemKind = "Table"]}[Data]
in
  TableNavigation;
