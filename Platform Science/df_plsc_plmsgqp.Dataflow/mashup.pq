[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLMSGQP_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "PLAPP", DestinationColumnName = "PLAPP"], [SourceColumnName = "PLRECTS", DestinationColumnName = "PLRECTS"], [SourceColumnName = "PLQUETS", DestinationColumnName = "PLQUETS"], [SourceColumnName = "PLMSGTYP", DestinationColumnName = "PLMSGTYP"], [SourceColumnName = "PLDRVCD1", DestinationColumnName = "PLDRVCD1"], [SourceColumnName = "PLDRVCD2", DestinationColumnName = "PLDRVCD2"], [SourceColumnName = "PLUNIT", DestinationColumnName = "PLUNIT"], [SourceColumnName = "PLORDER", DestinationColumnName = "PLORDER"], [SourceColumnName = "PLDISP", DestinationColumnName = "PLDISP"], [SourceColumnName = "PLPROC", DestinationColumnName = "PLPROC"], [SourceColumnName = "PLPAYLOD", DestinationColumnName = "PLPAYLOD"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLMSGQP = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLMSGQP"]}[Data],
  #"Trimmed text" = Table.TransformColumns(#"Navigation 2", {{"PLAPP", each Text.Trim(_), type nullable text}, {"PLMSGTYP", each Text.Trim(_), type nullable text}, {"PLDRVCD1", each Text.Trim(_), type nullable text}, {"PLDRVCD2", each Text.Trim(_), type nullable text}, {"PLUNIT", each Text.Trim(_), type nullable text}, {"PLORDER", each Text.Trim(_), type nullable text}, {"PLDISP", each Text.Trim(_), type nullable text}, {"PLPROC", each Text.Trim(_), type nullable text}, {"PLPAYLOD", each Text.Trim(_), type nullable text}})
in
  #"Trimmed text";
shared VW_PLSC_PLMSGQP_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLMSGQP", ItemKind = "Table"]}[Data]
in
  TableNavigation;
