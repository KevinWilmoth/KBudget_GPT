# PowerShell Deployment Validation and Testing

This document provides comprehensive information about the validation and testing capabilities for PowerShell deployment scripts in the KBudget GPT project.

## Table of Contents

1. [Overview](#overview)
2. [Built-in Validation](#built-in-validation)
3. [Automated Testing](#automated-testing)
4. [CI/CD Pipeline Integration](#cicd-pipeline-integration)
5. [Alert and Error Handling](#alert-and-error-handling)
6. [Usage Examples](#usage-examples)
7. [Troubleshooting](#troubleshooting)

## Overview

The deployment validation system ensures that all Azure resources are deployed correctly and detects failed or partial deployments. The system includes:

- **Post-deployment validation** - Verifies that all resources were created successfully
- **Status checking** - Monitors deployment status and resource health
- **Output collection** - Captures and stores deployment results and resource IDs
- **Automated testing** - Pester-based unit tests for deployment scripts
- **CI/CD integration** - GitHub Actions workflow for continuous validation
- **Automated alerts** - Notifications for critical failures

## Built-in Validation

### Deployment Validation Module

The `Deployment-Validation.psm1` module provides comprehensive validation functions:

#### Resource Validation Functions

```powershell
# Import the validation module
Import-Module ./Deployment-Validation.psm1

# Validate individual resources
$rgStatus = Test-ResourceGroupExists -ResourceGroupName "kbudget-dev-rg"
$vnetStatus = Test-VirtualNetworkExists -ResourceGroupName "kbudget-dev-rg" -VNetName "kbudget-dev-vnet"
$kvStatus = Test-KeyVaultExists -ResourceGroupName "kbudget-dev-rg" -KeyVaultName "kbudget-dev-kv"
$storageStatus = Test-StorageAccountExists -ResourceGroupName "kbudget-dev-rg" -StorageAccountName "kbudgetdevstorage"
$cosmosStatus = Test-CosmosDBAccountExists -ResourceGroupName "kbudget-dev-rg" -AccountName "kbudget-dev-cosmos"
$appStatus = Test-AppServiceExists -ResourceGroupName "kbudget-dev-rg" -AppServiceName "kbudget-dev-app"
$funcStatus = Test-FunctionAppExists -ResourceGroupName "kbudget-dev-rg" -FunctionAppName "kbudget-dev-func"
```

#### Comprehensive Deployment Validation

```powershell
# Validate all deployed resources for an environment
$validationResults = Test-DeploymentResources -Environment "dev" -ResourceTypes @("all")

# Check validation status
if ($validationResults.OverallStatus -eq "Success") {
    Write-Host "All resources validated successfully!"
} else {
    Write-Host "Validation failed for some resources"
}

# Access individual resource status
foreach ($resourceType in $validationResults.Resources.Keys) {
    $resource = $validationResults.Resources[$resourceType]
    Write-Host "$resourceType - Exists: $($resource.Exists)"
}
```

#### Deployment Status Tracking

```powershell
# Get deployment status for a resource group deployment
$status = Get-DeploymentStatus -ResourceGroupName "kbudget-dev-rg" -DeploymentName "vnet-deployment-20240207"

# Get deployment status for a subscription-level deployment
$status = Get-DeploymentStatus -DeploymentName "rg-deployment-dev-20240207" -IsSubscriptionDeployment
```

### Enhanced Deploy-AzureResources.ps1

The deployment script now includes automatic validation:

```powershell
# Deploy resources with automatic validation
.\Deploy-AzureResources.ps1 -Environment dev

# Deployment process includes:
# 1. Prerequisites check
# 2. Resource deployment
# 3. Post-deployment validation
# 4. Output export
# 5. Alert sending (if failures detected)
```

### Output Collection and Storage

Deployment results are automatically exported to JSON files:

**Output Location**: `infrastructure/arm-templates/main-deployment/outputs/`

**Files Created**:
- `deployment-results_{environment}_{timestamp}.json` - Timestamped deployment results
- `deployment-results_{environment}_latest.json` - Latest deployment results (easy reference)

**Output Structure**:
```json
{
  "Environment": "dev",
  "Timestamp": "20240207_143000",
  "DeploymentTime": "2024-02-07 14:30:00",
  "ResourceGroupName": "kbudget-dev-rg",
  "Location": "eastus",
  "ResourcesDeployed": ["ResourceGroup", "VNet", "KeyVault", "Storage", "SqlDatabase", "AppService", "Functions"],
  "DeploymentDetails": {
    "VNet": {
      "DeploymentName": "vnet-deployment-20240207",
      "ProvisioningState": "Succeeded",
      "Timestamp": "2024-02-07 14:25:00",
      "Outputs": {
        "vnetId": "/subscriptions/.../resourceGroups/kbudget-dev-rg/providers/Microsoft.Network/virtualNetworks/kbudget-dev-vnet",
        "vnetName": "kbudget-dev-vnet"
      }
    }
  }
}
```

### Validation Summary Report

After each deployment, a comprehensive validation summary is displayed:

```
================================================================================
DEPLOYMENT VALIDATION SUMMARY
================================================================================
Environment:        dev
Resource Group:     kbudget-dev-rg
Validation Time:    2024-02-07 14:30:00
Overall Status:     Success

RESOURCE STATUS:
--------------------------------------------------------------------------------
ResourceGroup: ✓ DEPLOYED
  Resource ID: /subscriptions/.../resourceGroups/kbudget-dev-rg

VNet: ✓ DEPLOYED
  Resource ID: /subscriptions/.../Microsoft.Network/virtualNetworks/kbudget-dev-vnet

KeyVault: ✓ DEPLOYED
  Resource ID: /subscriptions/.../Microsoft.KeyVault/vaults/kbudget-dev-kv

Storage: ✓ DEPLOYED
  Resource ID: /subscriptions/.../Microsoft.Storage/storageAccounts/kbudgetdevstorage

CosmosDB: ✓ DEPLOYED
  Resource ID: /subscriptions/.../Microsoft.DocumentDB/databaseAccounts/kbudget-dev-cosmos

AppService: ✓ DEPLOYED
  Resource ID: /subscriptions/.../Microsoft.Web/sites/kbudget-dev-app

Functions: ✓ DEPLOYED
  Resource ID: /subscriptions/.../Microsoft.Web/sites/kbudget-dev-func

================================================================================
```

## Automated Testing

### Pester Tests

The `Deploy-AzureResources.Tests.ps1` file contains comprehensive Pester tests:

#### Installing Pester

```powershell
# Install Pester (version 5.0 or higher)
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser
```

#### Running Tests Locally

```powershell
# Navigate to the deployment scripts directory
cd infrastructure/arm-templates/main-deployment

# Run all tests
Invoke-Pester -Path Deploy-AzureResources.Tests.ps1

# Run tests with detailed output
$config = New-PesterConfiguration
$config.Run.Path = "Deploy-AzureResources.Tests.ps1"
$config.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $config

# Run tests and export results
$config = New-PesterConfiguration
$config.Run.Path = "Deploy-AzureResources.Tests.ps1"
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "test-results.xml"
Invoke-Pester -Configuration $config
```

#### Test Coverage

The Pester tests cover:

1. **Script File Validation**
   - File existence
   - PowerShell syntax validation
   - CmdletBinding and parameter validation

2. **Function Validation**
   - Required functions exist
   - Function signatures are correct
   - Parameter validation attributes

3. **Error Handling**
   - Try-catch blocks present
   - ErrorActionPreference set
   - Exit codes on errors

4. **Logging**
   - Write-Log function exists
   - Log directory creation
   - Logging of deployment status

5. **Validation Integration**
   - Post-deployment validation calls
   - Output export functionality
   - Alert mechanism

6. **Module Tests**
   - Deployment-Validation module syntax
   - Exported functions
   - Function parameters

## CI/CD Pipeline Integration

### GitHub Actions Workflow

The `.github/workflows/powershell-deployment-validation.yml` workflow runs automatically on:

- **Push to main or develop branches** (when deployment scripts change)
- **Pull requests** (when deployment scripts change)
- **Manual trigger** (workflow_dispatch)

### Workflow Jobs

#### 1. Validate Scripts Job

Validates PowerShell scripts and runs tests:

- ✓ PowerShell syntax validation
- ✓ Pester unit tests
- ✓ ARM template validation
- ✓ Required functions check
- ✓ Validation module verification
- ✓ Test results upload
- ✓ Validation report generation

#### 2. Security Scan Job

Scans for security issues and best practices:

- ✓ PSScriptAnalyzer (static code analysis)
- ✓ Hardcoded secrets detection
- ✓ Best practices validation

#### 3. Notify Status Job

Provides final status notification:

- ✓ Overall validation status
- ✓ Security scan status
- ✓ Success/failure notification

### Viewing CI/CD Results

1. Navigate to your repository on GitHub
2. Click on the **Actions** tab
3. Select the **PowerShell Deployment Validation** workflow
4. View the results of each job
5. Download artifacts (test results, validation reports)

### Manual Workflow Trigger

```bash
# Trigger the workflow manually via GitHub CLI
gh workflow run powershell-deployment-validation.yml

# Or use the GitHub UI:
# Actions → PowerShell Deployment Validation → Run workflow
```

## Alert and Error Handling

### Automated Alerts

The deployment system includes automated alerting for critical failures:

```powershell
# Alerts are automatically sent when:
# 1. Deployment fails during execution
# 2. Post-deployment validation fails
# 3. Critical resources are missing

# Alert levels:
# - Info: Informational messages
# - Warning: Non-critical issues
# - Critical: Deployment failures requiring attention
```

### Alert Structure

```powershell
# Alert message includes:
{
    "Timestamp": "2024-02-07T14:30:00Z",
    "Environment": "dev",
    "Status": "Failed",
    "AlertLevel": "Critical",
    "FailedResources": [
        {
            "ResourceType": "SqlServer",
            "Error": "Resource not found after deployment"
        }
    ]
}
```

### Extensible Alert System

The alert system can be extended to send notifications via:

- **Email** (using Send-MailMessage or SendGrid)
- **Slack** (using webhooks)
- **Teams** (using webhooks)
- **Azure Monitor** (using Azure alerts)

Example extension:

```powershell
function Send-DeploymentAlert {
    param(
        [object]$ValidationResults,
        [string]$AlertLevel = "Warning"
    )
    
    # ... existing code ...
    
    # Add Slack webhook notification
    if ($env:SLACK_WEBHOOK_URL) {
        $slackMessage = @{
            text = "Deployment Alert: $($ValidationResults.OverallStatus)"
            attachments = @(
                @{
                    color = if ($ValidationResults.OverallStatus -eq "Failed") { "danger" } else { "good" }
                    fields = @(
                        @{
                            title = "Environment"
                            value = $ValidationResults.Environment
                            short = $true
                        },
                        @{
                            title = "Alert Level"
                            value = $AlertLevel
                            short = $true
                        }
                    )
                }
            )
        }
        
        Invoke-RestMethod -Uri $env:SLACK_WEBHOOK_URL -Method Post -Body ($slackMessage | ConvertTo-Json -Depth 10) -ContentType 'application/json'
    }
}
```

## Usage Examples

### Example 1: Standard Deployment with Validation

```powershell
# Deploy all resources to development environment
.\Deploy-AzureResources.ps1 -Environment dev

# The script will:
# 1. Check prerequisites
# 2. Deploy all resources
# 3. Validate deployed resources
# 4. Export deployment results
# 5. Display validation summary
# 6. Exit with code 0 (success) or 1 (failure)
```

### Example 2: WhatIf Mode

```powershell
# Preview what would be deployed without making changes
.\Deploy-AzureResources.ps1 -Environment dev -WhatIf

# Validation is skipped in WhatIf mode
```

### Example 3: Partial Deployment with Validation

```powershell
# Deploy only VNet and Storage
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("vnet", "storage")

# Validation will only check VNet and Storage resources
```

### Example 4: Manual Validation

```powershell
# Import the validation module
Import-Module ./Deployment-Validation.psm1

# Validate specific environment
$results = Test-DeploymentResources -Environment "staging" -ResourceTypes @("all")

# Display summary
Write-DeploymentSummary -ValidationResults $results -LogFile "validation.log"

# Send alert if validation failed
if ($results.OverallStatus -eq "Failed") {
    Send-DeploymentAlert -ValidationResults $results -AlertLevel "Critical"
}
```

### Example 5: Checking Deployment Status

```powershell
# Check status of a specific deployment
Import-Module ./Deployment-Validation.psm1

$status = Get-DeploymentStatus `
    -ResourceGroupName "kbudget-dev-rg" `
    -DeploymentName "vnet-deployment-20240207"

Write-Host "Provisioning State: $($status.ProvisioningState)"
Write-Host "Duration: $($status.Duration) minutes"

if ($status.Status -eq "Failed") {
    Write-Host "Error: $($status.Error)"
}
```

## Troubleshooting

### Common Issues

#### Issue: Validation Module Not Found

**Error**: `Validation module not found - skipping post-deployment validation`

**Solution**:
```powershell
# Ensure Deployment-Validation.psm1 exists in the same directory
ls infrastructure/arm-templates/main-deployment/Deployment-Validation.psm1

# If missing, restore from source control
git checkout infrastructure/arm-templates/main-deployment/Deployment-Validation.psm1
```

#### Issue: Pester Tests Fail

**Error**: `Pester tests failed! Failed count: X`

**Solution**:
```powershell
# Run tests with detailed output to see specific failures
$config = New-PesterConfiguration
$config.Run.Path = "Deploy-AzureResources.Tests.ps1"
$config.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $config

# Fix the reported issues and re-run tests
```

#### Issue: Validation Reports False Negatives

**Error**: Resource shows as missing but was actually deployed

**Solution**:
```powershell
# Check if resource naming follows expected pattern
# Expected names:
# - Resource Group: kbudget-{env}-rg
# - VNet: kbudget-{env}-vnet
# - Key Vault: kbudget-{env}-kv
# - Storage: kbudget{env}storage (no hyphens)
# - Cosmos DB Account: kbudget-{env}-cosmos
# - App Service: kbudget-{env}-app
# - Function App: kbudget-{env}-func

# Manually verify resource exists
Get-AzResource -ResourceGroupName "kbudget-dev-rg" | Select-Object Name, ResourceType
```

#### Issue: CI/CD Workflow Fails

**Error**: GitHub Actions workflow fails on certain steps

**Solution**:
```bash
# Check the workflow run logs in GitHub Actions
# Common issues:
# 1. PowerShell syntax errors - Fix syntax in scripts
# 2. Missing dependencies - Ensure Pester is installed
# 3. Permission issues - Check repository settings

# View workflow logs
gh run list --workflow=powershell-deployment-validation.yml
gh run view <run-id> --log
```

#### Issue: Deployment Succeeds but Validation Fails

**Error**: `Deployment validation FAILED - Some resources are missing or misconfigured`

**Solution**:
```powershell
# This usually indicates a timing issue or partial deployment
# 1. Wait a few minutes for Azure to fully provision resources
# 2. Run validation manually to verify
Import-Module ./Deployment-Validation.psm1
$results = Test-DeploymentResources -Environment "dev"
Write-DeploymentSummary -ValidationResults $results

# 3. Check deployment outputs for errors
cat infrastructure/arm-templates/main-deployment/outputs/deployment-results_dev_latest.json

# 4. Check Azure Portal for resource status
```

### Getting Help

For additional help:

1. Check the [PowerShell Deployment Guide](../../../docs/POWERSHELL-DEPLOYMENT-GUIDE.md)
2. Review deployment logs in `infrastructure/arm-templates/main-deployment/logs/`
3. Check GitHub Actions workflow runs for detailed error messages
4. Review Azure Portal for resource deployment status

### Best Practices

1. **Always run WhatIf first** - Preview changes before deploying
2. **Monitor CI/CD results** - Check GitHub Actions after every commit
3. **Review validation summaries** - Ensure all resources deployed successfully
4. **Keep logs** - Archive deployment logs for troubleshooting
5. **Test locally** - Run Pester tests before committing changes
6. **Use version control** - Commit deployment outputs for history

---

**Last Updated**: 2024-02-07
**Version**: 1.0.0
