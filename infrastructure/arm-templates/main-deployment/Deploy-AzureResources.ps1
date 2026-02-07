################################################################################
# Azure Resources Deployment Script
# 
# Purpose: Deploy all Azure resources for KBudget GPT application
# Features:
#   - Deploys resource groups, VNet, Key Vault, Storage, SQL DB, App Service, Functions
#   - Supports dev, staging, and production environments
#   - Idempotent deployments (safe to run multiple times)
#   - Detailed logging and error handling
#   - Secure password handling via Key Vault
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
        
        # Generate and store SQL admin password
        $kvName = $deployment.Outputs.keyVaultName.Value
        $sqlPassword = -join ((65..90) + (97..122) + (48..57) + (33..47) | Get-Random -Count 16 | ForEach-Object {[char]$_})
        $securePassword = ConvertTo-SecureString -String $sqlPassword -AsPlainText -Force
        
        Set-AzKeyVaultSecret -VaultName $kvName -Name "SqlAdminPassword" -SecretValue $securePassword | Out-Null
        Write-Log "SQL admin password stored in Key Vault" "SUCCESS"
        
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

function Deploy-SqlDatabase {
    Write-Log "Deploying SQL Database..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "..\sql-database\sql-database.json"
    $parametersPath = Join-Path $ScriptDir "..\sql-database\parameters.$Environment.json"
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy SQL Database" "INFO"
            return
        }
        
        # Update parameter file to use actual subscription ID
        $subscriptionId = (Get-AzContext).Subscription.Id
        $paramContent = Get-Content $parametersPath -Raw | ConvertFrom-Json
        
        # Update Key Vault reference with actual subscription ID
        if ($paramContent.parameters.administratorLoginPassword.reference) {
            $kvId = $paramContent.parameters.administratorLoginPassword.reference.keyVault.id
            $kvId = $kvId -replace '\{subscription-id\}', $subscriptionId
            $paramContent.parameters.administratorLoginPassword.reference.keyVault.id = $kvId
        }
        
        $tempParamFile = Join-Path $env:TEMP "sql-params-$Timestamp.json"
        $paramContent | ConvertTo-Json -Depth 10 | Set-Content $tempParamFile
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "sql-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $tempParamFile `
            -Verbose
        
        Remove-Item $tempParamFile -Force
        
        Write-Log "SQL Database deployed successfully" "SUCCESS"
        Write-Log "SQL Server FQDN: $($deployment.Outputs.sqlServerFqdn.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy SQL Database: $_" "ERROR"
        throw
    }
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
    
    if ($deployAll -or $ResourceTypes -contains "sql") {
        $deployments["SqlDatabase"] = Deploy-SqlDatabase
    }
    
    if ($deployAll -or $ResourceTypes -contains "appservice") {
        $deployments["AppService"] = Deploy-AppService
    }
    
    if ($deployAll -or $ResourceTypes -contains "functions") {
        $deployments["Functions"] = Deploy-AzureFunctions
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
