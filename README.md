# Azure Files Premium Auto Resize
This is a Logic App on Azure that resizes all file shares in Storage Accounts keeping a pre-define buffer (50 GB by default).

For Azure File Premium this allows granularly adding capacity or reducing allocated quota when data is deleted reducing the over all cost of storage.

The main use case for this solution is AVD FSLogix user profiles stored on Azure Files Premium. If you are also using [FSLogix VHD Disk Compaction](https://learn.microsoft.com/en-us/fslogix/concepts-vhd-disk-compaction) feature there is a better chance of downsizing your file shares.

The activity should run daily, running it more than once per day may result in errors as reducing quota is only supported once every 24 hours.

## Deploy
Utilize the Bicep file on this repo to deploy the Logic App. Below PowerShell example can be used,
```PowerShell
$SubscriptionId = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
$null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop

$deployParams = @{
    ResourceGroupName       = 'rg-example-01'
    Name                    = 'StorageAccountResizeLogicApp'
    TemplateFile            = '.\src\Bicep\DeployLogicApp.bicep'
    ###
    TemplateParameterObject = @{
        LogicAppName      = 'logic-example-dev-we-01'
        TargetFreeSpaceGB = 50
        StorageAccountIds = @('ResourceId of Storage Account 1', 'ResourceId of Storage Account 2') # The system assigned identity of the Logic App must have the Contributor role on the Storage Accounts.
    }
}

New-AzResourceGroupDeployment @deployParams
```

> **Note** The system assigned identity of the Logic App must have the Contributor role on the Storage Accounts.

## Parameters
A parameter with no default value means it is required.
| Parameter         | Required | Description                                                                                       | Default Value          |
| ----------------- | -------- | ------------------------------------------------------------------------------------------------- | ---------------------- |
| LogicAppName      | Yes      | The name of the Logic App.                                                                        |                        |
| StorageAccountIds | Yes      | The resource Id of the storage accounts to resize. All FileShares in these accounts are targeted. |                        |
| Location          | No       | The region where resources are stored                                                             | Same as resource group |
| TriggerTime       | No       | The time of day to trigger the logic app.                                                         | 0 = midnight           |
| TriggerTimeZone   | No       | The time zone of the trigger time.                                                                | GMT Standard Time      |
| TargetFreeSpaceGB | No       | The target free space (buffer) in GB.                                                             | 50 GB                  |
