# Audit Log Retention Compliance Validation Guide

## Overview

This guide provides step-by-step procedures for validating audit log retention compliance for the KBudget GPT Azure infrastructure. It ensures all critical resources meet regulatory and security requirements.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Validation Procedures](#validation-procedures)
3. [Compliance Check Steps](#compliance-check-steps)
4. [Remediation Procedures](#remediation-procedures)
5. [Report Generation](#report-generation)
6. [Security Team Review](#security-team-review)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Azure PowerShell Module (Az)** - Version 9.0 or higher
- **Azure Account** - With appropriate permissions
- **Access Permissions** - Contributor or Owner role on resource groups

### Required Permissions

| Resource | Required Role | Purpose |
|----------|---------------|---------|
| Resource Groups | Contributor | Read and update diagnostic settings |
| Log Analytics Workspace | Log Analytics Contributor | Verify workspace configuration |
| All monitored resources | Monitoring Contributor | Configure diagnostic settings |

### Setup Instructions

```powershell
# 1. Install Azure PowerShell module (if not already installed)
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# 2. Login to Azure
Connect-AzAccount

# 3. Verify correct subscription
Get-AzContext

# 4. If needed, set the correct subscription
Set-AzContext -SubscriptionId "<subscription-id>"

# 5. Verify you have access to the resource groups
Get-AzResourceGroup -Name "kbudget-*-rg"
```

## Validation Procedures

### Quick Validation (Read-Only)

This validates current state without making any changes:

```powershell
cd /home/runner/work/KBudget_GPT/KBudget_GPT/infrastructure/arm-templates/diagnostic-settings

# Validate development environment
.\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly

# Validate staging environment
.\Set-AuditLogRetention.ps1 -Environment staging -ValidateOnly

# Validate production environment
.\Set-AuditLogRetention.ps1 -Environment prod -ValidateOnly
```

**Expected Output:**
- List of all resources analyzed
- Compliance status for each resource
- Any issues found with retention policies
- Overall compliance percentage

### Dry-Run Mode (What-If Analysis)

Preview changes that would be made without actually applying them:

```powershell
# See what changes would be made to development
.\Set-AuditLogRetention.ps1 -Environment dev -WhatIf

# See what changes would be made to production
.\Set-AuditLogRetention.ps1 -Environment prod -WhatIf
```

**Use Cases:**
- Before applying changes to production
- Understanding impact of policy updates
- Planning maintenance windows

### Apply Retention Policies

Apply the organizational retention policies to all resources:

```powershell
# Apply to development (safe to test first)
.\Set-AuditLogRetention.ps1 -Environment dev

# Apply to staging
.\Set-AuditLogRetention.ps1 -Environment staging

# Apply to production (after testing and approval)
.\Set-AuditLogRetention.ps1 -Environment prod
```

**Important Notes:**
- Always test on dev/staging first
- Review WhatIf output before production
- Obtain change approval for production
- Schedule during maintenance window if possible

## Compliance Check Steps

### Step 1: Pre-Check Verification

Before running compliance validation:

```powershell
# 1. Verify policy file exists and is valid
$policyPath = ".\audit-retention-policy.json"
Test-Path $policyPath

# 2. Verify policy content
Get-Content $policyPath | ConvertFrom-Json | Format-List

# 3. Check current Azure context
Get-AzContext | Format-List

# 4. Verify resource group exists
Get-AzResourceGroup -Name "kbudget-dev-rg"
```

### Step 2: Run Compliance Validation

Execute validation for each environment:

```powershell
# Development
.\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly -GenerateReport

# Staging
.\Set-AuditLogRetention.ps1 -Environment staging -ValidateOnly -GenerateReport

# Production
.\Set-AuditLogRetention.ps1 -Environment prod -ValidateOnly -GenerateReport
```

### Step 3: Review Validation Results

Check the console output:

```
========================================
Compliance Summary
========================================
Total Resources Analyzed: 10
Compliant Resources: 8
Non-Compliant Resources: 2
Compliance Rate: 80%
========================================
```

### Step 4: Analyze Compliance Reports

Reports are generated in the `outputs` directory:

```powershell
# View latest reports
Get-ChildItem .\outputs\ -Filter "compliance-report-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 3

# Open HTML report in browser
$latestReport = Get-ChildItem .\outputs\ -Filter "compliance-report-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Start-Process $latestReport.FullName
```

## Remediation Procedures

### Automatic Remediation

For non-compliant resources, apply fixes automatically:

```powershell
# Apply fixes to development
.\Set-AuditLogRetention.ps1 -Environment dev

# Verify fixes were applied
.\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly
```

### Manual Remediation

If automatic remediation fails or for complex issues:

#### Fix Missing Diagnostic Settings

```powershell
# Example: Configure diagnostic settings for an App Service
$resourceId = "/subscriptions/.../providers/Microsoft.Web/sites/myapp"
$workspaceId = "/subscriptions/.../providers/Microsoft.OperationalInsights/workspaces/myworkspace"

Set-AzDiagnosticSetting `
    -ResourceId $resourceId `
    -Name "default" `
    -WorkspaceId $workspaceId `
    -Enabled $true `
    -Log @(
        @{Category='AppServiceHTTPLogs'; Enabled=$true; RetentionPolicy=@{Enabled=$true; Days=90}}
        @{Category='AppServiceAuditLogs'; Enabled=$true; RetentionPolicy=@{Enabled=$true; Days=180}}
    )
```

#### Fix Insufficient Retention

```powershell
# Get current diagnostic settings
$currentSettings = Get-AzDiagnosticSetting -ResourceId $resourceId

# Update retention for specific log category
# (Update the specific category with new retention period)
```

### Verification After Remediation

```powershell
# Re-run validation to confirm all issues are resolved
.\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly -GenerateReport

# Should show 100% compliance
```

## Report Generation

### Generate Compliance Reports

```powershell
# Generate report for all environments
.\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly -GenerateReport
.\Set-AuditLogRetention.ps1 -Environment staging -ValidateOnly -GenerateReport
.\Set-AuditLogRetention.ps1 -Environment prod -ValidateOnly -GenerateReport
```

### Report Formats

The script generates two report formats:

#### 1. JSON Report
- **Location:** `outputs/compliance-report-{env}-{timestamp}.json`
- **Purpose:** Machine-readable, detailed data
- **Use:** Automated compliance tracking, integration with tools

#### 2. HTML Report
- **Location:** `outputs/compliance-report-{env}-{timestamp}.html`
- **Purpose:** Human-readable, visual presentation
- **Use:** Security team review, executive summaries

### Report Contents

Each report includes:

1. **Executive Summary**
   - Environment name
   - Report timestamp
   - Policy version
   - Overall compliance rate

2. **Resource Summary**
   - Total resources analyzed
   - Compliant resource count
   - Non-compliant resource count

3. **Resource Details**
   - Individual resource status
   - Specific compliance issues
   - Expected vs. actual configurations

4. **Compliance Frameworks**
   - SOC 2, ISO 27001, GDPR, HIPAA, PCI DSS

5. **Next Steps**
   - Remediation recommendations
   - Review schedule
   - Approval requirements

## Security Team Review

### Review Process

1. **Generate Reports**
   ```powershell
   # Generate reports for all environments
   .\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly -GenerateReport
   .\Set-AuditLogRetention.ps1 -Environment staging -ValidateOnly -GenerateReport
   .\Set-AuditLogRetention.ps1 -Environment prod -ValidateOnly -GenerateReport
   ```

2. **Package Reports**
   ```powershell
   # Create review package
   $reviewDate = Get-Date -Format "yyyyMMdd"
   $packagePath = ".\outputs\compliance-review-$reviewDate"
   New-Item -ItemType Directory -Path $packagePath -Force
   
   # Copy all reports
   Copy-Item ".\outputs\compliance-report-dev-*.html" $packagePath
   Copy-Item ".\outputs\compliance-report-staging-*.html" $packagePath
   Copy-Item ".\outputs\compliance-report-prod-*.html" $packagePath
   Copy-Item ".\audit-retention-policy.json" $packagePath
   ```

3. **Submit for Review**
   - Email review package to: security-team@organization.com
   - Include: All HTML reports, policy file, summary memo
   - Request: Review and sign-off within 5 business days

4. **Review Checklist for Security Team**

   - [ ] All critical resources have diagnostic settings configured
   - [ ] Log retention meets or exceeds policy requirements
   - [ ] Audit logs (180+ days) are properly configured
   - [ ] Critical audit logs (365+ days) are properly configured
   - [ ] All compliance framework requirements are met
   - [ ] No high-severity compliance issues remain
   - [ ] Log Analytics workspace has adequate retention
   - [ ] Backup and archival policies are in place

5. **Sign-Off Process**

   Create a sign-off document:

   ```
   COMPLIANCE SIGN-OFF FORM
   
   Project: KBudget GPT Audit Log Retention
   Review Date: [DATE]
   Reviewer: [SECURITY TEAM MEMBER NAME]
   Approver: [CISO NAME]
   
   Compliance Status:
   - Development: [X] COMPLIANT [ ] NON-COMPLIANT
   - Staging: [X] COMPLIANT [ ] NON-COMPLIANT
   - Production: [X] COMPLIANT [ ] NON-COMPLIANT
   
   Frameworks Validated:
   - [X] SOC 2 Type II
   - [X] ISO 27001
   - [X] GDPR
   - [X] HIPAA
   - [X] PCI DSS
   
   Outstanding Issues: [NONE / LIST ISSUES]
   
   Recommendation: [APPROVE / CONDITIONAL APPROVE / REJECT]
   
   Reviewer Signature: _________________ Date: _______
   Approver Signature: _________________ Date: _______
   ```

## Troubleshooting

### Common Issues

#### Issue 1: "Not logged in to Azure"

**Error:**
```
Not logged in to Azure. Please run Connect-AzAccount first.
```

**Solution:**
```powershell
Connect-AzAccount
```

#### Issue 2: "Resource group not found"

**Error:**
```
Resource group not found: kbudget-dev-rg
```

**Solutions:**
1. Verify resource group exists:
   ```powershell
   Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "kbudget-*" }
   ```

2. Check if using correct subscription:
   ```powershell
   Get-AzContext
   Set-AzContext -SubscriptionId "<correct-subscription-id>"
   ```

3. Verify you have permissions:
   ```powershell
   Get-AzRoleAssignment -ResourceGroupName "kbudget-dev-rg"
   ```

#### Issue 3: "Policy file not found"

**Error:**
```
Policy file not found: audit-retention-policy.json
```

**Solution:**
```powershell
# Verify you're in the correct directory
Get-Location

# Should be in diagnostic-settings folder
cd /home/runner/work/KBudget_GPT/KBudget_GPT/infrastructure/arm-templates/diagnostic-settings

# Verify file exists
Test-Path .\audit-retention-policy.json
```

#### Issue 4: "Unable to retrieve diagnostic settings"

**Error:**
```
Unable to retrieve diagnostic settings for [ResourceId]
```

**Possible Causes:**
1. Insufficient permissions
2. Resource doesn't support diagnostic settings
3. API throttling

**Solutions:**
1. Verify permissions:
   ```powershell
   Get-AzRoleAssignment -Scope $resourceId
   ```

2. Check if resource type is supported:
   - App Service: Supported
   - SQL Database: Supported
   - Storage Account: Supported
   - Function App: Supported
   - Key Vault: Supported

3. Add retry logic or wait and re-run

#### Issue 5: Low compliance rate

**Scenario:** Compliance rate is below 100%

**Investigation Steps:**

1. Review the compliance report:
   ```powershell
   # Open latest HTML report
   $report = Get-ChildItem .\outputs\ -Filter "*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   Start-Process $report.FullName
   ```

2. Identify non-compliant resources from the report

3. Check specific resource:
   ```powershell
   $resourceId = "/subscriptions/.../resourceGroups/kbudget-dev-rg/providers/Microsoft.Web/sites/myapp"
   Get-AzDiagnosticSetting -ResourceId $resourceId
   ```

4. Apply automatic remediation:
   ```powershell
   .\Set-AuditLogRetention.ps1 -Environment dev
   ```

5. Verify compliance after remediation:
   ```powershell
   .\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly
   ```

### Getting Help

If you encounter issues not covered here:

1. **Check Azure Service Health:**
   ```powershell
   Get-AzResourceHealth
   ```

2. **Review Azure Activity Logs:**
   ```powershell
   Get-AzLog -ResourceGroupName "kbudget-dev-rg" -MaxRecord 10
   ```

3. **Contact Support:**
   - Internal: devops-team@organization.com
   - Azure Support: Open ticket in Azure Portal

## Maintenance Schedule

### Regular Compliance Checks

- **Frequency:** Monthly
- **Schedule:** First Monday of each month
- **Owner:** DevOps Team
- **Procedure:** Run validation and generate reports

### Policy Review

- **Frequency:** Quarterly
- **Schedule:** As defined in policy file
- **Owner:** Security and Governance Team
- **Procedure:** Review and update retention policies as needed

### Annual Audit

- **Frequency:** Annually
- **Schedule:** Q1 of each year
- **Owner:** CISO
- **Procedure:** Comprehensive compliance audit with external auditor

## References

- [Organizational Audit Retention Policy](./audit-retention-policy.json)
- [Azure Diagnostic Settings Documentation](https://docs.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
- [Azure Monitor Best Practices](https://docs.microsoft.com/azure/azure-monitor/best-practices)
- [Compliance Frameworks Documentation](../../docs/COMPLIANCE-DOCUMENTATION.md)
