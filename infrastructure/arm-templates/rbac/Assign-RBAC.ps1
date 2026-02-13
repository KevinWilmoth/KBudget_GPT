################################################################################
# Azure RBAC Assignment Script
# 
# Purpose: Assign Role-Based Access Control (RBAC) to Azure resources
# Features:
#   - Assigns built-in roles (Reader, Contributor, Owner) to users/groups
#   - Supports custom role definitions
#   - Configures service principals with least-privilege permissions
#   - Validates role assignments
#   - Supports dev, staging, and production environments
#   - Detailed logging and error handling
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Owner or User Access Administrator role on subscription/resource group
#
# Usage:
#   .\Assign-RBAC.ps1 -Environment dev -ConfigFile "rbac-config.dev.json"
#   .\Assign-RBAC.ps1 -Environment staging -ConfigFile "rbac-config.staging.json"
#   .\Assign-RBAC.ps1 -Environment prod -ConfigFile "rbac-config.prod.json"
#   .\Assign-RBAC.ps1 -Environment dev -WhatIf
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "rbac_assignment_$($Environment)_$Timestamp.log"

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

# Default resource group name if not provided
if (-not $ResourceGroupName) {
    $ResourceGroupName = "kbudget-$Environment-rg"
}

# Default config file if not provided
if (-not $ConfigFile) {
    $ConfigFile = Join-Path $ScriptDir "rbac-config.$Environment.json"
}

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

function Write-SectionHeader {
    param([string]$Title)
    
    $Separator = "=" * 80
    Write-Log ""
    Write-Log $Separator
    Write-Log $Title
    Write-Log $Separator
    Write-Log ""
}

################################################################################
# Helper Functions
################################################################################

function Test-Prerequisites {
    Write-SectionHeader "Checking Prerequisites"
    
    # Check Azure PowerShell module
    Write-Log "Checking for Azure PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Write-Log "Azure PowerShell module (Az) not found. Please install it." "ERROR"
        Write-Log "Run: Install-Module -Name Az -AllowClobber -Scope CurrentUser" "ERROR"
        return $false
    }
    Write-Log "Azure PowerShell module found" "SUCCESS"
    
    # Check Azure authentication
    Write-Log "Checking Azure authentication..."
    $context = Get-AzContext
    if (-not $context) {
        Write-Log "Not authenticated to Azure. Please run Connect-AzAccount" "ERROR"
        return $false
    }
    Write-Log "Authenticated as: $($context.Account.Id)" "SUCCESS"
    Write-Log "Subscription: $($context.Subscription.Name)" "INFO"
    
    # Check if resource group exists
    Write-Log "Checking if resource group '$ResourceGroupName' exists..."
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Log "Resource group '$ResourceGroupName' not found" "ERROR"
        return $false
    }
    Write-Log "Resource group found: $($rg.ResourceGroupName)" "SUCCESS"
    
    # Check if config file exists
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Configuration file not found: $ConfigFile" "ERROR"
        Write-Log "Please create a configuration file or specify a valid path" "ERROR"
        return $false
    }
    Write-Log "Configuration file found: $ConfigFile" "SUCCESS"
    
    return $true
}

function Get-RBACConfiguration {
    Write-SectionHeader "Loading RBAC Configuration"
    
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded successfully" "SUCCESS"
        Write-Log "Number of role assignments: $($config.roleAssignments.Count)" "INFO"
        return $config
    }
    catch {
        Write-Log "Failed to load configuration file: $_" "ERROR"
        throw
    }
}

function Resolve-PrincipalId {
    param(
        [string]$PrincipalType,
        [string]$PrincipalIdentifier
    )
    
    try {
        switch ($PrincipalType.ToLower()) {
            "user" {
                $user = Get-AzADUser -UserPrincipalName $PrincipalIdentifier -ErrorAction SilentlyContinue
                if (-not $user) {
                    $user = Get-AzADUser -Mail $PrincipalIdentifier -ErrorAction SilentlyContinue
                }
                if (-not $user) {
                    $user = Get-AzADUser -DisplayName $PrincipalIdentifier -ErrorAction SilentlyContinue
                }
                if ($user) {
                    return @{
                        Id = $user.Id
                        DisplayName = $user.DisplayName
                        Type = "User"
                    }
                }
            }
            "group" {
                $group = Get-AzADGroup -DisplayName $PrincipalIdentifier -ErrorAction SilentlyContinue
                if ($group) {
                    return @{
                        Id = $group.Id
                        DisplayName = $group.DisplayName
                        Type = "Group"
                    }
                }
            }
            "serviceprincipal" {
                $sp = Get-AzADServicePrincipal -DisplayName $PrincipalIdentifier -ErrorAction SilentlyContinue
                if (-not $sp) {
                    $sp = Get-AzADServicePrincipal -ApplicationId $PrincipalIdentifier -ErrorAction SilentlyContinue
                }
                if ($sp) {
                    return @{
                        Id = $sp.Id
                        DisplayName = $sp.DisplayName
                        Type = "ServicePrincipal"
                    }
                }
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Error resolving principal: $_" "WARNING"
        return $null
    }
}

function Get-ResourceId {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$ResourceGroupName
    )
    
    try {
        switch ($ResourceType.ToLower()) {
            "resourcegroup" {
                $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
                if ($rg) {
                    return $rg.ResourceId
                }
            }
            "storageaccount" {
                $storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
                if ($storage) {
                    return $storage.Id
                }
            }
            "keyvault" {
                $kv = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $ResourceName -ErrorAction SilentlyContinue
                if ($kv) {
                    return $kv.ResourceId
                }
            }
            "sqldatabase" {
                # For SQL Database, we need server and database name
                $parts = $ResourceName -split "/"
                if ($parts.Count -eq 2) {
                    $serverName = $parts[0]
                    $dbName = $parts[1]
                    $db = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $serverName -DatabaseName $dbName -ErrorAction SilentlyContinue
                    if ($db) {
                        return $db.ResourceId
                    }
                }
            }
            "appservice" {
                $app = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
                if ($app) {
                    return $app.Id
                }
            }
            "functionapp" {
                $func = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
                if ($func) {
                    return $func.Id
                }
            }
            "loganalytics" {
                $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
                if ($workspace) {
                    return $workspace.ResourceId
                }
            }
            "subscription" {
                $context = Get-AzContext
                return "/subscriptions/$($context.Subscription.Id)"
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Error getting resource ID: $_" "WARNING"
        return $null
    }
}

function Assign-Role {
    param(
        [object]$Assignment
    )
    
    $principalInfo = Resolve-PrincipalId -PrincipalType $Assignment.principalType -PrincipalIdentifier $Assignment.principalIdentifier
    
    if (-not $principalInfo) {
        Write-Log "Failed to resolve principal: $($Assignment.principalIdentifier)" "ERROR"
        return $false
    }
    
    Write-Log "Resolved principal: $($principalInfo.DisplayName) ($($principalInfo.Type))" "INFO"
    
    # Get resource scope
    $scope = $null
    if ($Assignment.scope.type -eq "ResourceGroup") {
        $scope = (Get-AzResourceGroup -Name $Assignment.scope.name).ResourceId
    }
    elseif ($Assignment.scope.type -eq "Subscription") {
        $context = Get-AzContext
        $scope = "/subscriptions/$($context.Subscription.Id)"
    }
    else {
        $scope = Get-ResourceId -ResourceType $Assignment.scope.type -ResourceName $Assignment.scope.name -ResourceGroupName $ResourceGroupName
    }
    
    if (-not $scope) {
        Write-Log "Failed to determine scope for: $($Assignment.scope.name)" "ERROR"
        return $false
    }
    
    Write-Log "Scope: $scope" "INFO"
    
    # Check if role assignment already exists
    $existingAssignment = Get-AzRoleAssignment -ObjectId $principalInfo.Id -RoleDefinitionName $Assignment.role -Scope $scope -ErrorAction SilentlyContinue
    
    if ($existingAssignment) {
        Write-Log "Role assignment already exists: $($Assignment.role) for $($principalInfo.DisplayName)" "WARNING"
        return $true
    }
    
    # Assign role
    if ($WhatIf) {
        Write-Log "WHATIF: Would assign role '$($Assignment.role)' to '$($principalInfo.DisplayName)' on scope '$scope'" "INFO"
        return $true
    }
    
    try {
        Write-Log "Assigning role: $($Assignment.role)" "INFO"
        $roleAssignment = New-AzRoleAssignment `
            -ObjectId $principalInfo.Id `
            -RoleDefinitionName $Assignment.role `
            -Scope $scope `
            -ErrorAction Stop
        
        Write-Log "Role assigned successfully: $($Assignment.role) to $($principalInfo.DisplayName)" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to assign role: $_" "ERROR"
        return $false
    }
}

################################################################################
# Main Execution
################################################################################

function Main {
    Write-SectionHeader "Azure RBAC Assignment Script - $EnvName Environment"
    
    Write-Log "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Environment: $EnvName" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Configuration File: $ConfigFile" "INFO"
    Write-Log "WhatIf Mode: $WhatIf" "INFO"
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Exiting." "ERROR"
        exit 1
    }
    
    # Load configuration
    try {
        $config = Get-RBACConfiguration
    }
    catch {
        Write-Log "Failed to load configuration. Exiting." "ERROR"
        exit 1
    }
    
    # Process role assignments
    Write-SectionHeader "Processing Role Assignments"
    
    $successCount = 0
    $failureCount = 0
    $skippedCount = 0
    
    foreach ($assignment in $config.roleAssignments) {
        Write-Log "" "INFO"
        Write-Log "Processing assignment for: $($assignment.principalIdentifier)" "INFO"
        Write-Log "Role: $($assignment.role)" "INFO"
        Write-Log "Scope Type: $($assignment.scope.type)" "INFO"
        Write-Log "Scope Name: $($assignment.scope.name)" "INFO"
        
        $result = Assign-Role -Assignment $assignment
        
        if ($result) {
            $successCount++
        }
        else {
            $failureCount++
        }
    }
    
    # Summary
    Write-SectionHeader "RBAC Assignment Summary"
    Write-Log "Total Assignments Processed: $($config.roleAssignments.Count)" "INFO"
    Write-Log "Successful: $successCount" "SUCCESS"
    Write-Log "Failed: $failureCount" $(if ($failureCount -gt 0) { "ERROR" } else { "INFO" })
    Write-Log "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    
    if ($failureCount -gt 0) {
        Write-Log "Some role assignments failed. Please review the log file: $LogFile" "WARNING"
        exit 1
    }
    
    Write-Log "RBAC assignment completed successfully!" "SUCCESS"
    Write-Log "Log file: $LogFile" "INFO"
}

# Execute main function
Main
