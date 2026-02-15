################################################################################
# Azure Resources Deployment Script
# 
# Purpose: Deploy all Azure resources for KBudget GPT application
# Features:
#   - Deploys resource groups, VNet, Key Vault, Storage, Cosmos DB, App Service, Functions
#   - Deploys monitoring: Log Analytics, Diagnostic Settings, Alerts
#   - Supports dev, staging, and production environments
#   - Idempotent deployments (safe to run multiple times)
#   - Detailed logging and error handling
#   - Secure key handling via Key Vault
#   - Output resource IDs and connection strings
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Proper permissions (Contributor or Owner)
#
# Usage:
#   .\Deploy-AzureResources.ps1 -Environment dev
#   .\Deploy-AzureResources.ps1 -Environment staging
#   .\Deploy-AzureResources.ps1 -Environment prod
#   .\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("vnet", "storage")
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [ValidateSet("eastus", "westus", "westus2", "centralus", "northeurope", "westeurope")]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [ValidateSet("all", "vnet", "keyvault", "storage", "cosmos", "cosmos-containers", "appservice", "functions", "appgateway", "monitoring")]
    [string[]]$ResourceTypes = @("all"),

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$SkipResourceGroup
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "deployment_$($Environment)_$Timestamp.log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Environment mappings
$EnvMap = @{
    "dev"     = "Development"
    "staging" = "Staging"
    "prod"    = "Production"
}

$EnvName = $EnvMap[$Environment]

# Resource naming
$ResourceGroupName = "kbudget-$Environment-rg"

################################################################################
# Logging Functions
################################################################################

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Level] $TimeStamp - $Message"
    
    # Color coding for console output
    switch ($Level) {
        "INFO"    { Write-Host $LogMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage
}

################################################################################
# Validation Functions
################################################################################

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    # Check for Az PowerShell module
    if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Log "Azure PowerShell module (Az) is not installed" "ERROR"
        Write-Log "Install with: Install-Module -Name Az -AllowClobber -Scope CurrentUser" "ERROR"
        throw "Missing Azure PowerShell module"
    }
    
    # Check Azure authentication
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not authenticated to Azure" "ERROR"
            Write-Log "Run: Connect-AzAccount" "ERROR"
            throw "Not authenticated to Azure"
        }
        Write-Log "Authenticated as: $($context.Account.Id)" "SUCCESS"
        Write-Log "Subscription: $($context.Subscription.Name)" "INFO"
    }
    catch {
        Write-Log "Failed to get Azure context: $_" "ERROR"
        throw
    }
}

################################################################################
# Deployment Functions
################################################################################

function Deploy-ResourceGroup {
    Write-Log "Deploying Resource Group: $ResourceGroupName" "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\resource-groups\resource-group.json"
    $parametersPath = Join-Path $ScriptDir "..\resource-groups\parameters.$Environment.json"
    
    if (-not (Test-Path $templatePath)) {
        Write-Log "Template not found: $templatePath" "ERROR"
        throw "Template file not found"
    }
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy resource group $ResourceGroupName" "INFO"
            return
        }
        
        $deployment = New-AzSubscriptionDeployment `
            -Name "rg-deployment-$Environment-$Timestamp" `
            -Location $Location `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "Resource Group deployed successfully" "SUCCESS"
        Write-Log "Resource Group ID: $($deployment.Outputs.resourceGroupId.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Resource Group: $_" "ERROR"
        throw
    }
}

function Deploy-VirtualNetwork {
    Write-Log "Deploying Virtual Network..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\virtual-network\virtual-network.json"
    $parametersPath = Join-Path $ScriptDir "..\virtual-network\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Virtual Network" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "vnet-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "Virtual Network deployed successfully" "SUCCESS"
        Write-Log "VNet ID: $($deployment.Outputs.vnetId.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Virtual Network: $_" "ERROR"
        throw
    }
}

function Deploy-KeyVault {
    param(
        [string]$ObjectId
    )
    
    Write-Log "Deploying Key Vault..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\key-vault\key-vault.json"
    $parametersPath = Join-Path $ScriptDir "..\key-vault\parameters.$Environment.json"
    
    # Get current user's object ID if not provided
    if (-not $ObjectId) {
        $context = Get-AzContext
        $ObjectId = (Get-AzADUser -UserPrincipalName $context.Account.Id).Id
        if (-not $ObjectId) {
            # Try getting service principal if user lookup fails
            $ObjectId = (Get-AzADServicePrincipal -ApplicationId $context.Account.Id).Id
        }
    }
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Key Vault" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "kv-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -objectId $ObjectId `
            -Verbose
        
        Write-Log "Key Vault deployed successfully" "SUCCESS"
        Write-Log "Key Vault URI: $($deployment.Outputs.keyVaultUri.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Key Vault: $_" "ERROR"
        throw
    }
}

function Deploy-StorageAccount {
    Write-Log "Deploying Storage Account..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\storage-account\storage-account.json"
    $parametersPath = Join-Path $ScriptDir "..\storage-account\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Storage Account" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "storage-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "Storage Account deployed successfully" "SUCCESS"
        Write-Log "Storage Account: $($deployment.Outputs.storageAccountName.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Storage Account: $_" "ERROR"
        throw
    }
}

function Deploy-CosmosDatabase {
    Write-Log "Deploying Cosmos Database..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\cosmos-database\cosmos-database.json"
    $parametersPath = Join-Path $ScriptDir "..\cosmos-database\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Cosmos Database" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "cosmos-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "Cosmos Database deployed successfully" "SUCCESS"
        Write-Log "Cosmos DB Endpoint: $($deployment.Outputs.cosmosAccountEndpoint.Value)" "INFO"
        
        # Store Cosmos DB primary key in Key Vault
        $primaryKey = $deployment.Outputs.primaryMasterKey.Value
        $secureKey = ConvertTo-SecureString -String $primaryKey -AsPlainText -Force
        
        # Get Key Vault name from environment
        $kvName = "kbudget-$Environment-kv"
        Set-AzKeyVaultSecret -VaultName $kvName -Name "CosmosDbPrimaryKey" -SecretValue $secureKey | Out-Null
        Write-Log "Cosmos DB primary key stored in Key Vault" "SUCCESS"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Cosmos Database: $_" "ERROR"
        throw
    }
}

function Test-CosmosContainerPrerequisites {
    param(
        [string]$ResourceGroupName,
        [string]$CosmosAccountName,
        [string]$DatabaseName
    )
    
    Write-Log "Validating Cosmos DB prerequisites..." "INFO"
    
    # Check if Cosmos DB account exists
    $cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroupName -Name $CosmosAccountName -ErrorAction SilentlyContinue
    if (-not $cosmosAccount) {
        throw "Cosmos DB account '$CosmosAccountName' not found in resource group '$ResourceGroupName'"
    }
    
    # Check if database exists
    $database = Get-AzCosmosDBSqlDatabase -ResourceGroupName $ResourceGroupName -AccountName $CosmosAccountName -Name $DatabaseName -ErrorAction SilentlyContinue
    if (-not $database) {
        throw "Cosmos DB database '$DatabaseName' not found in account '$CosmosAccountName'"
    }
    
    Write-Log "✓ Cosmos DB prerequisites validated" "SUCCESS"
    return $true
}

function Deploy-CosmosContainers {
    Write-Log "Deploying Cosmos DB containers..." "INFO"
    
    $cosmosDbPath = Join-Path $ScriptDir "..\cosmos-database"
    $containers = @("users", "budgets", "envelopes", "transactions")
    $containerDeployments = @{}
    
    # Get Cosmos DB account and database names from environment
    $cosmosAccountName = "kbudget-$Environment-cosmos"
    $cosmosDatabaseName = "kbudget-$Environment-db"
    
    # Validate prerequisites
    try {
        Test-CosmosContainerPrerequisites -ResourceGroupName $ResourceGroupName -CosmosAccountName $cosmosAccountName -DatabaseName $cosmosDatabaseName
    }
    catch {
        Write-Log "Cosmos DB prerequisites check failed: $_" "ERROR"
        Write-Log "Please deploy Cosmos DB account and database first using -ResourceTypes @('cosmos')" "WARNING"
        throw
    }
    
    foreach ($container in $containers) {
        $containerTemplatePath = Join-Path $cosmosDbPath "$container-container.json"
        $containerParamsPath = Join-Path $cosmosDbPath "$container-container.parameters.$Environment.json"
        
        if (Test-Path $containerTemplatePath) {
            Write-Log "  Deploying $container container..." "INFO"
            
            try {
                if ($WhatIf) {
                    Write-Log "  WhatIf: Would deploy $container container" "INFO"
                    continue
                }
                
                $containerDeployment = New-AzResourceGroupDeployment `
                    -Name "$container-container-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                    -ResourceGroupName $ResourceGroupName `
                    -TemplateFile $containerTemplatePath `
                    -TemplateParameterFile $containerParamsPath `
                    -ErrorAction Stop
                
                Write-Log "  ✓ $container container deployed successfully" "SUCCESS"
                $containerDeployments[$container] = $containerDeployment
            }
            catch {
                # Check for specific errors
                if ($_.Exception.Message -like "*already exists*") {
                    Write-Log "  Container '$container' already exists. Skipping..." "WARNING"
                    continue
                }
                elseif ($_.Exception.Message -like "*quota exceeded*") {
                    Write-Log "  Cosmos DB quota exceeded. Check account limits." "ERROR"
                    throw
                }
                else {
                    Write-Log "  Failed to deploy $container container: $_" "ERROR"
                    throw
                }
            }
        }
        else {
            Write-Log "  Template not found: $containerTemplatePath" "WARNING"
        }
    }
    
    Write-Log "Cosmos DB containers deployment completed" "SUCCESS"
    return $containerDeployments
}

function Test-CosmosContainers {
    param(
        [string]$ResourceGroupName,
        [string]$CosmosAccountName,
        [string]$DatabaseName,
        [string[]]$ExpectedContainers
    )
    
    Write-Log "Validating Cosmos DB containers..." "INFO"
    
    $allValid = $true
    
    foreach ($containerName in $ExpectedContainers) {
        $container = Get-AzCosmosDBSqlContainer `
            -ResourceGroupName $ResourceGroupName `
            -AccountName $CosmosAccountName `
            -DatabaseName $DatabaseName `
            -Name $containerName `
            -ErrorAction SilentlyContinue
        
        if ($container) {
            Write-Log "  ✓ Container '$containerName' exists" "SUCCESS"
            
            # Validate partition key
            $partitionKey = $container.Resource.PartitionKey.Paths[0]
            
            # Validate partition key based on container name (using optimized strategy from Subtask 13)
            $expectedPartitionKey = switch ($containerName) {
                "users" { "/id" }
                "budgets" { "/id" }
                "envelopes" { "/budgetId" }
                "transactions" { "/budgetId" }
                default { "/userId" }  # fallback for any other containers
            }
            
            if ($partitionKey -eq $expectedPartitionKey) {
                Write-Log "    ✓ Partition key: $partitionKey" "INFO"
            }
            else {
                Write-Log "    Unexpected partition key: $partitionKey (expected $expectedPartitionKey)" "WARNING"
                $allValid = $false
            }
        }
        else {
            Write-Log "  ✗ Container '$containerName' not found" "WARNING"
            $allValid = $false
        }
    }
    
    if ($allValid) {
        Write-Log "✓ All Cosmos DB containers validated successfully" "SUCCESS"
    }
    else {
        Write-Log "Some container validations failed" "WARNING"
    }
    
    return $allValid
}

function Deploy-AppService {
    Write-Log "Deploying App Service..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\app-service\app-service.json"
    $parametersPath = Join-Path $ScriptDir "..\app-service\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy App Service" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "app-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "App Service deployed successfully" "SUCCESS"
        Write-Log "App Service URL: https://$($deployment.Outputs.appServiceDefaultHostName.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy App Service: $_" "ERROR"
        throw
    }
}

function Deploy-AzureFunctions {
    Write-Log "Deploying Azure Functions..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\azure-functions\azure-functions.json"
    $parametersPath = Join-Path $ScriptDir "..\azure-functions\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Azure Functions" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "func-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "Azure Functions deployed successfully" "SUCCESS"
        Write-Log "Function App URL: https://$($deployment.Outputs.functionAppDefaultHostName.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Azure Functions: $_" "ERROR"
        throw
    }
}

function Deploy-ApplicationGateway {
    Write-Log "Deploying Application Gateway with WAF..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\application-gateway\application-gateway.json"
    $parametersPath = Join-Path $ScriptDir "..\application-gateway\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Application Gateway with WAF" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "appgw-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "Application Gateway with WAF deployed successfully" "SUCCESS"
        Write-Log "Public IP: $($deployment.Outputs.publicIpAddress.Value)" "INFO"
        Write-Log "Public FQDN: $($deployment.Outputs.publicIpFqdn.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Application Gateway: $_" "ERROR"
        throw
    }
}

function Deploy-LogAnalytics {
    Write-Log "Deploying Log Analytics Workspace..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\log-analytics\log-analytics.json"
    $parametersPath = Join-Path $ScriptDir "..\log-analytics\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Log Analytics Workspace" "INFO"
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "law-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $parametersPath `
            -Verbose
        
        Write-Log "Log Analytics Workspace deployed successfully" "SUCCESS"
        Write-Log "Workspace ID: $($deployment.Outputs.workspaceId.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Log Analytics Workspace: $_" "ERROR"
        throw
    }
}

function Deploy-DiagnosticSettings {
    param(
        [hashtable]$Deployments
    )
    
    Write-Log "Deploying Diagnostic Settings..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\diagnostic-settings\diagnostic-settings.json"
    $parametersPath = Join-Path $ScriptDir "..\diagnostic-settings\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Diagnostic Settings" "INFO"
            return
        }
        
        # Read parameter file and update with actual resource IDs
        $subscriptionId = (Get-AzContext).Subscription.Id
        $paramContent = Get-Content $parametersPath -Raw | ConvertFrom-Json
        
        # Update workspace ID if Log Analytics was deployed
        if ($Deployments.ContainsKey("LogAnalytics")) {
            $workspaceId = $Deployments["LogAnalytics"].Outputs.workspaceId.Value
            $paramContent.parameters.workspaceId.value = $workspaceId
        }
        
        # Update resource IDs with actual subscription ID
        foreach ($param in $paramContent.parameters.PSObject.Properties) {
            if ($param.Value -is [PSCustomObject] -and $param.Value.value -match '\{subscription-id\}') {
                $param.Value.value = $param.Value.value -replace '\{subscription-id\}', $subscriptionId
            }
        }
        
        $tempParamFile = Join-Path $env:TEMP "diag-params-$Timestamp.json"
        $paramContent | ConvertTo-Json -Depth 10 | Set-Content $tempParamFile
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "diag-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $tempParamFile `
            -Verbose
        
        Remove-Item $tempParamFile -Force
        
        Write-Log "Diagnostic Settings deployed successfully" "SUCCESS"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Diagnostic Settings: $_" "ERROR"
        throw
    }
}

function Deploy-MonitoringAlerts {
    param(
        [hashtable]$Deployments
    )
    
    Write-Log "Deploying Monitoring Alerts..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\monitoring-alerts\monitoring-alerts.json"
    $parametersPath = Join-Path $ScriptDir "..\monitoring-alerts\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy Monitoring Alerts" "INFO"
            return
        }
        
        # Read parameter file and update with actual resource IDs
        $subscriptionId = (Get-AzContext).Subscription.Id
        $paramContent = Get-Content $parametersPath -Raw | ConvertFrom-Json
        
        # Update resource IDs with actual subscription ID
        foreach ($param in $paramContent.parameters.PSObject.Properties) {
            if ($param.Value -is [PSCustomObject] -and $param.Value.value -match '\{subscription-id\}') {
                $param.Value.value = $param.Value.value -replace '\{subscription-id\}', $subscriptionId
            }
        }
        
        $tempParamFile = Join-Path $env:TEMP "alerts-params-$Timestamp.json"
        $paramContent | ConvertTo-Json -Depth 10 | Set-Content $tempParamFile
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "alerts-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $tempParamFile `
            -Verbose
        
        Remove-Item $tempParamFile -Force
        
        Write-Log "Monitoring Alerts deployed successfully" "SUCCESS"
        Write-Log "Action Group: $($deployment.Outputs.actionGroupName.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Monitoring Alerts: $_" "ERROR"
        throw
    }
}

################################################################################
# Post-Deployment Validation Functions
################################################################################

function Invoke-PostDeploymentValidation {
    param(
        [hashtable]$Deployments,
        [string]$Environment,
        [string[]]$ResourceTypes
    )
    
    Write-Log "=== Post-Deployment Validation ===" "INFO"
    
    # Import validation module
    $validationModule = Join-Path $ScriptDir "Deployment-Validation.psm1"
    if (Test-Path $validationModule) {
        Import-Module $validationModule -Force
        
        # Validate deployed resources
        $validationResults = Test-DeploymentResources -Environment $Environment -ResourceTypes $ResourceTypes
        
        # Write validation summary
        Write-DeploymentSummary -ValidationResults $validationResults -LogFile $LogFile
        
        # Send alerts if validation failed
        if ($validationResults.OverallStatus -eq "Failed") {
            Send-DeploymentAlert -ValidationResults $validationResults -AlertLevel "Critical"
            Write-Log "Deployment validation FAILED - Some resources are missing or misconfigured" "ERROR"
            return $false
        }
        
        Write-Log "All deployed resources validated successfully" "SUCCESS"
        return $true
    }
    else {
        Write-Log "Validation module not found - skipping post-deployment validation" "WARNING"
        return $true
    }
}

function Export-DeploymentResults {
    param(
        [hashtable]$Deployments,
        [string]$Environment
    )
    
    Write-Log "=== Exporting Deployment Results ===" "INFO"
    
    $outputDir = Join-Path $ScriptDir "outputs"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $outputFile = Join-Path $outputDir "deployment-results_$($Environment)_$Timestamp.json"
    
    $results = @{
        Environment = $Environment
        Timestamp = $Timestamp
        DeploymentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ResourceGroupName = $ResourceGroupName
        Location = $Location
        ResourcesDeployed = @($Deployments.Keys)
        DeploymentDetails = @{}
    }
    
    foreach ($key in $Deployments.Keys) {
        $deployment = $Deployments[$key]
        if ($deployment) {
            # Handle CosmosContainers separately (it's a hashtable of deployments)
            if ($key -eq "CosmosContainers") {
                $containerDetails = @{}
                foreach ($containerName in $deployment.Keys) {
                    $containerDeployment = $deployment[$containerName]
                    if ($containerDeployment) {
                        $containerDetails[$containerName] = @{
                            DeploymentName = $containerDeployment.DeploymentName
                            ProvisioningState = $containerDeployment.ProvisioningState
                            Timestamp = if ($containerDeployment.Timestamp) { $containerDeployment.Timestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
                        }
                        
                        # Extract outputs
                        if ($containerDeployment.Outputs) {
                            $outputs = @{}
                            foreach ($outputKey in $containerDeployment.Outputs.Keys) {
                                $outputs[$outputKey] = $containerDeployment.Outputs[$outputKey].Value
                            }
                            $containerDetails[$containerName]['Outputs'] = $outputs
                        }
                    }
                }
                $results.DeploymentDetails[$key] = $containerDetails
            }
            else {
                $details = @{
                    DeploymentName = $deployment.DeploymentName
                    ProvisioningState = $deployment.ProvisioningState
                    Timestamp = if ($deployment.Timestamp) { $deployment.Timestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
                }
                
                # Extract outputs
                if ($deployment.Outputs) {
                    $outputs = @{}
                    foreach ($outputKey in $deployment.Outputs.Keys) {
                        $outputs[$outputKey] = $deployment.Outputs[$outputKey].Value
                    }
                    $details['Outputs'] = $outputs
                }
                
                $results.DeploymentDetails[$key] = $details
            }
        }
    }
    
    try {
        $results | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFile
        Write-Log "Deployment results exported to: $outputFile" "SUCCESS"
        
        # Also create a latest.json symlink/copy for easy access
        $latestFile = Join-Path $outputDir "deployment-results_$($Environment)_latest.json"
        $results | ConvertTo-Json -Depth 10 | Set-Content -Path $latestFile
        Write-Log "Latest results available at: $latestFile" "INFO"
        
        return $outputFile
    }
    catch {
        Write-Log "Failed to export deployment results: $_" "WARNING"
        return $null
    }
}

################################################################################
# Main Execution
################################################################################

try {
    Write-Log "=== Starting Azure Resources Deployment ===" "INFO"
    Write-Log "Environment: $EnvName ($Environment)" "INFO"
    Write-Log "Location: $Location" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Log File: $LogFile" "INFO"
    
    if ($WhatIf) {
        Write-Log "Running in WhatIf mode - no resources will be created" "WARNING"
    }
    
    # Validate prerequisites
    Test-Prerequisites
    
    $deployments = @{}
    $deploymentStartTime = Get-Date
    
    # Determine what to deploy
    $deployAll = $ResourceTypes -contains "all"
    
    # Deploy Resource Group (unless skipped)
    if (-not $SkipResourceGroup) {
        $deployments["ResourceGroup"] = Deploy-ResourceGroup
    }
    
    # Deploy resources in dependency order
    if ($deployAll -or $ResourceTypes -contains "vnet") {
        $deployments["VNet"] = Deploy-VirtualNetwork
    }
    
    if ($deployAll -or $ResourceTypes -contains "keyvault") {
        $deployments["KeyVault"] = Deploy-KeyVault
    }
    
    if ($deployAll -or $ResourceTypes -contains "storage") {
        $deployments["Storage"] = Deploy-StorageAccount
    }
    
    if ($deployAll -or $ResourceTypes -contains "cosmos") {
        $deployments["CosmosDatabase"] = Deploy-CosmosDatabase
    }
    
    # Deploy Cosmos DB Containers
    if ($deployAll -or $ResourceTypes -contains "cosmos-containers") {
        $containerDeployments = Deploy-CosmosContainers
        
        # Store container deployments
        if ($containerDeployments -and $containerDeployments.Count -gt 0) {
            $deployments["CosmosContainers"] = $containerDeployments
            
            # Validate deployed containers
            if (-not $WhatIf) {
                $cosmosAccountName = "kbudget-$Environment-cosmos"
                $cosmosDatabaseName = "kbudget-$Environment-db"
                $expectedContainers = @("users", "budgets", "envelopes", "transactions")
                
                Test-CosmosContainers `
                    -ResourceGroupName $ResourceGroupName `
                    -CosmosAccountName $cosmosAccountName `
                    -DatabaseName $cosmosDatabaseName `
                    -ExpectedContainers $expectedContainers
            }
        }
    }
    
    if ($deployAll -or $ResourceTypes -contains "appservice") {
        $deployments["AppService"] = Deploy-AppService
    }
    
    if ($deployAll -or $ResourceTypes -contains "functions") {
        $deployments["Functions"] = Deploy-AzureFunctions
    }
    
    if ($deployAll -or $ResourceTypes -contains "appgateway") {
        $deployments["ApplicationGateway"] = Deploy-ApplicationGateway
    }
    
    # Deploy monitoring resources (Log Analytics, Diagnostic Settings, Alerts)
    if ($deployAll -or $ResourceTypes -contains "monitoring") {
        # Deploy Log Analytics Workspace first
        $deployments["LogAnalytics"] = Deploy-LogAnalytics
        
        # Deploy Diagnostic Settings (requires Log Analytics and other resources)
        if ($deployments.ContainsKey("AppService") -or $deployments.ContainsKey("CosmosDatabase") -or 
            $deployments.ContainsKey("Storage") -or $deployments.ContainsKey("Functions") -or 
            $deployments.ContainsKey("KeyVault")) {
            $deployments["DiagnosticSettings"] = Deploy-DiagnosticSettings -Deployments $deployments
        }
        
        # Deploy Monitoring Alerts (requires other resources)
        if ($deployments.ContainsKey("AppService") -or $deployments.ContainsKey("CosmosDatabase") -or 
            $deployments.ContainsKey("Storage") -or $deployments.ContainsKey("Functions")) {
            $deployments["MonitoringAlerts"] = Deploy-MonitoringAlerts -Deployments $deployments
        }
    }
    
    $deploymentDuration = ((Get-Date) - $deploymentStartTime).TotalMinutes
    
    Write-Log "=== Deployment Summary ===" "SUCCESS"
    Write-Log "Environment: $EnvName" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Location: $Location" "INFO"
    Write-Log "Resources Deployed: $($deployments.Keys -join ', ')" "INFO"
    Write-Log "Deployment Duration: $([math]::Round($deploymentDuration, 2)) minutes" "INFO"
    Write-Log "Log File: $LogFile" "INFO"
    
    # Export deployment results
    if (-not $WhatIf) {
        $outputFile = Export-DeploymentResults -Deployments $deployments -Environment $Environment
        
        # Perform post-deployment validation
        $validationPassed = Invoke-PostDeploymentValidation -Deployments $deployments -Environment $Environment -ResourceTypes $ResourceTypes
        
        if (-not $validationPassed) {
            Write-Log "=== Deployment Completed with VALIDATION ERRORS ===" "ERROR"
            Write-Log "Review the validation summary above for details" "ERROR"
            exit 1
        }
    }
    
    Write-Log "=== Deployment Completed Successfully ===" "SUCCESS"
}
catch {
    Write-Log "=== Deployment Failed ===" "ERROR"
    Write-Log "Error: $_" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    Write-Log "Log File: $LogFile" "ERROR"
    
    # Send critical alert on deployment failure
    try {
        $alertData = @{
            Environment = $Environment
            OverallStatus = "Failed"
            Resources = @{
                Error = @{
                    Exists = $false
                    Error = $_.Exception.Message
                }
            }
        }
        Send-DeploymentAlert -ValidationResults $alertData -AlertLevel "Critical"
    }
    catch {
        Write-Log "Failed to send deployment alert: $_" "WARNING"
    }
    
    exit 1
}
