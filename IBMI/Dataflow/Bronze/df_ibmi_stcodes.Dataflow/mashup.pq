[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_STCODES_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "STCODE", DestinationColumnName = "STCODE"], [SourceColumnName = "STDESC", DestinationColumnName = "STDESC"], [SourceColumnName = "STCRED", DestinationColumnName = "STCRED"], [SourceColumnName = "STDEBT", DestinationColumnName = "STDEBT"], [SourceColumnName = "STTYPE", DestinationColumnName = "STTYPE"], [SourceColumnName = "STDEDC", DestinationColumnName = "STDEDC"], [SourceColumnName = "STSTAT", DestinationColumnName = "STSTAT"], [SourceColumnName = "STCRDT", DestinationColumnName = "STCRDT"], [SourceColumnName = "STCRBY", DestinationColumnName = "STCRBY"], [SourceColumnName = "STCHDT", DestinationColumnName = "STCHDT"], [SourceColumnName = "STCHBY", DestinationColumnName = "STCHBY"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_STCODES = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_STCODES"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"STCRDT", Int64.Type}, {"STCHDT", Int64.Type}})
in
  #"Changed column type";
shared VW_STCODES_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_stcodes_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
