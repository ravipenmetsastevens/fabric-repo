section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_GLCHART_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "GCDELC", DestinationColumnName = "GCDELC"], [SourceColumnName = "GCACCT", DestinationColumnName = "GCACCT"], [SourceColumnName = "GCLEV", DestinationColumnName = "GCLEV"], [SourceColumnName = "GCDESC", DestinationColumnName = "GCDESC"], [SourceColumnName = "GCCONS", DestinationColumnName = "GCCONS"], [SourceColumnName = "GCPRT", DestinationColumnName = "GCPRT"], [SourceColumnName = "GCTYPE", DestinationColumnName = "GCTYPE"], [SourceColumnName = "GCAVCD", DestinationColumnName = "GCAVCD"], [SourceColumnName = "GCAVAL", DestinationColumnName = "GCAVAL"], [SourceColumnName = "GCAVPE", DestinationColumnName = "GCAVPE"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_GLCHART = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_GLCHART"]}[Data]
in
  #"Navigation 2";
shared VW_GLCHART_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_gl_account_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
