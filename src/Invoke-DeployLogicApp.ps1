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