#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Automated cleanup script for Azure Resource Groups

.DESCRIPTION
    This script finds and deletes Azure Resource Groups based on specified criteria:
    - Environment tags (Development, Staging, QA, Demo, Sandbox)
    - Age based on CreatedDate tag
    - Non-production environments only (Production is protected)
    
    Features:
    - Dry-run mode for safe review before deletion
    - Detailed logging with timestamps
    - Safety checks to prevent production deletion
    - Flexible filtering by tags, age, and environment

.PARAMETER Environment
    Filter by environment tag. Valid values: Development, Staging, QA, Demo, Sandbox, All
    Default: All (non-production environments)

.PARAMETER OlderThanDays
    Delete resource groups older than specified number of days (based on CreatedDate tag)
    Default: 90 days

.PARAMETER DryRun
    When specified, only shows what would be deleted without actually deleting
    Default: $true (safe by default)

.PARAMETER LogPath
    Path to the log file directory
    Default: ./logs

.PARAMETER IncludeUntagged
    Include resource groups without CreatedDate tag in the deletion list
    Default: $false

.EXAMPLE
    .\Cleanup-ResourceGroups.ps1 -DryRun
    Lists all non-production resource groups older than 90 days (no deletion)

.EXAMPLE
    .\Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30 -DryRun
    Lists Development resource groups older than 30 days (no deletion)

.EXAMPLE
    .\Cleanup-ResourceGroups.ps1 -Environment Staging -OlderThanDays 60 -DryRun:$false
    Deletes Staging resource groups older than 60 days (actual deletion)

.EXAMPLE
    .\Cleanup-ResourceGroups.ps1 -Environment All -OlderThanDays 180 -DryRun:$false -IncludeUntagged
    Deletes all non-production resource groups older than 180 days, including untagged ones

.NOTES
    Author: DevOps Team
    Project: KBudget GPT
    Version: 1.0.0
    
    SAFETY FEATURES:
    - Production resource groups are ALWAYS protected from deletion
    - Dry-run is enabled by default
    - All actions are logged with timestamps
    - Confirmation required for actual deletion
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Development', 'Staging', 'QA', 'Demo', 'Sandbox', 'All')]
    [string]$Environment = 'All',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 3650)]
    [int]$OlderThanDays = 90,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $true,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = './logs',

    [Parameter(Mandatory = $false)]
    [switch]$IncludeUntagged = $false
)

#region Configuration

# Protected environments that cannot be deleted
$ProtectedEnvironments = @('Production')

# Non-production environments eligible for cleanup
$NonProdEnvironments = @('Development', 'Staging', 'QA', 'Demo', 'Sandbox')

# Script configuration
$ScriptName = 'Cleanup-ResourceGroups'
$ScriptVersion = '1.0.0'

#endregion

#region Logging Functions

function Initialize-Logging {
    param(
        [string]$LogDirectory
    )
    
    # Create log directory if it doesn't exist
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
    
    # Create log file with timestamp
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $logFile = Join-Path -Path $LogDirectory -ChildPath "cleanup_${timestamp}.log"
    
    return $logFile
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$Level] $timestamp - $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $logEntry
    
    # Write to console with color
    switch ($Level) {
        'Info'    { Write-Host $logEntry -ForegroundColor Cyan }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
    }
}

#endregion

#region Validation Functions

function Test-AzureConnection {
    param([string]$LogFile)
    
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log -Message "Not connected to Azure. Please run 'Connect-AzAccount' first." -Level Error -LogFile $LogFile
            return $false
        }
        
        Write-Log -Message "Connected to Azure" -Level Success -LogFile $LogFile
        Write-Log -Message "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level Info -LogFile $LogFile
        Write-Log -Message "Account: $($context.Account.Id)" -Level Info -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Error checking Azure connection: $_" -Level Error -LogFile $LogFile
        return $false
    }
}

function Test-PowerShellVersion {
    param([string]$LogFile)
    
    $psVersion = $PSVersionTable.PSVersion
    Write-Log -Message "PowerShell Version: $psVersion" -Level Info -LogFile $LogFile
    
    if ($psVersion.Major -lt 5) {
        Write-Log -Message "PowerShell 5.0 or higher is required" -Level Error -LogFile $LogFile
        return $false
    }
    
    return $true
}

function Test-AzModule {
    param([string]$LogFile)
    
    if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Log -Message "Az.Resources module not found. Please install it: Install-Module -Name Az.Resources" -Level Error -LogFile $LogFile
        return $false
    }
    
    Write-Log -Message "Az.Resources module is available" -Level Success -LogFile $LogFile
    return $true
}

#endregion

#region Resource Group Functions

function Get-ResourceGroupAge {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ResourceGroup
    )
    
    # Try to get CreatedDate from tags
    if ($ResourceGroup.Tags -and $ResourceGroup.Tags.ContainsKey('CreatedDate')) {
        $createdDateString = $ResourceGroup.Tags['CreatedDate']
        try {
            $createdDate = [DateTime]::Parse($createdDateString)
            $age = (Get-Date) - $createdDate
            return [PSCustomObject]@{
                HasTag = $true
                CreatedDate = $createdDate
                AgeDays = [int]$age.TotalDays
            }
        }
        catch {
            return [PSCustomObject]@{
                HasTag = $true
                CreatedDate = $null
                AgeDays = -1
                Error = "Invalid date format: $createdDateString"
            }
        }
    }
    else {
        return [PSCustomObject]@{
            HasTag = $false
            CreatedDate = $null
            AgeDays = -1
        }
    }
}

function Get-ResourceGroupsForCleanup {
    param(
        [string]$EnvironmentFilter,
        [int]$MinAgeDays,
        [bool]$IncludeUntaggedGroups,
        [string]$LogFile
    )
    
    Write-Log -Message "Searching for resource groups matching cleanup criteria..." -Level Info -LogFile $LogFile
    Write-Log -Message "  Environment Filter: $EnvironmentFilter" -Level Info -LogFile $LogFile
    Write-Log -Message "  Minimum Age: $MinAgeDays days" -Level Info -LogFile $LogFile
    Write-Log -Message "  Include Untagged: $IncludeUntaggedGroups" -Level Info -LogFile $LogFile
    
    # Get all resource groups
    $allResourceGroups = Get-AzResourceGroup
    Write-Log -Message "Found $($allResourceGroups.Count) total resource groups in subscription" -Level Info -LogFile $LogFile
    
    $candidatesForDeletion = @()
    
    foreach ($rg in $allResourceGroups) {
        $rgName = $rg.ResourceGroupName
        
        # Check environment tag
        $envTag = $rg.Tags['Environment']
        
        # Skip if no environment tag and we're not including untagged
        if (-not $envTag -and -not $IncludeUntaggedGroups) {
            Write-Log -Message "  Skipping $rgName - No Environment tag" -Level Info -LogFile $LogFile
            continue
        }
        
        # PROTECTION: Never delete Production resource groups
        if ($envTag -in $ProtectedEnvironments) {
            Write-Log -Message "  Skipping $rgName - Protected environment: $envTag" -Level Warning -LogFile $LogFile
            continue
        }
        
        # Filter by environment if not 'All'
        if ($EnvironmentFilter -ne 'All' -and $envTag -ne $EnvironmentFilter) {
            continue
        }
        
        # Check age
        $ageInfo = Get-ResourceGroupAge -ResourceGroup $rg
        
        if (-not $ageInfo.HasTag -and -not $IncludeUntaggedGroups) {
            Write-Log -Message "  Skipping $rgName - No CreatedDate tag" -Level Info -LogFile $LogFile
            continue
        }
        
        if ($ageInfo.AgeDays -lt 0 -and -not $IncludeUntaggedGroups) {
            Write-Log -Message "  Skipping $rgName - Invalid or missing CreatedDate" -Level Warning -LogFile $LogFile
            continue
        }
        
        # For untagged groups, we include them if IncludeUntagged is true
        $meetsAgeCriteria = $false
        if ($ageInfo.AgeDays -ge $MinAgeDays) {
            $meetsAgeCriteria = $true
        }
        elseif (-not $ageInfo.HasTag -and $IncludeUntaggedGroups) {
            # Include untagged groups regardless of age
            $meetsAgeCriteria = $true
        }
        
        if ($meetsAgeCriteria) {
            $candidatesForDeletion += [PSCustomObject]@{
                ResourceGroupName = $rgName
                Location = $rg.Location
                Environment = if ($envTag) { $envTag } else { 'Untagged' }
                CreatedDate = if ($ageInfo.CreatedDate) { $ageInfo.CreatedDate.ToString('yyyy-MM-dd') } else { 'Unknown' }
                AgeDays = if ($ageInfo.AgeDays -ge 0) { $ageInfo.AgeDays } else { 'Unknown' }
                Tags = $rg.Tags
            }
        }
    }
    
    Write-Log -Message "Found $($candidatesForDeletion.Count) resource groups matching cleanup criteria" -Level Info -LogFile $LogFile
    
    return $candidatesForDeletion
}

function Remove-ResourceGroupsWithLogging {
    param(
        [array]$ResourceGroups,
        [bool]$IsDryRun,
        [string]$LogFile
    )
    
    if ($ResourceGroups.Count -eq 0) {
        Write-Log -Message "No resource groups to delete" -Level Info -LogFile $LogFile
        return @{
            Attempted = 0
            Succeeded = 0
            Failed = 0
        }
    }
    
    $results = @{
        Attempted = $ResourceGroups.Count
        Succeeded = 0
        Failed = 0
    }
    
    foreach ($rg in $ResourceGroups) {
        $rgName = $rg.ResourceGroupName
        
        if ($IsDryRun) {
            Write-Log -Message "[DRY RUN] Would delete: $rgName (Environment: $($rg.Environment), Age: $($rg.AgeDays) days)" -Level Warning -LogFile $LogFile
        }
        else {
            try {
                Write-Log -Message "Deleting resource group: $rgName" -Level Info -LogFile $LogFile
                Remove-AzResourceGroup -Name $rgName -Force -AsJob | Out-Null
                Write-Log -Message "  Successfully initiated deletion of $rgName (async operation)" -Level Success -LogFile $LogFile
                $results.Succeeded++
            }
            catch {
                Write-Log -Message "  Failed to delete $rgName - Error: $_" -Level Error -LogFile $LogFile
                $results.Failed++
            }
        }
    }
    
    return $results
}

#endregion

#region Main Script

function Main {
    # Initialize logging
    $logFile = Initialize-Logging -LogDirectory $LogPath
    
    Write-Log -Message "========================================" -Level Info -LogFile $logFile
    Write-Log -Message "$ScriptName v$ScriptVersion" -Level Info -LogFile $logFile
    Write-Log -Message "KBudget GPT - Resource Group Cleanup" -Level Info -LogFile $logFile
    Write-Log -Message "========================================" -Level Info -LogFile $logFile
    Write-Log -Message "Execution started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info -LogFile $logFile
    Write-Log -Message "Log file: $logFile" -Level Info -LogFile $logFile
    Write-Log -Message "" -Level Info -LogFile $logFile
    
    # Display parameters
    Write-Log -Message "Parameters:" -Level Info -LogFile $logFile
    Write-Log -Message "  Environment: $Environment" -Level Info -LogFile $logFile
    Write-Log -Message "  Older Than Days: $OlderThanDays" -Level Info -LogFile $logFile
    Write-Log -Message "  Dry Run: $DryRun" -Level Info -LogFile $logFile
    Write-Log -Message "  Include Untagged: $IncludeUntagged" -Level Info -LogFile $logFile
    Write-Log -Message "" -Level Info -LogFile $logFile
    
    # Validate prerequisites
    Write-Log -Message "Validating prerequisites..." -Level Info -LogFile $logFile
    
    if (-not (Test-PowerShellVersion -LogFile $logFile)) {
        return 1
    }
    
    if (-not (Test-AzModule -LogFile $logFile)) {
        return 1
    }
    
    if (-not (Test-AzureConnection -LogFile $logFile)) {
        return 1
    }
    
    Write-Log -Message "" -Level Info -LogFile $logFile
    
    # Get resource groups for cleanup
    $resourceGroupsToDelete = Get-ResourceGroupsForCleanup `
        -EnvironmentFilter $Environment `
        -MinAgeDays $OlderThanDays `
        -IncludeUntaggedGroups $IncludeUntagged `
        -LogFile $logFile
    
    Write-Log -Message "" -Level Info -LogFile $logFile
    
    # Display summary
    if ($resourceGroupsToDelete.Count -eq 0) {
        Write-Log -Message "No resource groups found matching the cleanup criteria" -Level Success -LogFile $logFile
    }
    else {
        Write-Log -Message "Resource Groups for Cleanup:" -Level Info -LogFile $logFile
        Write-Log -Message "========================================" -Level Info -LogFile $logFile
        
        $resourceGroupsToDelete | ForEach-Object {
            Write-Log -Message "  Name: $($_.ResourceGroupName)" -Level Info -LogFile $logFile
            Write-Log -Message "    Environment: $($_.Environment)" -Level Info -LogFile $logFile
            Write-Log -Message "    Location: $($_.Location)" -Level Info -LogFile $logFile
            Write-Log -Message "    Created: $($_.CreatedDate)" -Level Info -LogFile $logFile
            Write-Log -Message "    Age: $($_.AgeDays) days" -Level Info -LogFile $logFile
            Write-Log -Message "" -Level Info -LogFile $logFile
        }
        
        Write-Log -Message "========================================" -Level Info -LogFile $logFile
        
        # Confirmation for actual deletion
        if (-not $DryRun) {
            Write-Log -Message "WARNING: You are about to DELETE $($resourceGroupsToDelete.Count) resource group(s)" -Level Warning -LogFile $logFile
            Write-Log -Message "This action CANNOT be undone!" -Level Warning -LogFile $logFile
            
            $confirmation = Read-Host "Type 'DELETE' to confirm deletion"
            
            if ($confirmation -ne 'DELETE') {
                Write-Log -Message "Deletion cancelled by user" -Level Warning -LogFile $logFile
                return 0
            }
        }
        
        # Perform deletion
        Write-Log -Message "" -Level Info -LogFile $logFile
        $deleteResults = Remove-ResourceGroupsWithLogging `
            -ResourceGroups $resourceGroupsToDelete `
            -IsDryRun $DryRun `
            -LogFile $logFile
        
        # Summary
        Write-Log -Message "" -Level Info -LogFile $logFile
        Write-Log -Message "========================================" -Level Info -LogFile $logFile
        Write-Log -Message "Cleanup Summary:" -Level Info -LogFile $logFile
        Write-Log -Message "  Resource Groups Identified: $($deleteResults.Attempted)" -Level Info -LogFile $logFile
        
        if ($DryRun) {
            Write-Log -Message "  Mode: DRY RUN (no actual deletions performed)" -Level Warning -LogFile $logFile
            Write-Log -Message "  Run with -DryRun:`$false to perform actual deletion" -Level Info -LogFile $logFile
        }
        else {
            Write-Log -Message "  Successfully Deleted: $($deleteResults.Succeeded)" -Level Success -LogFile $logFile
            Write-Log -Message "  Failed: $($deleteResults.Failed)" -Level Info -LogFile $logFile
            
            if ($deleteResults.Succeeded -gt 0) {
                Write-Log -Message "  Note: Deletion is asynchronous. Check Azure Portal for completion status." -Level Info -LogFile $logFile
            }
        }
    }
    
    Write-Log -Message "========================================" -Level Info -LogFile $logFile
    Write-Log -Message "Execution completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info -LogFile $logFile
    Write-Log -Message "Log file: $logFile" -Level Info -LogFile $logFile
    Write-Log -Message "========================================" -Level Info -LogFile $logFile
    
    return 0
}

# Execute main function
$exitCode = Main
exit $exitCode

#endregion
