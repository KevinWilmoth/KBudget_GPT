################################################################################
# Deployment Validation Module
# 
# Purpose: Provides validation and verification functions for Azure deployments
# Features:
#   - Resource existence validation
#   - Deployment status checking
#   - Resource health verification
#   - Output collection and reporting
#   - Automated alerts for failures
#
################################################################################

################################################################################
# Deployment Status Functions
################################################################################

function Get-DeploymentStatus {
    <#
    .SYNOPSIS
        Gets the status of an Azure deployment
    
    .PARAMETER ResourceGroupName
        Name of the resource group
    
    .PARAMETER DeploymentName
        Name of the deployment
    
    .PARAMETER IsSubscriptionDeployment
        Indicates if this is a subscription-level deployment
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$DeploymentName,
        
        [Parameter(Mandatory = $false)]
        [switch]$IsSubscriptionDeployment
    )
    
    try {
        if ($IsSubscriptionDeployment) {
            $deployment = Get-AzSubscriptionDeployment -Name $DeploymentName -ErrorAction SilentlyContinue
        }
        else {
            $deployment = Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $DeploymentName -ErrorAction SilentlyContinue
        }
        
        if (-not $deployment) {
            return [PSCustomObject]@{
                Status = "NotFound"
                ProvisioningState = "NotFound"
                Timestamp = Get-Date
                Duration = $null
                Error = "Deployment not found"
            }
        }
        
        $duration = $null
        if ($deployment.Timestamp -and $deployment.LastModified) {
            $duration = ($deployment.LastModified - $deployment.Timestamp).TotalMinutes
        }
        
        return [PSCustomObject]@{
            Status = $deployment.ProvisioningState
            ProvisioningState = $deployment.ProvisioningState
            Timestamp = $deployment.Timestamp
            Duration = [math]::Round($duration, 2)
            Error = if ($deployment.ProvisioningState -eq "Failed") { $deployment.StatusMessage } else { $null }
            Outputs = $deployment.Outputs
        }
    }
    catch {
        return [PSCustomObject]@{
            Status = "Error"
            ProvisioningState = "Error"
            Timestamp = Get-Date
            Duration = $null
            Error = $_.Exception.Message
        }
    }
}

################################################################################
# Resource Validation Functions
################################################################################

function Test-ResourceGroupExists {
    <#
    .SYNOPSIS
        Validates that a resource group exists
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        return [PSCustomObject]@{
            Exists = $null -ne $rg
            ResourceGroupName = $ResourceGroupName
            Location = if ($rg) { $rg.Location } else { $null }
            ProvisioningState = if ($rg) { $rg.ProvisioningState } else { "NotFound" }
            ResourceId = if ($rg) { $rg.ResourceId } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            ResourceGroupName = $ResourceGroupName
            Location = $null
            ProvisioningState = "Error"
            Error = $_.Exception.Message
        }
    }
}

function Test-VirtualNetworkExists {
    <#
    .SYNOPSIS
        Validates that a virtual network exists and is properly configured
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$VNetName
    )
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            Exists = $null -ne $vnet
            VNetName = $VNetName
            ResourceId = if ($vnet) { $vnet.Id } else { $null }
            Location = if ($vnet) { $vnet.Location } else { $null }
            AddressSpace = if ($vnet) { $vnet.AddressSpace.AddressPrefixes -join ", " } else { $null }
            SubnetCount = if ($vnet) { $vnet.Subnets.Count } else { 0 }
            ProvisioningState = if ($vnet) { $vnet.ProvisioningState } else { "NotFound" }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            VNetName = $VNetName
            Error = $_.Exception.Message
        }
    }
}

function Test-KeyVaultExists {
    <#
    .SYNOPSIS
        Validates that a Key Vault exists and is accessible
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName
    )
    
    try {
        $kv = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            Exists = $null -ne $kv
            KeyVaultName = $KeyVaultName
            ResourceId = if ($kv) { $kv.ResourceId } else { $null }
            Location = if ($kv) { $kv.Location } else { $null }
            VaultUri = if ($kv) { $kv.VaultUri } else { $null }
            EnabledForDeployment = if ($kv) { $kv.EnabledForDeployment } else { $false }
            EnabledForTemplateDeployment = if ($kv) { $kv.EnabledForTemplateDeployment } else { $false }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            KeyVaultName = $KeyVaultName
            Error = $_.Exception.Message
        }
    }
}

function Test-StorageAccountExists {
    <#
    .SYNOPSIS
        Validates that a storage account exists and is accessible
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$StorageAccountName
    )
    
    try {
        $storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            Exists = $null -ne $storage
            StorageAccountName = $StorageAccountName
            ResourceId = if ($storage) { $storage.Id } else { $null }
            Location = if ($storage) { $storage.Location } else { $null }
            SkuName = if ($storage) { $storage.Sku.Name } else { $null }
            PrimaryEndpoints = if ($storage) { $storage.PrimaryEndpoints.Blob } else { $null }
            ProvisioningState = if ($storage) { $storage.ProvisioningState } else { "NotFound" }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            StorageAccountName = $StorageAccountName
            Error = $_.Exception.Message
        }
    }
}

function Test-CosmosAccountExists {
    <#
    .SYNOPSIS
        Validates that a Cosmos DB Account exists and is accessible
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$AccountName
    )
    
    try {
        $cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroupName -Name $AccountName -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            Exists = $null -ne $cosmosAccount
            AccountName = $AccountName
            ResourceId = if ($cosmosAccount) { $cosmosAccount.Id } else { $null }
            Location = if ($cosmosAccount) { $cosmosAccount.Location } else { $null }
            DocumentEndpoint = if ($cosmosAccount) { $cosmosAccount.DocumentEndpoint } else { $null }
            ProvisioningState = if ($cosmosAccount) { $cosmosAccount.ProvisioningState } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            AccountName = $AccountName
            Error = $_.Exception.Message
        }
    }
}

function Test-AppServiceExists {
    <#
    .SYNOPSIS
        Validates that an App Service exists and is running
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppServiceName
    )
    
    try {
        $app = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            Exists = $null -ne $app
            AppServiceName = $AppServiceName
            ResourceId = if ($app) { $app.Id } else { $null }
            Location = if ($app) { $app.Location } else { $null }
            DefaultHostName = if ($app) { $app.DefaultHostName } else { $null }
            State = if ($app) { $app.State } else { "NotFound" }
            HttpsOnly = if ($app) { $app.HttpsOnly } else { $false }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            AppServiceName = $AppServiceName
            Error = $_.Exception.Message
        }
    }
}

function Test-FunctionAppExists {
    <#
    .SYNOPSIS
        Validates that a Function App exists and is running
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$FunctionAppName
    )
    
    try {
        $func = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppName -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            Exists = $null -ne $func
            FunctionAppName = $FunctionAppName
            ResourceId = if ($func) { $func.Id } else { $null }
            Location = if ($func) { $func.Location } else { $null }
            DefaultHostName = if ($func) { $func.DefaultHostName } else { $null }
            State = if ($func) { $func.State } else { "NotFound" }
        }
    }
    catch {
        return [PSCustomObject]@{
            Exists = $false
            FunctionAppName = $FunctionAppName
            Error = $_.Exception.Message
        }
    }
}

################################################################################
# Comprehensive Validation Functions
################################################################################

function Test-DeploymentResources {
    <#
    .SYNOPSIS
        Validates all deployed resources for a given environment
    
    .PARAMETER Environment
        Environment name (dev, staging, prod)
    
    .PARAMETER ResourceTypes
        Array of resource types to validate
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "staging", "prod")]
        [string]$Environment,
        
        [Parameter(Mandatory = $false)]
        [string[]]$ResourceTypes = @("all")
    )
    
    $ResourceGroupName = "kbudget-$Environment-rg"
    $results = @{
        Environment = $Environment
        ResourceGroupName = $ResourceGroupName
        ValidationTime = Get-Date
        Resources = @{}
        OverallStatus = "Unknown"
    }
    
    # Check resource group first
    $rgStatus = Test-ResourceGroupExists -ResourceGroupName $ResourceGroupName
    $results.Resources["ResourceGroup"] = $rgStatus
    
    if (-not $rgStatus.Exists) {
        $results.OverallStatus = "Failed"
        return $results
    }
    
    $deployAll = $ResourceTypes -contains "all"
    $allPassed = $true
    
    # Validate VNet
    if ($deployAll -or $ResourceTypes -contains "vnet") {
        $vnetName = "kbudget-$Environment-vnet"
        $vnetStatus = Test-VirtualNetworkExists -ResourceGroupName $ResourceGroupName -VNetName $vnetName
        $results.Resources["VNet"] = $vnetStatus
        if (-not $vnetStatus.Exists) { $allPassed = $false }
    }
    
    # Validate Key Vault
    if ($deployAll -or $ResourceTypes -contains "keyvault") {
        $kvName = "kbudget-$Environment-kv"
        $kvStatus = Test-KeyVaultExists -ResourceGroupName $ResourceGroupName -KeyVaultName $kvName
        $results.Resources["KeyVault"] = $kvStatus
        if (-not $kvStatus.Exists) { $allPassed = $false }
    }
    
    # Validate Storage Account
    if ($deployAll -or $ResourceTypes -contains "storage") {
        $storageName = "kbudget${Environment}storage"
        $storageStatus = Test-StorageAccountExists -ResourceGroupName $ResourceGroupName -StorageAccountName $storageName
        $results.Resources["Storage"] = $storageStatus
        if (-not $storageStatus.Exists) { $allPassed = $false }
    }
    
    # Validate Cosmos DB Account
    if ($deployAll -or $ResourceTypes -contains "cosmos") {
        $cosmosAccountName = "kbudget-$Environment-cosmos"
        $cosmosStatus = Test-CosmosAccountExists -ResourceGroupName $ResourceGroupName -AccountName $cosmosAccountName
        $results.Resources["CosmosAccount"] = $cosmosStatus
        if (-not $cosmosStatus.Exists) { $allPassed = $false }
    }
    
    # Validate App Service
    if ($deployAll -or $ResourceTypes -contains "appservice") {
        $appName = "kbudget-$Environment-app"
        $appStatus = Test-AppServiceExists -ResourceGroupName $ResourceGroupName -AppServiceName $appName
        $results.Resources["AppService"] = $appStatus
        if (-not $appStatus.Exists) { $allPassed = $false }
    }
    
    # Validate Function App
    if ($deployAll -or $ResourceTypes -contains "functions") {
        $funcName = "kbudget-$Environment-func"
        $funcStatus = Test-FunctionAppExists -ResourceGroupName $ResourceGroupName -FunctionAppName $funcName
        $results.Resources["Functions"] = $funcStatus
        if (-not $funcStatus.Exists) { $allPassed = $false }
    }
    
    $results.OverallStatus = if ($allPassed) { "Success" } else { "Failed" }
    
    return $results
}

################################################################################
# Output and Reporting Functions
################################################################################

function Export-DeploymentOutputs {
    <#
    .SYNOPSIS
        Exports deployment outputs to a JSON file
    
    .PARAMETER Deployment
        The deployment object containing outputs
    
    .PARAMETER OutputPath
        Path to save the output file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Deployment,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        $outputs = @{}
        
        if ($Deployment.Outputs) {
            foreach ($key in $Deployment.Outputs.Keys) {
                $outputs[$key] = $Deployment.Outputs[$key].Value
            }
        }
        
        $outputObject = @{
            DeploymentName = $Deployment.DeploymentName
            ProvisioningState = $Deployment.ProvisioningState
            Timestamp = $Deployment.Timestamp
            Outputs = $outputs
        }
        
        $outputObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
        
        return [PSCustomObject]@{
            Success = $true
            OutputPath = $OutputPath
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Write-DeploymentSummary {
    <#
    .SYNOPSIS
        Writes a comprehensive deployment summary
    
    .PARAMETER ValidationResults
        Results from Test-DeploymentResources
    
    .PARAMETER LogFile
        Path to log file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$ValidationResults,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    
    $summary = @"

================================================================================
DEPLOYMENT VALIDATION SUMMARY
================================================================================
Environment:        $($ValidationResults.Environment)
Resource Group:     $($ValidationResults.ResourceGroupName)
Validation Time:    $($ValidationResults.ValidationTime.ToString('yyyy-MM-dd HH:mm:ss'))
Overall Status:     $($ValidationResults.OverallStatus)

RESOURCE STATUS:
--------------------------------------------------------------------------------
"@
    
    foreach ($resourceType in $ValidationResults.Resources.Keys) {
        $resource = $ValidationResults.Resources[$resourceType]
        $status = if ($resource.Exists) { "DEPLOYED" } else { "MISSING" }
        $summary += "`n$resourceType`: $status"
        
        if ($resource.ResourceId) {
            $summary += "`n  Resource ID: $($resource.ResourceId)"
        }
        
        if ($resource.Error) {
            $summary += "`n  Error: $($resource.Error)"
        }
    }
    
    $summary += "`n`n================================================================================`n"
    
    # Write to console
    Write-Host $summary
    
    # Write to log file if provided
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $summary
    }
    
    return $summary
}

function Send-DeploymentAlert {
    <#
    .SYNOPSIS
        Sends an alert for deployment failures (extensible for email/webhooks)
    
    .PARAMETER ValidationResults
        Results from Test-DeploymentResources
    
    .PARAMETER AlertLevel
        Level of alert (Info, Warning, Critical)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$ValidationResults,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Critical")]
        [string]$AlertLevel = "Warning"
    )
    
    $alertMessage = @{
        Timestamp = Get-Date
        Environment = $ValidationResults.Environment
        Status = $ValidationResults.OverallStatus
        AlertLevel = $AlertLevel
        FailedResources = @()
    }
    
    foreach ($resourceType in $ValidationResults.Resources.Keys) {
        $resource = $ValidationResults.Resources[$resourceType]
        if (-not $resource.Exists) {
            $alertMessage.FailedResources += @{
                ResourceType = $resourceType
                Error = $resource.Error
            }
        }
    }
    
    # Log the alert (can be extended to send emails, webhooks, etc.)
    Write-Warning "DEPLOYMENT ALERT: $($ValidationResults.OverallStatus) - Environment: $($ValidationResults.Environment)"
    
    if ($alertMessage.FailedResources.Count -gt 0) {
        Write-Warning "Failed Resources:"
        foreach ($failed in $alertMessage.FailedResources) {
            Write-Warning "  - $($failed.ResourceType): $($failed.Error)"
        }
    }
    
    return $alertMessage
}

################################################################################
# Export Module Members
################################################################################

Export-ModuleMember -Function @(
    'Get-DeploymentStatus',
    'Test-ResourceGroupExists',
    'Test-VirtualNetworkExists',
    'Test-KeyVaultExists',
    'Test-StorageAccountExists',
    'Test-CosmosAccountExists',
    'Test-AppServiceExists',
    'Test-FunctionAppExists',
    'Test-DeploymentResources',
    'Export-DeploymentOutputs',
    'Write-DeploymentSummary',
    'Send-DeploymentAlert'
)
