[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLTPPORDP_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "PLPPORD", DestinationColumnName = "PLPPORD"], [SourceColumnName = "PLPPTYPE", DestinationColumnName = "PLPPTYPE"], [SourceColumnName = "PLPPUNIT", DestinationColumnName = "PLPPUNIT"], [SourceColumnName = "PLPPDRV1", DestinationColumnName = "PLPPDRV1"], [SourceColumnName = "PLPPDRV2", DestinationColumnName = "PLPPDRV2"], [SourceColumnName = "PLPPDATE", DestinationColumnName = "PLPPDATE"], [SourceColumnName = "PLPPTIME", DestinationColumnName = "PLPPTIME"], [SourceColumnName = "PLPPPROC", DestinationColumnName = "PLPPPROC"], [SourceColumnName = "PLPPRETY", DestinationColumnName = "PLPPRETY"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLTPPORDP = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLTPPORDP"]}[Data],
  #"Removed columns" = Table.RemoveColumns(#"Navigation 2", {"PLPPPRDATE"}),
  #"Trimmed text" = Table.TransformColumns(#"Removed columns", {{"PLPPORD", each Text.Trim(_), type text}, {"PLPPTYPE", each Text.Trim(_), type text}, {"PLPPUNIT", each Text.Trim(_), type text}, {"PLPPDRV1", each Text.Trim(_), type text}, {"PLPPDRV2", each Text.Trim(_), type text}, {"PLPPTIME", each Text.Trim(_), type text}, {"PLPPPROC", each Text.Trim(_), type text}})
in
  #"Trimmed text";
shared VW_PLSC_PLTPPORDP_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLTPPORDP", ItemKind = "Table"]}[Data]
in
  TableNavigation;
