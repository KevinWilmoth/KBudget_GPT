################################################################################
# Azure RBAC Testing Script
# 
# Purpose: Test and validate RBAC assignments
# Features:
#   - Validates role assignments exist
#   - Tests least-privilege compliance
#   - Verifies service principal permissions
#   - Checks for over-privileged accounts
#   - Generates test reports
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Reader role or higher on subscription/resource group
#
# Usage:
#   .\Test-RBAC.ps1 -Environment dev
#   .\Test-RBAC.ps1 -Environment staging -ConfigFile "rbac-config.staging.json"
#   .\Test-RBAC.ps1 -Environment prod -ValidateLeastPrivilege
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
    [switch]$ValidateLeastPrivilege
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "rbac_test_$($Environment)_$Timestamp.log"

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
# Test Functions
################################################################################

function Test-Prerequisites {
    Write-SectionHeader "Checking Prerequisites"
    
    $passed = $true
    
    # Check Azure PowerShell module
    Write-Log "Checking for Azure PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Write-Log "Azure PowerShell module (Az) not found" "ERROR"
        $passed = $false
    }
    else {
        Write-Log "Azure PowerShell module found" "SUCCESS"
    }
    
    # Check Azure authentication
    Write-Log "Checking Azure authentication..."
    $context = Get-AzContext
    if (-not $context) {
        Write-Log "Not authenticated to Azure" "ERROR"
        $passed = $false
    }
    else {
        Write-Log "Authenticated as: $($context.Account.Id)" "SUCCESS"
    }
    
    # Check if resource group exists
    Write-Log "Checking if resource group exists..."
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Log "Resource group '$ResourceGroupName' not found" "ERROR"
        $passed = $false
    }
    else {
        Write-Log "Resource group found" "SUCCESS"
    }
    
    return $passed
}

function Test-ConfigurationFile {
    Write-SectionHeader "Testing Configuration File"
    
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Configuration file not found: $ConfigFile" "ERROR"
        return $false
    }
    
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Log "Configuration file loaded successfully" "SUCCESS"
        Write-Log "Role assignments defined: $($config.roleAssignments.Count)" "INFO"
        return $true
    }
    catch {
        Write-Log "Failed to parse configuration file: $_" "ERROR"
        return $false
    }
}

function Test-RoleAssignments {
    param([object]$Config)
    
    Write-SectionHeader "Testing Role Assignments"
    
    $testResults = @()
    
    foreach ($assignment in $Config.roleAssignments) {
        Write-Log "Testing: $($assignment.principalIdentifier) - $($assignment.role)" "INFO"
        
        $testResult = [PSCustomObject]@{
            Principal = $assignment.principalIdentifier
            Role = $assignment.role
            Scope = "$($assignment.scope.type)/$($assignment.scope.name)"
            Status = "Unknown"
            Message = ""
        }
        
        try {
            # Try to resolve principal
            $principal = $null
            switch ($assignment.principalType.ToLower()) {
                "user" {
                    $principal = Get-AzADUser -UserPrincipalName $assignment.principalIdentifier -ErrorAction SilentlyContinue
                }
                "group" {
                    $principal = Get-AzADGroup -DisplayName $assignment.principalIdentifier -ErrorAction SilentlyContinue
                }
                "serviceprincipal" {
                    $principal = Get-AzADServicePrincipal -DisplayName $assignment.principalIdentifier -ErrorAction SilentlyContinue
                }
            }
            
            if (-not $principal) {
                $testResult.Status = "FAILED"
                $testResult.Message = "Principal not found in Azure AD"
                Write-Log "  ❌ Principal not found" "ERROR"
                $testResults += $testResult
                continue
            }
            
            # Get scope
            $scope = $null
            if ($assignment.scope.type -eq "ResourceGroup") {
                $rg = Get-AzResourceGroup -Name $assignment.scope.name -ErrorAction SilentlyContinue
                if ($rg) {
                    $scope = $rg.ResourceId
                }
            }
            
            if (-not $scope) {
                $testResult.Status = "FAILED"
                $testResult.Message = "Scope not found"
                Write-Log "  ❌ Scope not found" "ERROR"
                $testResults += $testResult
                continue
            }
            
            # Check if role assignment exists
            $roleAssignment = Get-AzRoleAssignment -ObjectId $principal.Id -RoleDefinitionName $assignment.role -Scope $scope -ErrorAction SilentlyContinue
            
            if ($roleAssignment) {
                $testResult.Status = "PASSED"
                $testResult.Message = "Role assignment exists"
                Write-Log "  ✓ Role assignment verified" "SUCCESS"
            }
            else {
                $testResult.Status = "FAILED"
                $testResult.Message = "Role assignment not found"
                Write-Log "  ❌ Role assignment missing" "ERROR"
            }
        }
        catch {
            $testResult.Status = "ERROR"
            $testResult.Message = $_.Exception.Message
            Write-Log "  ❌ Error: $_" "ERROR"
        }
        
        $testResults += $testResult
    }
    
    return $testResults
}

function Test-LeastPrivilege {
    Write-SectionHeader "Testing Least-Privilege Compliance"
    
    $issues = @()
    
    # Get all role assignments
    $rg = Get-AzResourceGroup -Name $ResourceGroupName
    $assignments = Get-AzRoleAssignment -Scope $rg.ResourceId
    
    # Check for over-privileged service principals
    $spOwners = $assignments | Where-Object { 
        $_.ObjectType -eq "ServicePrincipal" -and $_.RoleDefinitionName -eq "Owner" 
    }
    
    if ($spOwners.Count -gt 0) {
        Write-Log "⚠️ Found $($spOwners.Count) service principal(s) with Owner role" "WARNING"
        foreach ($sp in $spOwners) {
            Write-Log "  - $($sp.DisplayName)" "WARNING"
            $issues += "Service Principal '$($sp.DisplayName)' has Owner role (should use Contributor or less)"
        }
    }
    else {
        Write-Log "✓ No service principals with Owner role" "SUCCESS"
    }
    
    # Check for excessive Contributor assignments
    $contributors = $assignments | Where-Object { $_.RoleDefinitionName -eq "Contributor" }
    Write-Log "Found $($contributors.Count) Contributor role assignments" "INFO"
    
    # Check for User Access Administrator on service principals
    $uaaServicePrincipals = $assignments | Where-Object { 
        $_.ObjectType -eq "ServicePrincipal" -and $_.RoleDefinitionName -eq "User Access Administrator" 
    }
    
    if ($uaaServicePrincipals.Count -gt 0) {
        Write-Log "⚠️ Found $($uaaServicePrincipals.Count) service principal(s) with User Access Administrator role" "WARNING"
        foreach ($sp in $uaaServicePrincipals) {
            Write-Log "  - $($sp.DisplayName)" "WARNING"
            $issues += "Service Principal '$($sp.DisplayName)' has User Access Administrator role (high risk)"
        }
    }
    else {
        Write-Log "✓ No service principals with User Access Administrator role" "SUCCESS"
    }
    
    return $issues
}

function Show-TestSummary {
    param(
        [array]$TestResults,
        [array]$LeastPrivilegeIssues
    )
    
    Write-SectionHeader "Test Summary"
    
    $passed = ($TestResults | Where-Object { $_.Status -eq "PASSED" }).Count
    $failed = ($TestResults | Where-Object { $_.Status -eq "FAILED" }).Count
    $errors = ($TestResults | Where-Object { $_.Status -eq "ERROR" }).Count
    
    Write-Log "Total Tests: $($TestResults.Count)" "INFO"
    Write-Log "Passed: $passed" $(if ($passed -eq $TestResults.Count) { "SUCCESS" } else { "INFO" })
    Write-Log "Failed: $failed" $(if ($failed -gt 0) { "ERROR" } else { "INFO" })
    Write-Log "Errors: $errors" $(if ($errors -gt 0) { "ERROR" } else { "INFO" })
    Write-Log ""
    
    if ($ValidateLeastPrivilege) {
        Write-Log "Least-Privilege Issues: $($LeastPrivilegeIssues.Count)" $(if ($LeastPrivilegeIssues.Count -gt 0) { "WARNING" } else { "SUCCESS" })
        if ($LeastPrivilegeIssues.Count -gt 0) {
            foreach ($issue in $LeastPrivilegeIssues) {
                Write-Log "  - $issue" "WARNING"
            }
        }
    }
    
    # Failed tests detail
    if ($failed -gt 0) {
        Write-Log "" "INFO"
        Write-Log "Failed Tests:" "ERROR"
        $failedTests = $TestResults | Where-Object { $_.Status -eq "FAILED" }
        foreach ($test in $failedTests) {
            Write-Log "  - $($test.Principal) / $($test.Role): $($test.Message)" "ERROR"
        }
    }
}

################################################################################
# Main Execution
################################################################################

function Main {
    Write-SectionHeader "Azure RBAC Testing Script - $EnvName Environment"
    
    Write-Log "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Environment: $EnvName" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Configuration File: $ConfigFile" "INFO"
    
    # Test prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Exiting." "ERROR"
        exit 1
    }
    
    # Test configuration file
    if (-not (Test-ConfigurationFile)) {
        Write-Log "Configuration file test failed. Exiting." "ERROR"
        exit 1
    }
    
    # Load configuration
    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    
    # Test role assignments
    $testResults = Test-RoleAssignments -Config $config
    
    # Test least privilege if requested
    $leastPrivilegeIssues = @()
    if ($ValidateLeastPrivilege) {
        $leastPrivilegeIssues = Test-LeastPrivilege
    }
    
    # Show summary
    Show-TestSummary -TestResults $testResults -LeastPrivilegeIssues $leastPrivilegeIssues
    
    Write-SectionHeader "Testing Complete"
    Write-Log "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Log file: $LogFile" "INFO"
    
    # Exit with appropriate code
    $failed = ($testResults | Where-Object { $_.Status -ne "PASSED" }).Count
    if ($failed -gt 0 -or $leastPrivilegeIssues.Count -gt 0) {
        exit 1
    }
}

# Execute main function
Main
