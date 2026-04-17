section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_COMODITY_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "COMCDE", DestinationColumnName = "COMCDE"], [SourceColumnName = "COMDIV", DestinationColumnName = "COMDIV"], [SourceColumnName = "COMDEL", DestinationColumnName = "COMDEL"], [SourceColumnName = "COMDES", DestinationColumnName = "COMDES"], [SourceColumnName = "COMCLS", DestinationColumnName = "COMCLS"], [SourceColumnName = "COMACC", DestinationColumnName = "COMACC"], [SourceColumnName = "COSHDS", DestinationColumnName = "COSHDS"], [SourceColumnName = "COMTDC", DestinationColumnName = "COMTDC"], [SourceColumnName = "COMSTC", DestinationColumnName = "COMSTC"], [SourceColumnName = "COMNMF", DestinationColumnName = "COMNMF"], [SourceColumnName = "CORTYP", DestinationColumnName = "CORTYP"], [SourceColumnName = "COMWGT", DestinationColumnName = "COMWGT"], [SourceColumnName = "COMHGT", DestinationColumnName = "COMHGT"], [SourceColumnName = "COMLGT", DestinationColumnName = "COMLGT"], [SourceColumnName = "COMWDT", DestinationColumnName = "COMWDT"], [SourceColumnName = "COGSTC", DestinationColumnName = "COGSTC"], [SourceColumnName = "COOSTP", DestinationColumnName = "COOSTP"], [SourceColumnName = "COPRTP", DestinationColumnName = "COPRTP"], [SourceColumnName = "COOSGL", DestinationColumnName = "COOSGL"], [SourceColumnName = "COOSPC", DestinationColumnName = "COOSPC"], [SourceColumnName = "COPRPC", DestinationColumnName = "COPRPC"], [SourceColumnName = "COOFC", DestinationColumnName = "COOFC"], [SourceColumnName = "COTEMP", DestinationColumnName = "COTEMP"], [SourceColumnName = "COUNIT", DestinationColumnName = "COUNIT"], [SourceColumnName = "COWASH", DestinationColumnName = "COWASH"], [SourceColumnName = "COGRAV", DestinationColumnName = "COGRAV"], [SourceColumnName = "COPLAC", DestinationColumnName = "COPLAC"], [SourceColumnName = "COHZFL", DestinationColumnName = "COHZFL"], [SourceColumnName = "COHZCD", DestinationColumnName = "COHZCD"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_COMODITY = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_COMODITY"]}[Data]
in
  #"Navigation 2";
shared VW_COMODITY_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_commodity_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
