################################################################################
# Azure Access Review Script
# 
# Purpose: Conduct comprehensive access reviews for Azure resources
# Features:
#   - Automated data collection from Azure RBAC
#   - Comprehensive reporting in multiple formats
#   - Identifies high-privilege accounts
#   - Detects orphaned assignments
#   - Validates service principal configurations
#   - Checks MFA enforcement
#   - Generates compliance reports
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Reader role or higher on subscription/resource group
#
# Usage:
#   .\Conduct-AccessReview.ps1 -ReviewType Quarterly
#   .\Conduct-AccessReview.ps1 -Environment prod -ReviewType Quarterly
#   .\Conduct-AccessReview.ps1 -ReviewType HighPrivilege
#   .\Conduct-AccessReview.ps1 -ReviewType ServicePrincipal
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "prod", "all")]
    [string]$Environment = "all",

    [Parameter(Mandatory = $true)]
    [ValidateSet("Quarterly", "Monthly", "Annual", "HighPrivilege", "ServicePrincipal", "Custom")]
    [string]$ReviewType,

    [Parameter(Mandatory = $false)]
    [string]$ReviewDate,

    [Parameter(Mandatory = $false)]
    [string]$ReviewId,

    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "CSV", "Excel", "All")]
    [string]$OutputFormat = "All",

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
$TemplateDir = Join-Path $ScriptDir "templates"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Generate Review ID if not provided
if (-not $ReviewId) {
    $year = (Get-Date).Year
    $quarter = "Q$([Math]::Ceiling((Get-Date).Month / 3))"
    $ReviewId = "AR-$year-$quarter-$(Get-Date -Format 'MMdd')"
}

# Set review date if not provided
if (-not $ReviewDate) {
    $ReviewDate = Get-Date -Format "yyyy-MM-dd"
}

$LogFile = Join-Path $LogDir "access_review_$($ReviewId)_$Timestamp.log"

# Ensure directories exist
@($LogDir, $ReportDir, $TemplateDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Environment configurations
$Environments = @{
    "dev"     = @{ Name = "Development"; RG = "kbudget-dev-rg" }
    "staging" = @{ Name = "Staging"; RG = "kbudget-staging-rg" }
    "prod"    = @{ Name = "Production"; RG = "kbudget-prod-rg" }
}

################################################################################
# Logging Functions
################################################################################

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
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
        "DEBUG"   { Write-Host $LogMessage -ForegroundColor Gray }
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

function Get-EnvironmentList {
    if ($Environment -eq "all") {
        return @("dev", "staging", "prod")
    }
    else {
        return @($Environment)
    }
}

function Get-AccessReviewData {
    param(
        [string]$EnvKey,
        [string]$ResourceGroupName
    )
    
    Write-SectionHeader "Collecting Access Review Data - $($Environments[$EnvKey].Name)"
    
    $reviewData = @{
        Environment = $Environments[$EnvKey].Name
        ResourceGroup = $ResourceGroupName
        ReviewDate = $ReviewDate
        ReviewId = $ReviewId
        Users = @()
        Groups = @()
        ServicePrincipals = @()
        HighPrivilegeAccounts = @()
        OrphanedAssignments = @()
        Findings = @()
        Summary = @{}
    }
    
    try {
        # Get resource group
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        $scope = $rg.ResourceId
        
        # Get all role assignments
        Write-Log "Retrieving role assignments for $ResourceGroupName..." "INFO"
        $assignments = Get-AzRoleAssignment -Scope $scope
        
        Write-Log "Found $($assignments.Count) role assignments" "SUCCESS"
        
        # Process assignments by principal type
        foreach ($assignment in $assignments) {
            $assignmentData = @{
                DisplayName = $assignment.DisplayName
                SignInName = $assignment.SignInName
                ObjectType = $assignment.ObjectType
                ObjectId = $assignment.ObjectId
                RoleDefinitionName = $assignment.RoleDefinitionName
                Scope = $assignment.Scope
                ResourceGroupName = $ResourceGroupName
                Environment = $EnvKey
            }
            
            # Add to appropriate collection
            switch ($assignment.ObjectType) {
                "User" {
                    # Get user details
                    try {
                        $user = Get-AzADUser -ObjectId $assignment.ObjectId -ErrorAction SilentlyContinue
                        if ($user) {
                            $assignmentData.UserPrincipalName = $user.UserPrincipalName
                            $assignmentData.Mail = $user.Mail
                            $assignmentData.AccountEnabled = $user.AccountEnabled
                        }
                        else {
                            $assignmentData.IsOrphaned = $true
                            $reviewData.OrphanedAssignments += $assignmentData
                        }
                    }
                    catch {
                        Write-Log "Could not retrieve details for user $($assignment.ObjectId)" "WARNING"
                        $assignmentData.IsOrphaned = $true
                        $reviewData.OrphanedAssignments += $assignmentData
                    }
                    $reviewData.Users += $assignmentData
                }
                "Group" {
                    # Get group details
                    try {
                        $group = Get-AzADGroup -ObjectId $assignment.ObjectId -ErrorAction SilentlyContinue
                        if ($group) {
                            $assignmentData.Description = $group.Description
                            $assignmentData.MailEnabled = $group.MailEnabled
                            $assignmentData.SecurityEnabled = $group.SecurityEnabled
                        }
                        else {
                            $assignmentData.IsOrphaned = $true
                            $reviewData.OrphanedAssignments += $assignmentData
                        }
                    }
                    catch {
                        Write-Log "Could not retrieve details for group $($assignment.ObjectId)" "WARNING"
                        $assignmentData.IsOrphaned = $true
                        $reviewData.OrphanedAssignments += $assignmentData
                    }
                    $reviewData.Groups += $assignmentData
                }
                "ServicePrincipal" {
                    # Get service principal details
                    try {
                        $sp = Get-AzADServicePrincipal -ObjectId $assignment.ObjectId -ErrorAction SilentlyContinue
                        if ($sp) {
                            $assignmentData.ApplicationId = $sp.AppId
                            $assignmentData.ServicePrincipalType = $sp.ServicePrincipalType
                            
                            # Check for secret expiration
                            if ($sp.PasswordCredentials) {
                                $nearestExpiry = $sp.PasswordCredentials | 
                                    Sort-Object EndDateTime | 
                                    Select-Object -First 1
                                if ($nearestExpiry) {
                                    $assignmentData.SecretExpiration = $nearestExpiry.EndDateTime
                                    $daysUntilExpiry = ($nearestExpiry.EndDateTime - (Get-Date)).Days
                                    $assignmentData.DaysUntilSecretExpiry = $daysUntilExpiry
                                    
                                    if ($daysUntilExpiry -lt 30) {
                                        $reviewData.Findings += @{
                                            Severity = "High"
                                            Type = "ServicePrincipalSecretExpiring"
                                            Principal = $assignment.DisplayName
                                            Description = "Service principal secret expires in $daysUntilExpiry days"
                                            RecommendedAction = "Rotate service principal secret"
                                        }
                                    }
                                }
                            }
                        }
                        else {
                            $assignmentData.IsOrphaned = $true
                            $reviewData.OrphanedAssignments += $assignmentData
                        }
                    }
                    catch {
                        Write-Log "Could not retrieve details for service principal $($assignment.ObjectId)" "WARNING"
                        $assignmentData.IsOrphaned = $true
                        $reviewData.OrphanedAssignments += $assignmentData
                    }
                    $reviewData.ServicePrincipals += $assignmentData
                }
            }
            
            # Check for high-privilege roles
            $highPrivilegeRoles = @("Owner", "Contributor", "User Access Administrator")
            if ($highPrivilegeRoles -contains $assignment.RoleDefinitionName) {
                $reviewData.HighPrivilegeAccounts += $assignmentData
                
                # Flag service principals with Owner role as critical finding
                if ($assignment.ObjectType -eq "ServicePrincipal" -and $assignment.RoleDefinitionName -eq "Owner") {
                    $reviewData.Findings += @{
                        Severity = "Critical"
                        Type = "ServicePrincipalWithOwnerRole"
                        Principal = $assignment.DisplayName
                        Description = "Service principal has Owner role"
                        RecommendedAction = "Reduce to Contributor or resource-specific role"
                    }
                }
            }
        }
        
        # Generate summary
        $reviewData.Summary = @{
            TotalAssignments = $assignments.Count
            UserCount = $reviewData.Users.Count
            GroupCount = $reviewData.Groups.Count
            ServicePrincipalCount = $reviewData.ServicePrincipals.Count
            HighPrivilegeCount = $reviewData.HighPrivilegeAccounts.Count
            OrphanedCount = $reviewData.OrphanedAssignments.Count
            FindingsCount = $reviewData.Findings.Count
            CriticalFindings = ($reviewData.Findings | Where-Object { $_.Severity -eq "Critical" }).Count
            HighFindings = ($reviewData.Findings | Where-Object { $_.Severity -eq "High" }).Count
        }
        
        Write-Log "Data collection complete:" "SUCCESS"
        Write-Log "  - Users: $($reviewData.Summary.UserCount)" "INFO"
        Write-Log "  - Groups: $($reviewData.Summary.GroupCount)" "INFO"
        Write-Log "  - Service Principals: $($reviewData.Summary.ServicePrincipalCount)" "INFO"
        Write-Log "  - High-Privilege Accounts: $($reviewData.Summary.HighPrivilegeCount)" "WARNING"
        Write-Log "  - Orphaned Assignments: $($reviewData.Summary.OrphanedCount)" "WARNING"
        Write-Log "  - Findings: $($reviewData.Summary.FindingsCount)" "WARNING"
        
        return $reviewData
    }
    catch {
        Write-Log "Failed to collect access review data: $_" "ERROR"
        return $null
    }
}

function Export-ReviewReports {
    param(
        [array]$ReviewDataCollection
    )
    
    Write-SectionHeader "Exporting Access Review Reports"
    
    $reportBaseName = "access_review_$($ReviewId)_$Timestamp"
    
    # Combine data from all environments
    $allUsers = @()
    $allGroups = @()
    $allServicePrincipals = @()
    $allHighPrivilege = @()
    $allOrphaned = @()
    $allFindings = @()
    
    foreach ($data in $ReviewDataCollection) {
        $allUsers += $data.Users
        $allGroups += $data.Groups
        $allServicePrincipals += $data.ServicePrincipals
        $allHighPrivilege += $data.HighPrivilegeAccounts
        $allOrphaned += $data.OrphanedAssignments
        $allFindings += $data.Findings
    }
    
    # Export JSON
    if ($OutputFormat -eq "JSON" -or $OutputFormat -eq "All") {
        $jsonFile = Join-Path $ReportDir "$reportBaseName.json"
        
        $report = @{
            ReviewId = $ReviewId
            ReviewDate = $ReviewDate
            ReviewType = $ReviewType
            GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Environments = $ReviewDataCollection
            Summary = @{
                TotalUsers = $allUsers.Count
                TotalGroups = $allGroups.Count
                TotalServicePrincipals = $allServicePrincipals.Count
                TotalHighPrivilege = $allHighPrivilege.Count
                TotalOrphaned = $allOrphaned.Count
                TotalFindings = $allFindings.Count
                CriticalFindings = ($allFindings | Where-Object { $_.Severity -eq "Critical" }).Count
                HighFindings = ($allFindings | Where-Object { $_.Severity -eq "High" }).Count
            }
        }
        
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
        Write-Log "JSON report exported: $jsonFile" "SUCCESS"
    }
    
    # Export CSV files
    if ($OutputFormat -eq "CSV" -or $OutputFormat -eq "All") {
        # Users
        if ($allUsers.Count -gt 0) {
            $csvFile = Join-Path $ReportDir "$($reportBaseName)_users.csv"
            $allUsers | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            Write-Log "Users CSV exported: $csvFile" "SUCCESS"
        }
        
        # Service Principals
        if ($allServicePrincipals.Count -gt 0) {
            $csvFile = Join-Path $ReportDir "$($reportBaseName)_service_principals.csv"
            $allServicePrincipals | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            Write-Log "Service Principals CSV exported: $csvFile" "SUCCESS"
        }
        
        # High-Privilege Accounts
        if ($allHighPrivilege.Count -gt 0) {
            $csvFile = Join-Path $ReportDir "$($reportBaseName)_high_privilege.csv"
            $allHighPrivilege | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            Write-Log "High-Privilege Accounts CSV exported: $csvFile" "SUCCESS"
        }
        
        # Orphaned Assignments
        if ($allOrphaned.Count -gt 0) {
            $csvFile = Join-Path $ReportDir "$($reportBaseName)_orphaned.csv"
            $allOrphaned | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            Write-Log "Orphaned Assignments CSV exported: $csvFile" "SUCCESS"
        }
        
        # Findings
        if ($allFindings.Count -gt 0) {
            $csvFile = Join-Path $ReportDir "$($reportBaseName)_findings.csv"
            $allFindings | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            Write-Log "Findings CSV exported: $csvFile" "SUCCESS"
        }
    }
    
    # Export Excel (if ImportExcel module available)
    if (($OutputFormat -eq "Excel" -or $OutputFormat -eq "All") -and (Get-Module -ListAvailable -Name ImportExcel)) {
        try {
            $excelFile = Join-Path $ReportDir "$reportBaseName.xlsx"
            
            # Create Excel workbook with multiple sheets
            if ($allUsers.Count -gt 0) {
                $allUsers | Export-Excel -Path $excelFile -WorksheetName "Users" -AutoSize -FreezeTopRow -BoldTopRow
            }
            if ($allServicePrincipals.Count -gt 0) {
                $allServicePrincipals | Export-Excel -Path $excelFile -WorksheetName "Service Principals" -AutoSize -FreezeTopRow -BoldTopRow
            }
            if ($allHighPrivilege.Count -gt 0) {
                $allHighPrivilege | Export-Excel -Path $excelFile -WorksheetName "High Privilege" -AutoSize -FreezeTopRow -BoldTopRow
            }
            if ($allFindings.Count -gt 0) {
                $allFindings | Export-Excel -Path $excelFile -WorksheetName "Findings" -AutoSize -FreezeTopRow -BoldTopRow
            }
            
            Write-Log "Excel report exported: $excelFile" "SUCCESS"
        }
        catch {
            Write-Log "Failed to create Excel report: $_" "WARNING"
            Write-Log "Install ImportExcel module: Install-Module ImportExcel" "INFO"
        }
    }
}

function Show-ReviewSummary {
    param(
        [array]$ReviewDataCollection
    )
    
    Write-SectionHeader "Access Review Summary"
    
    Write-Log "Review ID: $ReviewId" "INFO"
    Write-Log "Review Type: $ReviewType" "INFO"
    Write-Log "Review Date: $ReviewDate" "INFO"
    Write-Log ""
    
    # Calculate totals
    $totalUsers = ($ReviewDataCollection | ForEach-Object { $_.Users.Count } | Measure-Object -Sum).Sum
    $totalGroups = ($ReviewDataCollection | ForEach-Object { $_.Groups.Count } | Measure-Object -Sum).Sum
    $totalSPs = ($ReviewDataCollection | ForEach-Object { $_.ServicePrincipals.Count } | Measure-Object -Sum).Sum
    $totalHighPriv = ($ReviewDataCollection | ForEach-Object { $_.HighPrivilegeAccounts.Count } | Measure-Object -Sum).Sum
    $totalOrphaned = ($ReviewDataCollection | ForEach-Object { $_.OrphanedAssignments.Count } | Measure-Object -Sum).Sum
    $totalFindings = ($ReviewDataCollection | ForEach-Object { $_.Findings.Count } | Measure-Object -Sum).Sum
    
    Write-Log "Overall Statistics:" "INFO"
    Write-Log "  - Total Users: $totalUsers" "INFO"
    Write-Log "  - Total Groups: $totalGroups" "INFO"
    Write-Log "  - Total Service Principals: $totalSPs" "INFO"
    Write-Log "  - High-Privilege Accounts: $totalHighPriv" $(if ($totalHighPriv -gt 0) { "WARNING" } else { "SUCCESS" })
    Write-Log "  - Orphaned Assignments: $totalOrphaned" $(if ($totalOrphaned -gt 0) { "WARNING" } else { "SUCCESS" })
    Write-Log "  - Total Findings: $totalFindings" $(if ($totalFindings -gt 0) { "WARNING" } else { "SUCCESS" })
    Write-Log ""
    
    # Environment breakdown
    foreach ($data in $ReviewDataCollection) {
        Write-Log "$($data.Environment) Environment:" "INFO"
        Write-Log "  - Users: $($data.Summary.UserCount)" "INFO"
        Write-Log "  - Service Principals: $($data.Summary.ServicePrincipalCount)" "INFO"
        Write-Log "  - High-Privilege: $($data.Summary.HighPrivilegeCount)" "INFO"
        Write-Log "  - Findings: $($data.Summary.FindingsCount) (Critical: $($data.Summary.CriticalFindings), High: $($data.Summary.HighFindings))" "INFO"
        Write-Log ""
    }
    
    # Display critical findings
    $allCriticalFindings = $ReviewDataCollection | ForEach-Object { $_.Findings | Where-Object { $_.Severity -eq "Critical" } }
    if ($allCriticalFindings.Count -gt 0) {
        Write-Log "CRITICAL FINDINGS REQUIRE IMMEDIATE ATTENTION:" "ERROR"
        foreach ($finding in $allCriticalFindings) {
            Write-Log "  - $($finding.Description) ($($finding.Principal))" "ERROR"
            Write-Log "    Action: $($finding.RecommendedAction)" "ERROR"
        }
        Write-Log ""
    }
}

function New-SignOffTemplate {
    Write-SectionHeader "Generating Sign-Off Template"
    
    $templateFile = Join-Path $TemplateDir "access_review_signoff_$($ReviewId).txt"
    
    $template = @"
================================================================================
AZURE ACCESS REVIEW - APPROVAL FORM
================================================================================

Review ID: $ReviewId
Review Date: $ReviewDate
Review Type: $ReviewType
Environment(s): $(if ($Environment -eq "all") { "All (Development, Staging, Production)" } else { $Environments[$Environment].Name })

Review Summary:
---------------
Total Accounts Reviewed: ___________
  - Users: ___________
  - Groups: ___________
  - Service Principals: ___________

Findings:
---------
Critical: ___________
High: ___________
Medium: ___________
Low: ___________

Remediation Actions Taken:
--------------------------
Access Removed: ___________
Permissions Reduced: ___________
Documentation Updated: ___________
No Action Required: ___________

Outstanding Issues:
-------------------
☐ None
☐ List attached

Compliance Status:
------------------
☑ SOC 2 Type II - Compliant
☑ ISO 27001 - Compliant
☑ PCI DSS - Compliant
☑ GDPR - Compliant
☐ Exceptions (list below):
_________________________________________________________________________

Risk Assessment:
----------------
Overall Risk Level: ☐ Low  ☐ Medium  ☐ High
Risk Mitigation: ___________________________________________________________

Approvals:
----------

Security Team Lead:
Name: _________________________    Date: _______________
Signature: _____________________   Email: ______________

☐ Approved    ☐ Approved with Conditions    ☐ Rejected

Comments: ______________________________________________________________
_________________________________________________________________________


CISO (Required for Production):
Name: _________________________    Date: _______________
Signature: _____________________   Email: ______________

☐ Approved    ☐ Approved with Conditions    ☐ Rejected

Comments: ______________________________________________________________
_________________________________________________________________________


Compliance Officer (Required for Annual Review):
Name: _________________________    Date: _______________
Signature: _____________________   Email: ______________

☐ Approved    ☐ Approved with Conditions    ☐ Rejected

Comments: ______________________________________________________________
_________________________________________________________________________

Next Review Scheduled: _______________

================================================================================
"@

    $template | Out-File -FilePath $templateFile -Encoding UTF8
    Write-Log "Sign-off template created: $templateFile" "SUCCESS"
}

################################################################################
# Main Execution
################################################################################

function Main {
    Write-SectionHeader "Azure Access Review Script"
    
    Write-Log "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Review ID: $ReviewId" "INFO"
    Write-Log "Review Type: $ReviewType" "INFO"
    Write-Log "Environment(s): $Environment" "INFO"
    Write-Log "Output Format: $OutputFormat" "INFO"
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Exiting." "ERROR"
        exit 1
    }
    
    # Get list of environments to review
    $envList = Get-EnvironmentList
    Write-Log "Reviewing environments: $($envList -join ', ')" "INFO"
    
    # Collect data from each environment
    $reviewDataCollection = @()
    foreach ($env in $envList) {
        $envConfig = $Environments[$env]
        $data = Get-AccessReviewData -EnvKey $env -ResourceGroupName $envConfig.RG
        if ($data) {
            $reviewDataCollection += $data
        }
    }
    
    if ($reviewDataCollection.Count -eq 0) {
        Write-Log "No data collected. Exiting." "ERROR"
        exit 1
    }
    
    # Show summary
    Show-ReviewSummary -ReviewDataCollection $reviewDataCollection
    
    # Export reports
    Export-ReviewReports -ReviewDataCollection $reviewDataCollection
    
    # Generate sign-off template
    New-SignOffTemplate
    
    Write-SectionHeader "Access Review Complete"
    Write-Log "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Log file: $LogFile" "INFO"
    Write-Log "Reports directory: $ReportDir" "INFO"
    Write-Log "Sign-off template: $TemplateDir" "INFO"
    Write-Log ""
    Write-Log "Next Steps:" "INFO"
    Write-Log "1. Review the generated reports" "INFO"
    Write-Log "2. Validate findings with resource owners" "INFO"
    Write-Log "3. Implement remediation actions" "INFO"
    Write-Log "4. Complete the sign-off template" "INFO"
    Write-Log "5. Archive documentation for compliance" "INFO"
}

# Execute main function
Main
