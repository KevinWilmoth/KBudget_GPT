# Azure Resource Group Cleanup Scripts

This directory contains automated cleanup scripts for managing Azure Resource Groups lifecycle in the KBudget GPT project.

## Overview

The cleanup automation helps manage costs and maintain a tidy Azure environment by automatically identifying and deleting old or non-production resource groups based on configurable criteria.

## Safety Features

- **Production Protection**: Production resource groups are ALWAYS protected from deletion
- **Dry-Run Default**: Scripts run in dry-run mode by default, showing what would be deleted without actually deleting
- **Detailed Logging**: All operations are logged with timestamps for audit and troubleshooting
- **Confirmation Required**: Actual deletions require explicit user confirmation

## Files

| File | Purpose |
|------|---------|
| `delete-resource-group.json` | ARM template for resource group deletion operations |
| `Cleanup-ResourceGroups.ps1` | PowerShell script for automated cleanup based on tags, age, or environment |
| `CLEANUP-README.md` | This file - Documentation for cleanup scripts |

## Prerequisites

### PowerShell Script

1. **PowerShell**: Version 5.0 or higher (PowerShell 7+ recommended)
2. **Azure PowerShell Module**: Az.Resources module
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   ```
3. **Azure Authentication**: Active Azure session
   ```powershell
   Connect-AzAccount
   ```
4. **Permissions**: Contributor or Owner role at subscription level

### ARM Template

1. **Azure CLI**: Install from [here](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **Azure Subscription**: Active Azure subscription
3. **Permissions**: Contributor or Owner role at subscription level

## Authentication

### PowerShell

```powershell
# Connect to Azure
Connect-AzAccount

# Set the correct subscription (if you have multiple)
Set-AzContext -Subscription "<subscription-id-or-name>"

# Verify the current context
Get-AzContext
```

### Azure CLI

```bash
# Login to Azure
az login

# Set the correct subscription
az account set --subscription "<subscription-id-or-name>"

# Verify the current subscription
az account show
```

## Usage

### PowerShell Cleanup Script

#### Basic Usage - Dry Run (Safe)

Show what would be deleted without actually deleting:

```powershell
# Show all non-production resource groups older than 90 days
./Cleanup-ResourceGroups.ps1

# Show Development resource groups older than 30 days
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30

# Show Staging resource groups older than 60 days
./Cleanup-ResourceGroups.ps1 -Environment Staging -OlderThanDays 60 -DryRun

# Include resource groups without CreatedDate tag
./Cleanup-ResourceGroups.ps1 -IncludeUntagged
```

#### Actual Deletion (Requires Confirmation)

Perform actual deletion (requires typing 'DELETE' to confirm):

```powershell
# Delete Development resource groups older than 30 days
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30 -DryRun:$false

# Delete all non-production resource groups older than 180 days
./Cleanup-ResourceGroups.ps1 -Environment All -OlderThanDays 180 -DryRun:$false

# Delete Staging resource groups older than 90 days, including untagged
./Cleanup-ResourceGroups.ps1 -Environment Staging -OlderThanDays 90 -DryRun:$false -IncludeUntagged
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Environment` | String | `All` | Filter by environment tag: Development, Staging, QA, Demo, Sandbox, All |
| `OlderThanDays` | Integer | `90` | Delete resource groups older than specified days (1-3650) |
| `DryRun` | Switch | `$true` | When true, only shows what would be deleted |
| `LogPath` | String | `./logs` | Path to log file directory |
| `IncludeUntagged` | Switch | `$false` | Include resource groups without CreatedDate tag |

#### Examples

**Example 1: Review before deleting**
```powershell
# Step 1: Dry run to see what would be deleted
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 45

# Review the output and log file

# Step 2: If satisfied, perform actual deletion
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 45 -DryRun:$false
```

**Example 2: Cleanup old demo environments**
```powershell
# Delete Demo resource groups older than 14 days
./Cleanup-ResourceGroups.ps1 -Environment Demo -OlderThanDays 14 -DryRun:$false
```

**Example 3: Quarterly cleanup**
```powershell
# Delete all non-production resource groups older than 6 months
./Cleanup-ResourceGroups.ps1 -OlderThanDays 180 -DryRun:$false
```

**Example 4: Cleanup with untagged resources**
```powershell
# Include resource groups without proper tagging
./Cleanup-ResourceGroups.ps1 -Environment All -OlderThanDays 120 -IncludeUntagged -DryRun:$false
```

### ARM Template for Deletion

The ARM template provides a declarative way to delete resource groups:

```bash
# Deploy the deletion template (still requires actual az group delete command)
az deployment sub create \
  --name delete-old-rg \
  --location eastus \
  --template-file delete-resource-group.json \
  --parameters resourceGroupName="kbudget-demo-rg" deleteConfirmation="true"
```

**Note**: The ARM template marks resource groups for deletion but doesn't execute the deletion. Use the PowerShell script for automated cleanup or Azure CLI for manual deletion:

```bash
# Manual deletion with Azure CLI
az group delete --name <resource-group-name> --yes --no-wait
```

## Cleanup Criteria

The PowerShell script identifies resource groups for cleanup based on:

### 1. Environment Tag

Resource groups are filtered by their `Environment` tag:
- **Eligible for cleanup**: Development, Staging, QA, Demo, Sandbox
- **Protected**: Production (NEVER deleted by automation)

### 2. Age (CreatedDate Tag)

Resource groups are evaluated based on their `CreatedDate` tag:
- Default threshold: 90 days
- Configurable via `-OlderThanDays` parameter
- Resource groups without `CreatedDate` tag are skipped unless `-IncludeUntagged` is specified

### 3. Untagged Resources

By default, resource groups without proper tags are skipped. Use `-IncludeUntagged` to include them in cleanup.

## Logging

All operations are logged with detailed timestamps:

### Log Location

Logs are stored in the `logs/` directory with the naming pattern:
```
logs/cleanup_YYYYMMDD_HHMMSS.log
```

### Log Content

Each log entry includes:
- Timestamp
- Log level (Info, Success, Warning, Error)
- Detailed message

Example log entries:
```
[Info] 2026-02-07 10:30:15 - Execution started
[Info] 2026-02-07 10:30:16 - Found 42 total resource groups in subscription
[Warning] 2026-02-07 10:30:17 - Skipping kbudget-prod-rg - Protected environment: Production
[Info] 2026-02-07 10:30:18 - Found 5 resource groups matching cleanup criteria
[Success] 2026-02-07 10:30:25 - Successfully initiated deletion of kbudget-demo-old-rg
```

### Viewing Logs

```powershell
# View most recent log
Get-Content ./logs/cleanup_*.log | Select-Object -Last 50

# View specific log
Get-Content ./logs/cleanup_20260207_103015.log

# Search for errors
Get-Content ./logs/cleanup_*.log | Select-String -Pattern "ERROR"
```

## Production Protection

**CRITICAL SAFETY FEATURE**: Production resource groups are ALWAYS protected.

The script includes multiple safeguards:

1. **Environment Tag Check**: Any resource group with `Environment=Production` is automatically skipped
2. **Protected Environments List**: Configured in the script to prevent accidental deletion
3. **Logging**: All skipped production resource groups are logged with warnings

Example protection log:
```
[Warning] 2026-02-07 10:30:17 - Skipping kbudget-prod-rg - Protected environment: Production
```

## Best Practices

### 1. Always Start with Dry Run

```powershell
# First, see what would be deleted
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30

# Review the output and logs

# Then, if satisfied, perform actual deletion
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30 -DryRun:$false
```

### 2. Regular Cleanup Schedule

Consider setting up a regular cleanup schedule:
- **Weekly**: Delete Demo/Sandbox resources older than 14 days
- **Monthly**: Delete Development resources older than 60 days
- **Quarterly**: Delete Staging/QA resources older than 90 days

### 3. Proper Tagging

Ensure all resource groups have proper tags:
- `Environment`: Development, Staging, Production, QA, Demo, Sandbox
- `CreatedDate`: ISO date format (YYYY-MM-DD)
- Other tags as defined in [Azure Resource Group Best Practices](../../../docs/azure-resource-group-best-practices.md)

### 4. Log Review

Regularly review cleanup logs for:
- Unexpected deletions
- Failed operations
- Protected resource groups being targeted
- Untagged resource groups

### 5. Test in Lower Environments

Before running cleanup in production subscription:
1. Test the script in a test/dev subscription
2. Verify dry-run output
3. Review logs thoroughly
4. Confirm deletion behavior

## Scheduled Automation

### Azure Automation Runbook

Create an Azure Automation runbook for scheduled cleanup:

```powershell
# Example runbook content
param(
    [int]$OlderThanDays = 90,
    [string]$Environment = 'All'
)

# Connect using managed identity or service principal
Connect-AzAccount -Identity

# Run cleanup
./Cleanup-ResourceGroups.ps1 `
    -Environment $Environment `
    -OlderThanDays $OlderThanDays `
    -DryRun:$false `
    -IncludeUntagged
```

Schedule the runbook to run:
- Daily for Demo/Sandbox cleanup
- Weekly for Development cleanup
- Monthly for Staging/QA cleanup

### GitHub Actions

Automate cleanup via GitHub Actions:

```yaml
name: Cleanup Azure Resources

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM UTC
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Run Cleanup Script
        shell: pwsh
        run: |
          cd infrastructure/arm-templates/resource-groups
          ./Cleanup-ResourceGroups.ps1 -Environment All -OlderThanDays 90 -DryRun:$false
```

### Azure DevOps Pipeline

```yaml
trigger: none

schedules:
  - cron: '0 2 * * 0'
    displayName: Weekly cleanup
    branches:
      include:
        - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzurePowerShell@5
    inputs:
      azureSubscription: 'Azure-Service-Connection'
      scriptType: 'FilePath'
      scriptPath: 'infrastructure/arm-templates/resource-groups/Cleanup-ResourceGroups.ps1'
      scriptArguments: '-Environment All -OlderThanDays 90 -DryRun:$false'
      azurePowerShellVersion: 'LatestVersion'
```

## Troubleshooting

### Common Issues

**Issue**: "Script cannot be loaded because running scripts is disabled"
```powershell
# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Issue**: "Az.Resources module not found"
```powershell
# Solution: Install Az module
Install-Module -Name Az -AllowClobber -Scope CurrentUser
Import-Module Az.Resources
```

**Issue**: "Not connected to Azure"
```powershell
# Solution: Connect to Azure
Connect-AzAccount
Set-AzContext -Subscription "<subscription-id>"
```

**Issue**: "Insufficient permissions to delete resource group"
- **Solution**: Ensure you have Contributor or Owner role at subscription level

**Issue**: "Resource group deletion failed"
- Check if there are locks on the resource group
- Verify there are no resources that prevent deletion
- Check Azure Activity Log for detailed error messages

### Verification

Check deletion status in Azure:

```powershell
# List all resource groups
Get-AzResourceGroup | Select-Object ResourceGroupName, Location, ProvisioningState

# Check deletion jobs
Get-Job

# View specific resource group
Get-AzResourceGroup -Name "<resource-group-name>"
```

Using Azure CLI:

```bash
# List resource groups
az group list --query "[].{Name:name, Location:location, State:properties.provisioningState}" --output table

# Check if specific group exists
az group exists --name "<resource-group-name>"
```

## Security Considerations

1. **Credentials**: Never commit Azure credentials to source control
2. **Service Principals**: Use least-privilege service principals for automation
3. **Audit Logs**: Enable and review Azure Activity Logs for all deletions
4. **Backups**: Ensure critical resources are backed up before cleanup
5. **Resource Locks**: Use Azure resource locks on critical production resources

## Related Documentation

- [Azure Resource Group Naming Conventions](../../../docs/azure-resource-group-naming-conventions.md)
- [Azure Resource Group Best Practices](../../../docs/azure-resource-group-best-practices.md)
- [Resource Group Deployment README](README.md)
- [Azure Resource Manager Documentation](https://docs.microsoft.com/azure/azure-resource-manager/)
- [Azure PowerShell Documentation](https://docs.microsoft.com/powershell/azure/)

## Support

For questions or issues:
- **DevOps Team**: devops-team@company.com
- **Document Owner**: Kevin Wilmoth
- **GitHub Issues**: [Submit an issue](../../issues)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-07 | Initial release with ARM template and PowerShell cleanup script |
