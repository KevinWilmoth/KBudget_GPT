################################################################################
# Azure RBAC Audit Script
# 
# Purpose: Audit Role-Based Access Control (RBAC) assignments
# Features:
#   - Reviews current role assignments across resources
#   - Identifies over-privileged accounts
#   - Generates audit reports in JSON and CSV formats
#   - Validates least-privilege compliance
#   - Supports dev, staging, and production environments
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Reader role or higher on subscription/resource group
#
# Usage:
#   .\Audit-RBAC.ps1 -Environment dev
#   .\Audit-RBAC.ps1 -Environment staging -OutputFormat JSON
#   .\Audit-RBAC.ps1 -Environment prod -ResourceGroupName "kbudget-prod-rg"
#   .\Audit-RBAC.ps1 -Environment dev -IncludeInheritedAssignments
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "CSV", "Both")]
    [string]$OutputFormat = "Both",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeInheritedAssignments,

    [Parameter(Mandatory = $false)]
    [switch]$DetailedReport
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$ReportDir = Join-Path $ScriptDir "reports"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "rbac_audit_$($Environment)_$Timestamp.log"

# Ensure directories exist
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
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
    
    return $true
}

function Get-RoleAssignments {
    param(
        [string]$Scope
    )
    
    Write-SectionHeader "Retrieving Role Assignments"
    
    try {
        $assignments = @()
        
        if ($IncludeInheritedAssignments) {
            Write-Log "Retrieving all role assignments (including inherited)..." "INFO"
            $assignments = Get-AzRoleAssignment -Scope $Scope
        }
        else {
            Write-Log "Retrieving direct role assignments only..." "INFO"
            $assignments = Get-AzRoleAssignment -Scope $Scope | Where-Object { $_.Scope -eq $Scope }
        }
        
        Write-Log "Found $($assignments.Count) role assignments" "SUCCESS"
        return $assignments
    }
    catch {
        Write-Log "Failed to retrieve role assignments: $_" "ERROR"
        return @()
    }
}

function Get-ResourceAssignments {
    param(
        [string]$ResourceGroupName
    )
    
    Write-SectionHeader "Retrieving Resource-Level Assignments"
    
    try {
        $resources = Get-AzResource -ResourceGroupName $ResourceGroupName
        $resourceAssignments = @()
        
        Write-Log "Found $($resources.Count) resources in resource group" "INFO"
        
        foreach ($resource in $resources) {
            Write-Log "Checking resource: $($resource.Name) ($($resource.ResourceType))" "INFO"
            
            $assignments = Get-AzRoleAssignment -Scope $resource.ResourceId -ErrorAction SilentlyContinue
            
            if ($assignments) {
                foreach ($assignment in $assignments) {
                    $resourceAssignments += [PSCustomObject]@{
                        ResourceName = $resource.Name
                        ResourceType = $resource.ResourceType
                        ResourceId = $resource.ResourceId
                        DisplayName = $assignment.DisplayName
                        SignInName = $assignment.SignInName
                        ObjectType = $assignment.ObjectType
                        RoleDefinitionName = $assignment.RoleDefinitionName
                        Scope = $assignment.Scope
                    }
                }
            }
        }
        
        Write-Log "Found $($resourceAssignments.Count) resource-level assignments" "SUCCESS"
        return $resourceAssignments
    }
    catch {
        Write-Log "Failed to retrieve resource assignments: $_" "ERROR"
        return @()
    }
}

function Analyze-RoleAssignments {
    param(
        [array]$Assignments
    )
    
    Write-SectionHeader "Analyzing Role Assignments"
    
    $analysis = @{
        TotalAssignments = $Assignments.Count
        ByRole = @{}
        ByPrincipalType = @{}
        HighPrivilegeAccounts = @()
        ServicePrincipals = @()
        Users = @()
        Groups = @()
    }
    
    # Group by role
    $roleGroups = $Assignments | Group-Object -Property RoleDefinitionName
    foreach ($group in $roleGroups) {
        $analysis.ByRole[$group.Name] = $group.Count
    }
    
    # Group by principal type
    $typeGroups = $Assignments | Group-Object -Property ObjectType
    foreach ($group in $typeGroups) {
        $analysis.ByPrincipalType[$group.Name] = $group.Count
    }
    
    # Identify high-privilege accounts (Owner, Contributor, User Access Administrator)
    $highPrivilegeRoles = @("Owner", "Contributor", "User Access Administrator")
    $analysis.HighPrivilegeAccounts = $Assignments | Where-Object { 
        $highPrivilegeRoles -contains $_.RoleDefinitionName 
    } | Select-Object DisplayName, SignInName, RoleDefinitionName, ObjectType, Scope
    
    # Separate by type
    $analysis.ServicePrincipals = $Assignments | Where-Object { $_.ObjectType -eq "ServicePrincipal" }
    $analysis.Users = $Assignments | Where-Object { $_.ObjectType -eq "User" }
    $analysis.Groups = $Assignments | Where-Object { $_.ObjectType -eq "Group" }
    
    return $analysis
}

function Export-AuditReport {
    param(
        [array]$Assignments,
        [object]$Analysis
    )
    
    Write-SectionHeader "Exporting Audit Report"
    
    $reportBaseName = "rbac_audit_$($Environment)_$Timestamp"
    
    # Export detailed assignments
    if ($OutputFormat -eq "JSON" -or $OutputFormat -eq "Both") {
        $jsonFile = Join-Path $ReportDir "$reportBaseName.json"
        
        $report = @{
            GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Environment = $EnvName
            ResourceGroup = $ResourceGroupName
            Summary = @{
                TotalAssignments = $Analysis.TotalAssignments
                HighPrivilegeCount = $Analysis.HighPrivilegeAccounts.Count
                ServicePrincipalsCount = $Analysis.ServicePrincipals.Count
                UsersCount = $Analysis.Users.Count
                GroupsCount = $Analysis.Groups.Count
            }
            RoleDistribution = $Analysis.ByRole
            PrincipalTypeDistribution = $Analysis.ByPrincipalType
            HighPrivilegeAccounts = $Analysis.HighPrivilegeAccounts
            AllAssignments = $Assignments | Select-Object DisplayName, SignInName, ObjectType, RoleDefinitionName, Scope
        }
        
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
        Write-Log "JSON report exported: $jsonFile" "SUCCESS"
    }
    
    # Export CSV
    if ($OutputFormat -eq "CSV" -or $OutputFormat -eq "Both") {
        $csvFile = Join-Path $ReportDir "$reportBaseName.csv"
        
        $Assignments | Select-Object `
            DisplayName, `
            SignInName, `
            ObjectType, `
            RoleDefinitionName, `
            Scope | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        
        Write-Log "CSV report exported: $csvFile" "SUCCESS"
        
        # Export high-privilege accounts separately
        if ($Analysis.HighPrivilegeAccounts.Count -gt 0) {
            $highPrivCsvFile = Join-Path $ReportDir "$($reportBaseName)_high_privilege.csv"
            $Analysis.HighPrivilegeAccounts | Export-Csv -Path $highPrivCsvFile -NoTypeInformation -Encoding UTF8
            Write-Log "High-privilege accounts report exported: $highPrivCsvFile" "SUCCESS"
        }
    }
}

function Show-AuditSummary {
    param(
        [object]$Analysis
    )
    
    Write-SectionHeader "Audit Summary"
    
    Write-Log "Total Role Assignments: $($Analysis.TotalAssignments)" "INFO"
    Write-Log "" "INFO"
    
    Write-Log "Role Distribution:" "INFO"
    foreach ($role in $Analysis.ByRole.GetEnumerator() | Sort-Object Value -Descending) {
        Write-Log "  - $($role.Key): $($role.Value)" "INFO"
    }
    Write-Log "" "INFO"
    
    Write-Log "Principal Type Distribution:" "INFO"
    foreach ($type in $Analysis.ByPrincipalType.GetEnumerator()) {
        Write-Log "  - $($type.Key): $($type.Value)" "INFO"
    }
    Write-Log "" "INFO"
    
    if ($Analysis.HighPrivilegeAccounts.Count -gt 0) {
        Write-Log "High-Privilege Accounts: $($Analysis.HighPrivilegeAccounts.Count)" "WARNING"
        foreach ($account in $Analysis.HighPrivilegeAccounts) {
            Write-Log "  - $($account.DisplayName) ($($account.ObjectType)): $($account.RoleDefinitionName)" "WARNING"
        }
    }
    else {
        Write-Log "No high-privilege accounts found" "SUCCESS"
    }
    Write-Log "" "INFO"
    
    Write-Log "Service Principals: $($Analysis.ServicePrincipals.Count)" "INFO"
    if ($DetailedReport -and $Analysis.ServicePrincipals.Count -gt 0) {
        foreach ($sp in $Analysis.ServicePrincipals) {
            Write-Log "  - $($sp.DisplayName): $($sp.RoleDefinitionName)" "INFO"
        }
    }
}

################################################################################
# Main Execution
################################################################################

function Main {
    Write-SectionHeader "Azure RBAC Audit Script - $EnvName Environment"
    
    Write-Log "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Environment: $EnvName" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Output Format: $OutputFormat" "INFO"
    Write-Log "Include Inherited: $IncludeInheritedAssignments" "INFO"
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Exiting." "ERROR"
        exit 1
    }
    
    # Get resource group
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        $scope = $rg.ResourceId
        Write-Log "Resource group scope: $scope" "INFO"
    }
    catch {
        Write-Log "Failed to get resource group: $_" "ERROR"
        exit 1
    }
    
    # Get role assignments
    $assignments = Get-RoleAssignments -Scope $scope
    
    if ($assignments.Count -eq 0) {
        Write-Log "No role assignments found" "WARNING"
        exit 0
    }
    
    # Get resource-level assignments if detailed report requested
    if ($DetailedReport) {
        $resourceAssignments = Get-ResourceAssignments -ResourceGroupName $ResourceGroupName
        Write-Log "Total resource-level assignments: $($resourceAssignments.Count)" "INFO"
    }
    
    # Analyze assignments
    $analysis = Analyze-RoleAssignments -Assignments $assignments
    
    # Show summary
    Show-AuditSummary -Analysis $analysis
    
    # Export report
    Export-AuditReport -Assignments $assignments -Analysis $analysis
    
    Write-SectionHeader "Audit Complete"
    Write-Log "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Log file: $LogFile" "INFO"
    Write-Log "Reports directory: $ReportDir" "INFO"
}

# Execute main function
Main
