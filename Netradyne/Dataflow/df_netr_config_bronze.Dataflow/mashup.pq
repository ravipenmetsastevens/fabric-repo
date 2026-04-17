section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr alertType_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "typeId", DestinationColumnName = "configId"], [SourceColumnName = "typeDescription", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr alertType" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"alertTypes"}, {"alertTypes"}),
  #"Expanded alertTypes" = Table.ExpandListColumn(#"Expanded data.configuration", "alertTypes"),
  #"Expanded alertTypes 1" = Table.ExpandRecordColumn(#"Expanded alertTypes", "alertTypes", {"typeId", "typeDescription"}, {"typeId", "typeDescription"}),
  #"Added custom" = Table.AddColumn(#"Expanded alertTypes 1", "configType", each "alertTypes"),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom", {{"typeId", type text}, {"typeDescription", type text}, {"configType", type text}})
in
  #"Changed column type 1";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr alertSeverity_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "severity", DestinationColumnName = "configId"], [SourceColumnName = "severityDescription", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr alertSeverity" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"alertSeverityTypes"}, {"alertSeverityTypes"}),
  #"Expanded alertSeverityTypes" = Table.ExpandListColumn(#"Expanded data.configuration 1", "alertSeverityTypes"),
  #"Expanded alertSeverityTypes 1" = Table.ExpandRecordColumn(#"Expanded alertSeverityTypes", "alertSeverityTypes", {"severity", "severityDescription"}, {"severity", "severityDescription"}),
  #"Added custom" = Table.AddColumn(#"Expanded alertSeverityTypes 1", "configType", each "alertSeverityType"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"severity", type text}, {"severityDescription", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr alertCategory_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "category", DestinationColumnName = "configId"], [SourceColumnName = "categoryDescription", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr alertCategory" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"alertCategoryTypes"}, {"alertCategoryTypes"}),
  #"Expanded alertCategoryTypes" = Table.ExpandListColumn(#"Expanded data.configuration 1", "alertCategoryTypes"),
  #"Expanded alertCategoryTypes 1" = Table.ExpandRecordColumn(#"Expanded alertCategoryTypes", "alertCategoryTypes", {"category", "categoryDescription"}, {"category", "categoryDescription"}),
  #"Added custom" = Table.AddColumn(#"Expanded alertCategoryTypes 1", "configType", each "alertCategoryType"),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom", {{"configType", type text}, {"category", type text}, {"categoryDescription", type text}})
in
  #"Changed column type 1";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr alertCause_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "code", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr alertCause" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"alertCause"}, {"alertCause"}),
  #"Expanded alertCause" = Table.ExpandListColumn(#"Expanded data.configuration 1", "alertCause"),
  #"Expanded alertCause 1" = Table.ExpandRecordColumn(#"Expanded alertCause", "alertCause", {"code", "description"}, {"code", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded alertCause 1", "configType", each "alertCause"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"code", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr vehicleStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr vehicleStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"vehicleStatus"}, {"vehicleStatus"}),
  #"Expanded vehicleStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "vehicleStatus"),
  #"Expanded vehicleStatus 1" = Table.ExpandRecordColumn(#"Expanded vehicleStatus", "vehicleStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded vehicleStatus 1", "configType", each "vehicleStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr cameraConfigurations_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "position", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"], [SourceColumnName = "key", DestinationColumnName = "configMisc"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr cameraConfigurations" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"cameraConfigurations"}, {"cameraConfigurations"}),
  #"Expanded cameraConfigurations" = Table.ExpandListColumn(#"Expanded data.configuration 1", "cameraConfigurations"),
  #"Expanded cameraConfigurations 1" = Table.ExpandRecordColumn(#"Expanded cameraConfigurations", "cameraConfigurations", {"position", "description", "key"}, {"position", "description", "key"}),
  #"Added custom" = Table.AddColumn(#"Expanded cameraConfigurations 1", "configType", each "cameraConfigurations"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"position", type text}, {"description", type text}, {"key", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr videoStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr videoStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"videoStatus"}, {"videoStatus"}),
  #"Expanded videoStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "videoStatus"),
  #"Expanded videoStatus 1" = Table.ExpandRecordColumn(#"Expanded videoStatus", "videoStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded videoStatus 1", "configType", each "videoStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr requestStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr requestStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"requestStatus"}, {"requestStatus"}),
  #"Expanded requestStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "requestStatus"),
  #"Expanded requestStatus 1" = Table.ExpandRecordColumn(#"Expanded requestStatus", "requestStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded requestStatus 1", "configType", each "requestStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr userStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr userStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"userStatus"}, {"userStatus"}),
  #"Expanded userStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "userStatus"),
  #"Expanded userStatus 1" = Table.ExpandRecordColumn(#"Expanded userStatus", "userStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded userStatus 1", "configType", each "userStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr coachingSessionsStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr coachingSessionsStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"coachingSessionStatus"}, {"coachingSessionStatus"}),
  #"Expanded coachingSessionStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "coachingSessionStatus"),
  #"Expanded coachingSessionStatus 1" = Table.ExpandRecordColumn(#"Expanded coachingSessionStatus", "coachingSessionStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded coachingSessionStatus 1", "configType", each "coachingSessionStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr canStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr canStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"canStatus"}, {"canStatus"}),
  #"Expanded canStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "canStatus"),
  #"Expanded canStatus 1" = Table.ExpandRecordColumn(#"Expanded canStatus", "canStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded canStatus 1", "configType", each "canStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr masterDisconnectedStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr masterDisconnectedStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"masterDisconnectedStatus"}, {"masterDisconnectedStatus"}),
  #"Expanded masterDisconnectedStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "masterDisconnectedStatus"),
  #"Expanded masterDisconnectedStatus 1" = Table.ExpandRecordColumn(#"Expanded masterDisconnectedStatus", "masterDisconnectedStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded masterDisconnectedStatus 1", "configType", each "masterDisconnectedStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr batteryConnectedStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr batteryConnectedStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"batteryConnectedStatus"}, {"batteryConnectedStatus"}),
  #"Expanded batteryConnectedStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "batteryConnectedStatus"),
  #"Expanded batteryConnectedStatus 1" = Table.ExpandRecordColumn(#"Expanded batteryConnectedStatus", "batteryConnectedStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded batteryConnectedStatus 1", "configType", each "batteryConnectedStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr batterySource_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr batterySource" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"batterySource"}, {"batterySource"}),
  #"Expanded batterySource" = Table.ExpandListColumn(#"Expanded data.configuration 1", "batterySource"),
  #"Expanded batterySource 1" = Table.ExpandRecordColumn(#"Expanded batterySource", "batterySource", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded batterySource 1", "configType", each "batterySource"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr rolesDetail_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "roleId", DestinationColumnName = "configId"], [SourceColumnName = "roleDescription", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr rolesDetail" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"rolesDetail"}, {"rolesDetail"}),
  #"Expanded rolesDetail" = Table.ExpandListColumn(#"Expanded data.configuration 1", "rolesDetail"),
  #"Expanded rolesDetail 1" = Table.ExpandRecordColumn(#"Expanded rolesDetail", "rolesDetail", {"roleId", "roleDescription"}, {"roleId", "roleDescription"}),
  #"Added custom" = Table.AddColumn(#"Expanded rolesDetail 1", "configType", each "rolesDetail"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"roleId", type text}, {"roleDescription", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr driverStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr driverStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"driverStatus"}, {"driverStatus"}),
  #"Expanded driverStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "driverStatus"),
  #"Expanded driverStatus 1" = Table.ExpandRecordColumn(#"Expanded driverStatus", "driverStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded driverStatus 1", "configType", each "driverStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr alertStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr alertStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"alertStatus"}, {"alertStatus"}),
  #"Expanded alertStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "alertStatus"),
  #"Expanded alertStatus 1" = Table.ExpandRecordColumn(#"Expanded alertStatus", "alertStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded alertStatus 1", "configType", each "alertStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr deviceStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr deviceStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"deviceStatus"}, {"deviceStatus"}),
  #"Expanded deviceStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "deviceStatus"),
  #"Expanded deviceStatus 1" = Table.ExpandRecordColumn(#"Expanded deviceStatus", "deviceStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded deviceStatus 1", "configType", each "deviceStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr inCabAudioAlertTypes_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "type", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr inCabAudioAlertTypes" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"inCabAudioAlertTypes"}, {"inCabAudioAlertTypes"}),
  #"Expanded inCabAudioAlertTypes" = Table.ExpandListColumn(#"Expanded data.configuration 1", "inCabAudioAlertTypes"),
  #"Expanded inCabAudioAlertTypes 1" = Table.ExpandRecordColumn(#"Expanded inCabAudioAlertTypes", "inCabAudioAlertTypes", {"type", "description"}, {"type", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded inCabAudioAlertTypes 1", "configType", each "inCabAudioAlertTypes"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"type", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr alertSubTypes_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "id", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr alertSubTypes" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"alertSubTypes"}, {"alertSubTypes"}),
  #"Expanded alertSubTypes" = Table.ExpandListColumn(#"Expanded data.configuration 1", "alertSubTypes"),
  #"Expanded alertSubTypes 1" = Table.ExpandRecordColumn(#"Expanded alertSubTypes", "alertSubTypes", {"id", "description"}, {"id", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded alertSubTypes 1", "configType", each "alertSubTypes"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"id", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr coachingCompletionReason_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "key", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr coachingCompletionReason" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"coachingCompletionReason"}, {"coachingCompletionReason"}),
  #"Expanded coachingCompletionReason" = Table.ExpandListColumn(#"Expanded data.configuration 1", "coachingCompletionReason"),
  #"Expanded coachingCompletionReason 1" = Table.ExpandRecordColumn(#"Expanded coachingCompletionReason", "coachingCompletionReason", {"key", "description"}, {"key", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded coachingCompletionReason 1", "configType", each "coachingCompletionReason"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"key", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr deviceHealthStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr deviceHealthStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"deviceHealthStatus"}, {"deviceHealthStatus"}),
  #"Expanded deviceHealthStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "deviceHealthStatus"),
  #"Expanded deviceHealthStatus 1" = Table.ExpandRecordColumn(#"Expanded deviceHealthStatus", "deviceHealthStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded deviceHealthStatus 1", "configType", each "deviceHealthStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr fnoInclusionTypes_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr fnoInclusionTypes" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"fnolInclusionTypes"}, {"fnolInclusionTypes"}),
  #"Expanded fnolInclusionTypes" = Table.ExpandListColumn(#"Expanded data.configuration 1", "fnolInclusionTypes"),
  #"Expanded fnolInclusionTypes 1" = Table.ExpandRecordColumn(#"Expanded fnolInclusionTypes", "fnolInclusionTypes", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded fnolInclusionTypes 1", "configType", each "fnoInclusionTypes"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr vehicleHealthStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "status", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr vehicleHealthStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"vehicleHealthStatus"}, {"vehicleHealthStatus"}),
  #"Expanded vehicleHealthStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "vehicleHealthStatus"),
  #"Expanded vehicleHealthStatus 1" = Table.ExpandRecordColumn(#"Expanded vehicleHealthStatus", "vehicleHealthStatus", {"status", "description"}, {"status", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded vehicleHealthStatus 1", "configType", each "vehicleHealthStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"status", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr feedbackType_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "value", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr feedbackType" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"feedbackType"}, {"feedbackType"}),
  #"Expanded feedbackType" = Table.ExpandListColumn(#"Expanded data.configuration 1", "feedbackType"),
  #"Expanded feedbackType 1" = Table.ExpandRecordColumn(#"Expanded feedbackType", "feedbackType", {"value", "description"}, {"value", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded feedbackType 1", "configType", each "feedbackType"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"value", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr feedbackReason_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "value", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr feedbackReason" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"feedbackReason"}, {"feedbackReason"}),
  #"Expanded feedbackReason" = Table.ExpandListColumn(#"Expanded data.configuration 1", "feedbackReason"),
  #"Expanded feedbackReason 1" = Table.ExpandRecordColumn(#"Expanded feedbackReason", "feedbackReason", {"value", "description"}, {"value", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded feedbackReason 1", "configType", each "feedbackReason"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"value", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr feedbackStatus_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "value", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr feedbackStatus" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"feedbackStatus"}, {"feedbackStatus"}),
  #"Expanded feedbackStatus" = Table.ExpandListColumn(#"Expanded data.configuration 1", "feedbackStatus"),
  #"Expanded feedbackStatus 1" = Table.ExpandRecordColumn(#"Expanded feedbackStatus", "feedbackStatus", {"value", "description"}, {"value", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded feedbackStatus 1", "configType", each "feedbackStatus"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"configType", type text}, {"description", type text}, {"value", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "netr alertStopSignSubSeverity_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "configType", DestinationColumnName = "configType"], [SourceColumnName = "value", DestinationColumnName = "configId"], [SourceColumnName = "description", DestinationColumnName = "configDescription"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"netr alertStopSignSubSeverity" = let
  Source = AzureStorage.Blobs("https://fabricstoragescus.blob.core.windows.net/"),
  #"Navigation 1" = Source{[Name = "netradyne"]}[Data],
  Navigation = #"Navigation 1"{[#"Folder Path" = "https://fabricstoragescus.blob.core.windows.net/netradyne/", Name = "netradyne_config.json"]}[Content],
  #"Imported JSON" = Json.Document(Navigation, 65001),
  #"Converted to table" = Table.FromRecords({#"Imported JSON"}),
  #"Expanded data" = Table.ExpandRecordColumn(#"Converted to table", "data", {"configuration"}, {"data.configuration"}),
  #"Expanded data.configuration 1" = Table.ExpandRecordColumn(#"Expanded data", "data.configuration", {"alertStopSignSubSeverity"}, {"alertStopSignSubSeverity"}),
  #"Expanded alertStopSignSubSeverity" = Table.ExpandListColumn(#"Expanded data.configuration 1", "alertStopSignSubSeverity"),
  #"Expanded alertStopSignSubSeverity 1" = Table.ExpandRecordColumn(#"Expanded alertStopSignSubSeverity", "alertStopSignSubSeverity", {"value", "description"}, {"value", "description"}),
  #"Added custom" = Table.AddColumn(#"Expanded alertStopSignSubSeverity 1", "configType", each "alertStopSignSubSeverity"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"value", type text}, {"description", type text}, {"configType", type text}})
in
  #"Changed column type";
shared #"netr alertType_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr alertSeverity_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr alertCategory_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr alertCause_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr vehicleStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr cameraConfigurations_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr videoStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr requestStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr userStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr coachingSessionsStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr canStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr masterDisconnectedStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr batteryConnectedStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr batterySource_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr rolesDetail_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr driverStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr alertStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr deviceStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr inCabAudioAlertTypes_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr alertSubTypes_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr coachingCompletionReason_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr deviceHealthStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr fnoInclusionTypes_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr vehicleHealthStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr feedbackType_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr feedbackReason_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr feedbackStatus_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
shared #"netr alertStopSignSubSeverity_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "netr_config_v2_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
