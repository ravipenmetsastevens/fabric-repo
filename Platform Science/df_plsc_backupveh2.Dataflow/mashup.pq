[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_BACKUPVEH_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "PHVEH", DestinationColumnName = "PHVEH"], [SourceColumnName = "PHTIME", DestinationColumnName = "PHTIME"], [SourceColumnName = "PHTIME_DT", DestinationColumnName = "PHTIME_DT"], [SourceColumnName = "PHARRV", DestinationColumnName = "PHARRV"], [SourceColumnName = "PHARRV_DT", DestinationColumnName = "PHARRV_DT"], [SourceColumnName = "PHTYPE", DestinationColumnName = "PHTYPE"], [SourceColumnName = "PHPSRC", DestinationColumnName = "PHPSRC"], [SourceColumnName = "PHSIOT", DestinationColumnName = "PHSIOT"], [SourceColumnName = "PHIGST", DestinationColumnName = "PHIGST"], [SourceColumnName = "PHMACT", DestinationColumnName = "PHMACT"], [SourceColumnName = "PHMAC", DestinationColumnName = "PHMAC"], [SourceColumnName = "PHVER", DestinationColumnName = "PHVER"], [SourceColumnName = "PHGMH", DestinationColumnName = "PHGMH"], [SourceColumnName = "PHBTIN", DestinationColumnName = "PHBTIN"], [SourceColumnName = "PHNXST", DestinationColumnName = "PHNXST"], [SourceColumnName = "PHNXSA", DestinationColumnName = "PHNXSA"], [SourceColumnName = "PHLSST", DestinationColumnName = "PHLSST"], [SourceColumnName = "PHLSSA", DestinationColumnName = "PHLSSA"], [SourceColumnName = "PHLAT", DestinationColumnName = "PHLAT"], [SourceColumnName = "PHLON", DestinationColumnName = "PHLON"], [SourceColumnName = "PHLTDD", DestinationColumnName = "PHLTDD"], [SourceColumnName = "PHDIRC", DestinationColumnName = "PHDIRC"], [SourceColumnName = "PHSPED", DestinationColumnName = "PHSPED"], [SourceColumnName = "PHODOM", DestinationColumnName = "PHODOM"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_BACKUPVEH = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_BACKUPVEH"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"PHMAC#", "PHMAC"}, {"PHVER#", "PHVER"}}),
  #"Trimmed text" = Table.TransformColumns(#"Renamed columns", {{"PHTYPE", each Text.Trim(_), type text}, {"PHPSRC", each Text.Trim(_), type text}, {"PHSIOT", each Text.Trim(_), type text}, {"PHIGST", each Text.Trim(_), type text}, {"PHMACT", each Text.Trim(_), type text}, {"PHBTIN", each Text.Trim(_), type text}})
in
  #"Trimmed text";
shared VW_PLSC_BACKUPVEH_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_BACKUPVEH", ItemKind = "Table"]}[Data]
in
  TableNavigation;
