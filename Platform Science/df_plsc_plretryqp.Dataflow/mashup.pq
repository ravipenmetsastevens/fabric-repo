[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLRETRYQP_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "PLQTYPE", DestinationColumnName = "PLQTYPE"], [SourceColumnName = "PLCRWJU", DestinationColumnName = "PLCRWJU"], [SourceColumnName = "PLCRWJD", DestinationColumnName = "PLCRWJD"], [SourceColumnName = "PLCRWJT", DestinationColumnName = "PLCRWJT"], [SourceColumnName = "PLCNWJI", DestinationColumnName = "PLCNWJI"], [SourceColumnName = "PLCMWJI", DestinationColumnName = "PLCMWJI"], [SourceColumnName = "PLCMWJR", DestinationColumnName = "PLCMWJR"], [SourceColumnName = "PLCRWPU", DestinationColumnName = "PLCRWPU"], [SourceColumnName = "PLCRWPD", DestinationColumnName = "PLCRWPD"], [SourceColumnName = "PLCRWPT", DestinationColumnName = "PLCRWPT"], [SourceColumnName = "PLCNWPO", DestinationColumnName = "PLCNWPO"], [SourceColumnName = "PLCNWPD", DestinationColumnName = "PLCNWPD"], [SourceColumnName = "PLCRFFU", DestinationColumnName = "PLCRFFU"], [SourceColumnName = "PLCRFFD", DestinationColumnName = "PLCRFFD"], [SourceColumnName = "PLCRFFT", DestinationColumnName = "PLCRFFT"], [SourceColumnName = "PLQSEND", DestinationColumnName = "PLQSEND"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLRETRYQP = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLRETRYQP"]}[Data],
  #"Trimmed text" = Table.TransformColumns(#"Navigation 2", {{"PLQTYPE", each Text.Trim(_), type text}, {"PLCRWJU", each Text.Trim(_), type text}, {"PLCRWJT", each Text.Trim(_), type text}, {"PLCNWJI", each Text.Trim(_), type text}, {"PLCMWJI", each Text.Trim(_), type text}, {"PLCMWJR", each Text.Trim(_), type text}, {"PLCRWPU", each Text.Trim(_), type text}, {"PLCRWPT", each Text.Trim(_), type text}, {"PLCNWPO", each Text.Trim(_), type text}, {"PLCNWPD", each Text.Trim(_), type text}, {"PLCRFFU", each Text.Trim(_), type text}, {"PLCRFFT", each Text.Trim(_), type text}}),
  #"Trimmed text 1" = Table.TransformColumns(#"Trimmed text", {{"PLQSEND", each Text.Trim(_), type text}})
in
  #"Trimmed text 1";
shared VW_PLSC_PLRETRYQP_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLRETRYQP", ItemKind = "Table"]}[Data]
in
  TableNavigation;
