# PowerShell Deployment Guide for KBudget GPT

This comprehensive guide covers all PowerShell scripts used for deploying and managing Azure infrastructure in the KBudget GPT project.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Authentication & Setup](#authentication--setup)
4. [PowerShell Scripts Reference](#powershell-scripts-reference)
   - [Deploy-AzureResources.ps1](#deploy-azureresourcesps1)
   - [Validate-Templates.ps1](#validate-templatesps1)
   - [Cleanup-ResourceGroups.ps1](#cleanup-resourcegroupsps1)
5. [Common Workflows](#common-workflows)
6. [Environment Settings](#environment-settings)
7. [Parameters Guide](#parameters-guide)
8. [Error Handling](#error-handling)
9. [Troubleshooting](#troubleshooting)
10. [CI/CD Integration](#cicd-integration)
11. [Best Practices](#best-practices)

---

## Overview

The KBudget GPT project includes three major PowerShell scripts for infrastructure deployment and management:

| Script | Location | Purpose |
|--------|----------|---------|
| **Deploy-AzureResources.ps1** | `infrastructure/arm-templates/main-deployment/` | Deploys all Azure resources (VNet, Key Vault, Storage, SQL, App Service, Functions) |
| **Validate-Templates.ps1** | `infrastructure/arm-templates/main-deployment/` | Validates ARM templates and parameter files for syntax and schema compliance |
| **Cleanup-ResourceGroups.ps1** | `infrastructure/arm-templates/resource-groups/` | Automated cleanup of old or non-production resource groups |

### Key Features

✅ **Multi-Environment Support**: Deploy to dev, staging, or production  
✅ **Idempotent Deployments**: Safe to run multiple times  
✅ **Comprehensive Validation**: Pre-deployment checks and template validation  
✅ **Security-First**: Secrets in Key Vault, TLS 1.2, HTTPS only  
✅ **Detailed Logging**: Timestamped logs for all operations  
✅ **Production Protection**: Automated safeguards for production resources

---

## Prerequisites

### Required Software

#### 1. PowerShell

**Windows PowerShell 5.1+** or **PowerShell 7.0+** (recommended)

```powershell
# Check your PowerShell version
$PSVersionTable.PSVersion
```

**Installation (PowerShell 7)**:
- Windows: `winget install Microsoft.PowerShell`
- macOS: `brew install powershell`
- Linux: Follow [Microsoft's guide](https://docs.microsoft.com/powershell/scripting/install/installing-powershell)

#### 2. Azure PowerShell Module (Az)

```powershell
# Install Az module
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Verify installation
Get-Module -ListAvailable -Name Az

# Import the module
Import-Module Az
```

**Required Az submodules**:
- `Az.Resources` - For resource group and ARM template deployments
- `Az.Accounts` - For authentication
- `Az.KeyVault` - For Key Vault operations
- `Az.Storage` - For storage operations
- `Az.Sql` - For SQL database operations
- `Az.Network` - For virtual network operations
- `Az.Websites` - For App Service operations

#### 3. Azure CLI (Optional)

Useful for quick checks and alternative deployment methods:

```bash
# Windows
winget install Microsoft.AzureCLI

# macOS
brew install azure-cli

# Linux (Ubuntu/Debian)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Azure Requirements

1. **Active Azure Subscription**
2. **Permissions**: Contributor or Owner role at subscription level
3. **Resource Quotas**: Ensure sufficient quotas for:
   - Virtual Networks
   - Public IP addresses
   - Storage accounts
   - SQL databases
   - App Service plans

### Connection Requirements

- **Internet Access**: Required for Azure API calls
- **Network Rules**: Ensure firewall/proxy allows Azure endpoints
- **DNS Resolution**: Must resolve Azure DNS names

### Execution Policy

Set execution policy to allow script execution:

```powershell
# Windows: Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Check current policy
Get-ExecutionPolicy -List
```

---

## Authentication & Setup

### Initial Azure Login

```powershell
# Login to Azure (opens browser for authentication)
Connect-AzAccount

# Login with specific tenant
Connect-AzAccount -TenantId "<tenant-id>"

# Login with service principal (automation)
$credential = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId "<tenant-id>"
```

### Select Subscription

```powershell
# List all subscriptions
Get-AzSubscription

# Set active subscription by name
Set-AzContext -SubscriptionName "Your Subscription Name"

# Set active subscription by ID
Set-AzContext -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Verify current context
Get-AzContext | Format-List
```

### Save Context (Optional)

```powershell
# Save context for future sessions
Save-AzContext -Path "$HOME/.azure/profile.json"

# Load saved context
Import-AzContext -Path "$HOME/.azure/profile.json"
```

### Verify Prerequisites

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Check Az module
Get-Module -ListAvailable Az

# Check Azure connection
Get-AzContext

# Check permissions
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id | 
    Where-Object { $_.Scope -like "/subscriptions/*" }
```

---

## PowerShell Scripts Reference

### Deploy-AzureResources.ps1

**Location**: `infrastructure/arm-templates/main-deployment/Deploy-AzureResources.ps1`

**Purpose**: Main orchestration script for deploying all Azure resources.

#### Synopsis

Deploys the complete Azure infrastructure including Resource Groups, Virtual Network, Key Vault, Storage Account, SQL Database, App Service, and Azure Functions.

#### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Environment` | String | Yes | - | Target environment: `dev`, `staging`, or `prod` |
| `Location` | String | No | `eastus` | Azure region for resources |
| `ResourceTypes` | Array | No | `@("all")` | Resource types to deploy |
| `WhatIf` | Switch | No | `$false` | Preview changes without deploying |
| `SkipResourceGroup` | Switch | No | `$false` | Skip resource group deployment |

#### Usage Examples

**Basic Deployment**:
```powershell
# Navigate to deployment directory
cd infrastructure/arm-templates/main-deployment

# Deploy all resources to development
.\Deploy-AzureResources.ps1 -Environment dev

# Deploy to staging
.\Deploy-AzureResources.ps1 -Environment staging

# Deploy to production
.\Deploy-AzureResources.ps1 -Environment prod
```

**Advanced Usage**:
```powershell
# Deploy only specific resources
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("vnet", "storage")

# Deploy to different region
.\Deploy-AzureResources.ps1 -Environment dev -Location westus2

# Preview deployment (WhatIf mode)
.\Deploy-AzureResources.ps1 -Environment dev -WhatIf

# Skip resource group creation (if already exists)
.\Deploy-AzureResources.ps1 -Environment dev -SkipResourceGroup
```

#### Available Resource Types

- `all` - Deploy all resources (default)
- `vnet` - Virtual Network
- `keyvault` - Key Vault
- `storage` - Storage Account
- `sql` - SQL Database
- `appservice` - App Service
- `functions` - Azure Functions

#### Output

The script outputs:
- Deployment progress with color-coded messages
- Resource IDs and connection information
- Log file location
- Deployment summary

#### Logs

Logs are created in `infrastructure/arm-templates/main-deployment/logs/`:
```
deployment_dev_20260207_103045.log
deployment_staging_20260207_150833.log
deployment_prod_20260207_153045.log
```

---

### Validate-Templates.ps1

**Location**: `infrastructure/arm-templates/main-deployment/Validate-Templates.ps1`

**Purpose**: Validates ARM templates and parameter files before deployment.

#### Synopsis

Validates JSON syntax, ARM template schema, and parameter file compatibility for all or specific resource types.

#### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ResourceType` | String | No | `all` | Resource type to validate |

#### Valid Resource Types

- `all` - Validate all templates (default)
- `app-service` - App Service templates
- `sql-database` - SQL Database templates
- `storage-account` - Storage Account templates
- `azure-functions` - Azure Functions templates
- `key-vault` - Key Vault templates
- `virtual-network` - Virtual Network templates

#### Usage Examples

**Validate All Templates**:
```powershell
# Navigate to deployment directory
cd infrastructure/arm-templates/main-deployment

# Validate all templates and parameter files
.\Validate-Templates.ps1

# Or explicitly specify all
.\Validate-Templates.ps1 -ResourceType all
```

**Validate Specific Resource**:
```powershell
# Validate only App Service templates
.\Validate-Templates.ps1 -ResourceType app-service

# Validate only SQL Database templates
.\Validate-Templates.ps1 -ResourceType sql-database

# Validate only Key Vault templates
.\Validate-Templates.ps1 -ResourceType key-vault
```

#### What Gets Validated

For each resource type, the script validates:

1. **Template File Existence**
   - Checks if the `.json` template file exists

2. **JSON Syntax**
   - Validates proper JSON formatting
   - Detects syntax errors

3. **ARM Template Schema**
   - Verifies `$schema` field exists
   - Checks for `resources` array

4. **Parameter Files**
   - Validates existence of environment-specific parameter files:
     - `parameters.dev.json`
     - `parameters.staging.json`
     - `parameters.prod.json`
   - Validates JSON syntax of each parameter file

5. **PowerShell Script Syntax**
   - Validates `Deploy-AzureResources.ps1` for PowerShell syntax errors

#### Output

The script provides:
- ✓ Green checkmarks for passed tests
- ✗ Red X marks for failed tests
- Detailed error messages for failures
- Summary statistics (Total, Passed, Failed)

**Example Output**:
```
=== ARM Template Validation ===
Script Directory: C:\...\main-deployment

Validating App Service...
✓ App Service template exists
✓ App Service template has valid JSON syntax
✓ App Service template has schema
✓ App Service template has resources
✓ App Service dev parameter file exists
✓ App Service dev parameter file has valid JSON
✓ App Service staging parameter file exists
✓ App Service staging parameter file has valid JSON
✓ App Service prod parameter file exists
✓ App Service prod parameter file has valid JSON

=== Validation Summary ===
Total Tests: 42
Passed: 42
Failed: 0

✓ All validation tests passed!
```

#### Exit Codes

- `0` - All validations passed
- `1` - One or more validations failed

#### When to Use

Run this script:
- **Before deployments** to catch errors early
- **After template changes** to verify modifications
- **In CI/CD pipelines** for automated validation
- **During PR reviews** to validate infrastructure code

---

### Cleanup-ResourceGroups.ps1

**Location**: `infrastructure/arm-templates/resource-groups/Cleanup-ResourceGroups.ps1`

**Purpose**: Automated cleanup of old or non-production resource groups based on tags and age.

#### Synopsis

Identifies and deletes Azure Resource Groups based on environment tags and age criteria. Includes safety features to protect production resources.

#### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Environment` | String | No | `All` | Filter by environment tag |
| `OlderThanDays` | Integer | No | `90` | Delete groups older than specified days (1-3650) |
| `DryRun` | Switch | No | `$true` | Preview mode (no actual deletion) |
| `LogPath` | String | No | `./logs` | Log file directory path |
| `IncludeUntagged` | Switch | No | `$false` | Include resource groups without CreatedDate tag |

#### Valid Environment Values

- `All` - All non-production environments (default)
- `Development` - Development environment only
- `Staging` - Staging environment only
- `QA` - QA environment only
- `Demo` - Demo environment only
- `Sandbox` - Sandbox environment only

**Note**: Production is ALWAYS protected and cannot be selected.

#### Usage Examples

**Dry Run (Safe Preview)**:
```powershell
# Navigate to resource groups directory
cd infrastructure/arm-templates/resource-groups

# Preview all non-production groups older than 90 days
.\Cleanup-ResourceGroups.ps1

# Preview Development groups older than 30 days
.\Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30

# Preview with untagged resources included
.\Cleanup-ResourceGroups.ps1 -IncludeUntagged
```

**Actual Deletion**:
```powershell
# Delete Development groups older than 30 days (requires confirmation)
.\Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30 -DryRun:$false

# Delete all non-production groups older than 180 days
.\Cleanup-ResourceGroups.ps1 -OlderThanDays 180 -DryRun:$false

# Delete Demo groups older than 14 days
.\Cleanup-ResourceGroups.ps1 -Environment Demo -OlderThanDays 14 -DryRun:$false
```

#### Safety Features

1. **Production Protection**: Production resource groups are NEVER deleted
2. **Dry-Run Default**: Safe preview mode is the default
3. **Confirmation Required**: Actual deletion requires typing "DELETE"
4. **Detailed Logging**: All operations logged with timestamps
5. **Tag-Based Filtering**: Only deletes tagged resources unless explicitly included

#### Cleanup Criteria

Resource groups are identified for cleanup based on:

1. **Environment Tag**:
   - Must have `Environment` tag
   - Must be non-production (Development, Staging, QA, Demo, Sandbox)
   - Production is ALWAYS excluded

2. **Age (CreatedDate Tag)**:
   - Based on `CreatedDate` tag
   - Default: 90 days
   - Configurable via `-OlderThanDays`

3. **Untagged Resources**:
   - By default, skipped
   - Include with `-IncludeUntagged`

#### Output

The script provides:
- List of resource groups matching criteria
- Age and environment information
- Deletion confirmation prompt (if not dry run)
- Operation summary
- Log file location

#### Logs

Logs are created in `infrastructure/arm-templates/resource-groups/logs/`:
```
cleanup_20260207_103015.log
cleanup_20260207_150833.log
```

---

## Common Workflows

### 1. Initial Environment Setup

Complete workflow for setting up a new environment:

```powershell
# Step 1: Authenticate
Connect-AzAccount
Set-AzContext -SubscriptionName "Your Subscription"

# Step 2: Validate templates
cd infrastructure/arm-templates/main-deployment
.\Validate-Templates.ps1

# Step 3: Preview deployment
.\Deploy-AzureResources.ps1 -Environment dev -WhatIf

# Step 4: Deploy (if validation passes)
.\Deploy-AzureResources.ps1 -Environment dev

# Step 5: Verify deployment
Get-AzResource -ResourceGroupName "kbudget-dev-rg" | Format-Table
```

### 2. Update Existing Environment

Workflow for updating an existing environment:

```powershell
# Step 1: Validate changes
cd infrastructure/arm-templates/main-deployment
.\Validate-Templates.ps1

# Step 2: Preview changes
.\Deploy-AzureResources.ps1 -Environment dev -WhatIf

# Step 3: Apply changes (idempotent)
.\Deploy-AzureResources.ps1 -Environment dev

# Step 4: Review logs
Get-Content .\logs\deployment_*.log -Tail 50
```

### 3. Deploy Specific Resource

Workflow for deploying or updating a specific resource:

```powershell
# Step 1: Validate specific resource template
cd infrastructure/arm-templates/main-deployment
.\Validate-Templates.ps1 -ResourceType sql-database

# Step 2: Deploy only that resource
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("sql") -SkipResourceGroup

# Step 3: Verify resource
Get-AzSqlServer -ResourceGroupName "kbudget-dev-rg"
```

### 4. Environment Cleanup

Workflow for cleaning up old resources:

```powershell
# Step 1: Preview what would be deleted (dry run)
cd infrastructure/arm-templates/resource-groups
.\Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 45

# Step 2: Review the output and logs
Get-Content .\logs\cleanup_*.log -Tail 50

# Step 3: Perform actual deletion (if satisfied)
.\Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 45 -DryRun:$false

# Step 4: Verify deletion
Get-AzResourceGroup | Where-Object { $_.Tags.Environment -eq "Development" }
```

### 5. Multi-Environment Deployment

Workflow for deploying to multiple environments:

```powershell
cd infrastructure/arm-templates/main-deployment

# Validate once for all environments
.\Validate-Templates.ps1

# Deploy to dev
.\Deploy-AzureResources.ps1 -Environment dev

# Test and verify dev deployment
# ... run tests ...

# Deploy to staging (after dev verification)
.\Deploy-AzureResources.ps1 -Environment staging

# Test and verify staging
# ... run tests ...

# Deploy to production (after staging verification)
.\Deploy-AzureResources.ps1 -Environment prod
```

### 6. Disaster Recovery

Workflow for redeploying after a disaster:

```powershell
# Step 1: Authenticate
Connect-AzAccount
Set-AzContext -SubscriptionName "Your Subscription"

# Step 2: Verify templates are valid
cd infrastructure/arm-templates/main-deployment
.\Validate-Templates.ps1

# Step 3: Redeploy all resources (idempotent)
.\Deploy-AzureResources.ps1 -Environment prod

# Step 4: Restore data from backups
# ... restore SQL database ...
# ... restore storage blobs ...

# Step 5: Verify all services
Get-AzResource -ResourceGroupName "kbudget-prod-rg" | Format-Table
```

---

## Environment Settings

### Environment-Specific Configuration

Each environment has its own parameter files located in resource-specific directories:

```
infrastructure/arm-templates/
├── app-service/
│   ├── parameters.dev.json
│   ├── parameters.staging.json
│   └── parameters.prod.json
├── sql-database/
│   ├── parameters.dev.json
│   ├── parameters.staging.json
│   └── parameters.prod.json
└── ... (similar for other resources)
```

### Environment Characteristics

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **Cost** | Minimal | Moderate | Optimized |
| **SKU** | Basic/Free | Standard | Premium |
| **Redundancy** | None | LRS | GRS/RA-GRS |
| **Backup** | Optional | Yes | Yes (extended retention) |
| **Monitoring** | Basic | Standard | Advanced |
| **Alerts** | Minimal | Yes | Yes (24/7) |
| **Auto-scale** | No | Optional | Yes |

### Resource Naming by Environment

| Resource Type | Development | Staging | Production |
|---------------|-------------|---------|------------|
| Resource Group | `kbudget-dev-rg` | `kbudget-staging-rg` | `kbudget-prod-rg` |
| Virtual Network | `kbudget-dev-vnet` | `kbudget-staging-vnet` | `kbudget-prod-vnet` |
| Key Vault | `kbudget-dev-kv` | `kbudget-staging-kv` | `kbudget-prod-kv` |
| Storage | `kbudgetdevst` | `kbudgetstagingst` | `kbudgetprodst` |
| SQL Server | `kbudget-dev-sql` | `kbudget-staging-sql` | `kbudget-prod-sql` |
| App Service | `kbudget-dev-app` | `kbudget-staging-app` | `kbudget-prod-app` |
| Functions | `kbudget-dev-func` | `kbudget-staging-func` | `kbudget-prod-func` |

### Environment Tags

All resources are tagged with:

```json
{
  "Environment": "Development|Staging|Production",
  "Project": "KBudget GPT",
  "ManagedBy": "ARM Template",
  "CreatedDate": "2026-02-07",
  "CostCenter": "Engineering",
  "Owner": "DevOps Team"
}
```

---

## Parameters Guide

### Common Parameters Across Scripts

#### Environment Parameter

Specifies the target environment:

```powershell
# Valid values
-Environment dev        # Development
-Environment staging    # Staging
-Environment prod       # Production
```

#### WhatIf Parameter

Preview mode without making changes:

```powershell
# Enable preview mode
-WhatIf
-WhatIf:$true

# Disable preview mode (default)
-WhatIf:$false
```

#### Verbose Output

Enable detailed output:

```powershell
# Enable verbose output
.\Deploy-AzureResources.ps1 -Environment dev -Verbose

# Use PowerShell preference variable
$VerbosePreference = 'Continue'
.\Deploy-AzureResources.ps1 -Environment dev
```

### Deploy-AzureResources.ps1 Parameters

**Location**:
```powershell
# Use different Azure region
-Location westus2
-Location northeurope
-Location centralus
```

**ResourceTypes**:
```powershell
# Deploy specific resources (array)
-ResourceTypes @("vnet", "storage")
-ResourceTypes @("keyvault", "sql")
-ResourceTypes @("appservice", "functions")
```

**SkipResourceGroup**:
```powershell
# Skip resource group deployment
-SkipResourceGroup
```

### Cleanup-ResourceGroups.ps1 Parameters

**OlderThanDays**:
```powershell
# Custom age threshold (1-3650 days)
-OlderThanDays 30
-OlderThanDays 180
-OlderThanDays 365
```

**DryRun**:
```powershell
# Dry run (preview only) - DEFAULT
-DryRun
-DryRun:$true

# Actual deletion
-DryRun:$false
```

**IncludeUntagged**:
```powershell
# Include untagged resource groups
-IncludeUntagged
```

**LogPath**:
```powershell
# Custom log directory
-LogPath "C:\Logs\Azure"
-LogPath "/var/log/azure"
```

---

## Error Handling

### Script-Level Error Handling

All scripts use `$ErrorActionPreference = "Stop"` to halt on errors.

### Common Error Scenarios

#### 1. Authentication Errors

**Error**: "Run Connect-AzAccount to login"

**Solution**:
```powershell
Connect-AzAccount
Set-AzContext -SubscriptionName "Your Subscription"
```

#### 2. Permission Errors

**Error**: "The client does not have authorization"

**Solution**:
```powershell
# Check your role assignments
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id

# Request Contributor or Owner role from subscription admin
```

#### 3. Module Not Found

**Error**: "Az.Resources module not found"

**Solution**:
```powershell
Install-Module -Name Az -AllowClobber -Scope CurrentUser
Import-Module Az
```

#### 4. Template Validation Errors

**Error**: "Template validation failed"

**Solution**:
```powershell
# Run validation script first
.\Validate-Templates.ps1

# Use Test-AzResourceGroupDeployment for detailed errors
Test-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "..\app-service\app-service.json" `
    -TemplateParameterFile "..\app-service\parameters.dev.json"
```

#### 5. Resource Name Conflicts

**Error**: "The storage account name is already taken"

**Solution**:
- Storage accounts and Key Vaults require globally unique names
- Update parameter files with unique names
- Add random suffix or use different naming pattern

#### 6. Quota Exceeded

**Error**: "Quota exceeded for resource type"

**Solution**:
```powershell
# Check current quotas
Get-AzVMUsage -Location eastus

# Request quota increase via Azure Portal or support ticket
```

### Logging and Debugging

#### Enable Detailed Logging

```powershell
# Enable verbose output
$VerbosePreference = 'Continue'

# Enable debug output
$DebugPreference = 'Continue'

# View error details
$Error[0] | Format-List -Force
```

#### View Deployment Errors

```powershell
# Get deployment operations
Get-AzResourceGroupDeploymentOperation `
    -DeploymentName "deployment-name" `
    -ResourceGroupName "kbudget-dev-rg"

# View failed deployments
Get-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg" |
    Where-Object { $_.ProvisioningState -eq "Failed" } |
    Format-List
```

#### Check Azure Activity Log

```powershell
# View recent activity log entries
Get-AzLog -ResourceGroupName "kbudget-dev-rg" -MaxRecord 20

# Filter for errors
Get-AzLog -ResourceGroupName "kbudget-dev-rg" -MaxRecord 50 |
    Where-Object { $_.Level -eq "Error" }
```

---

## Troubleshooting

### Template Validation Issues

**Problem**: Template validation fails with schema errors

**Diagnosis**:
```powershell
# Run validation script
.\Validate-Templates.ps1 -ResourceType app-service

# Check JSON syntax manually
Get-Content ..\app-service\app-service.json | ConvertFrom-Json
```

**Solutions**:
1. Validate JSON syntax with online tools (jsonlint.com)
2. Check ARM template schema version
3. Verify all required properties are present
4. Review ARM template reference documentation

### Deployment Failures

**Problem**: Deployment fails during resource creation

**Diagnosis**:
```powershell
# Check deployment status
Get-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg" |
    Select-Object DeploymentName, ProvisioningState, Timestamp |
    Sort-Object Timestamp -Descending

# View deployment operations
Get-AzResourceGroupDeploymentOperation `
    -DeploymentName "app-deployment-20260207_103045" `
    -ResourceGroupName "kbudget-dev-rg" |
    Where-Object { $_.ProvisioningState -ne "Succeeded" }
```

**Solutions**:
1. Check logs in `logs/` directory
2. Review deployment error messages
3. Validate parameter values
4. Check Azure quotas and limits
5. Verify network connectivity
6. Check resource dependencies

### Key Vault Access Issues

**Problem**: Cannot access secrets in Key Vault

**Diagnosis**:
```powershell
# Check Key Vault access policies
Get-AzKeyVault -ResourceGroupName "kbudget-dev-rg" |
    Select-Object -ExpandProperty AccessPolicies

# Verify current user
Get-AzContext
```

**Solutions**:
```powershell
# Grant access to current user
Set-AzKeyVaultAccessPolicy `
    -VaultName "kbudget-dev-kv" `
    -UserPrincipalName (Get-AzContext).Account.Id `
    -PermissionsToSecrets get,list,set
```

### SQL Database Connection Issues

**Problem**: Cannot connect to SQL Database

**Diagnosis**:
```powershell
# Check SQL firewall rules
Get-AzSqlServerFirewallRule `
    -ResourceGroupName "kbudget-dev-rg" `
    -ServerName "kbudget-dev-sql"

# Get SQL server FQDN
Get-AzSqlServer -ResourceGroupName "kbudget-dev-rg" |
    Select-Object FullyQualifiedDomainName
```

**Solutions**:
1. Add firewall rule for your IP:
```powershell
New-AzSqlServerFirewallRule `
    -ResourceGroupName "kbudget-dev-rg" `
    -ServerName "kbudget-dev-sql" `
    -FirewallRuleName "MyClientIP" `
    -StartIpAddress "x.x.x.x" `
    -EndIpAddress "x.x.x.x"
```
2. Enable "Allow Azure services" option
3. Use VPN if accessing from restricted network

### Cleanup Script Issues

**Problem**: Cleanup script doesn't find resource groups

**Diagnosis**:
```powershell
# List all resource groups with tags
Get-AzResourceGroup | Select-Object ResourceGroupName, Tags

# Check specific resource group tags
(Get-AzResourceGroup -Name "kbudget-demo-rg").Tags
```

**Solutions**:
1. Ensure resource groups have proper tags:
   - `Environment` tag
   - `CreatedDate` tag
2. Use `-IncludeUntagged` to include untagged groups
3. Verify date format in `CreatedDate` tag (YYYY-MM-DD)

### Execution Policy Issues

**Problem**: "script cannot be loaded because running scripts is disabled"

**Solution**:
```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Bypass for specific script (not recommended for automation)
powershell.exe -ExecutionPolicy Bypass -File .\Deploy-AzureResources.ps1 -Environment dev
```

### Network Connectivity Issues

**Problem**: Cannot reach Azure endpoints

**Diagnosis**:
```powershell
# Test connectivity to Azure
Test-NetConnection management.azure.com -Port 443

# Check proxy settings
[System.Net.WebProxy]::GetDefaultProxy()
```

**Solutions**:
1. Configure proxy settings:
```powershell
# Set proxy for current session
$proxyUri = "http://proxy.company.com:8080"
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyUri)
```
2. Check firewall rules
3. Verify DNS resolution
4. Contact network administrator

---

## CI/CD Integration

### GitHub Actions

#### Deploy Infrastructure Workflow

Create `.github/workflows/deploy-infrastructure.yml`:

```yaml
name: Deploy Azure Infrastructure

on:
  push:
    branches: [ main ]
    paths:
      - 'infrastructure/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  validate:
    name: Validate Templates
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Validate ARM Templates
        shell: pwsh
        run: |
          cd infrastructure/arm-templates/main-deployment
          ./Validate-Templates.ps1
  
  deploy:
    name: Deploy Resources
    needs: validate
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Infrastructure
        shell: pwsh
        run: |
          cd infrastructure/arm-templates/main-deployment
          ./Deploy-AzureResources.ps1 -Environment ${{ github.event.inputs.environment || 'dev' }}
      
      - name: Upload Deployment Logs
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: deployment-logs
          path: infrastructure/arm-templates/main-deployment/logs/*.log
```

#### Cleanup Workflow

Create `.github/workflows/cleanup-resources.yml`:

```yaml
name: Cleanup Old Resources

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM UTC
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to cleanup'
        required: true
        type: choice
        options:
          - Development
          - Staging
          - Demo
          - Sandbox
      olderThanDays:
        description: 'Delete resources older than (days)'
        required: true
        default: '90'

jobs:
  cleanup:
    name: Cleanup Resources
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Run Cleanup Script
        shell: pwsh
        run: |
          cd infrastructure/arm-templates/resource-groups
          ./Cleanup-ResourceGroups.ps1 `
            -Environment ${{ github.event.inputs.environment || 'All' }} `
            -OlderThanDays ${{ github.event.inputs.olderThanDays || '90' }} `
            -DryRun:$false
      
      - name: Upload Cleanup Logs
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: cleanup-logs
          path: infrastructure/arm-templates/resource-groups/logs/*.log
```

### Azure DevOps Pipelines

#### Infrastructure Deployment Pipeline

Create `azure-pipelines-infrastructure.yml`:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - infrastructure/*

parameters:
  - name: environment
    displayName: 'Target Environment'
    type: string
    default: 'dev'
    values:
      - dev
      - staging
      - prod

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Validate
    displayName: 'Validate Templates'
    jobs:
      - job: ValidateJob
        displayName: 'Validate ARM Templates'
        steps:
          - task: AzurePowerShell@5
            displayName: 'Validate Templates'
            inputs:
              azureSubscription: 'Azure-Service-Connection'
              ScriptType: 'FilePath'
              ScriptPath: 'infrastructure/arm-templates/main-deployment/Validate-Templates.ps1'
              azurePowerShellVersion: 'LatestVersion'
  
  - stage: Deploy
    displayName: 'Deploy Infrastructure'
    dependsOn: Validate
    jobs:
      - deployment: DeployJob
        displayName: 'Deploy Resources'
        environment: ${{ parameters.environment }}
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                
                - task: AzurePowerShell@5
                  displayName: 'Deploy Azure Resources'
                  inputs:
                    azureSubscription: 'Azure-Service-Connection'
                    ScriptType: 'FilePath'
                    ScriptPath: 'infrastructure/arm-templates/main-deployment/Deploy-AzureResources.ps1'
                    ScriptArguments: '-Environment ${{ parameters.environment }}'
                    azurePowerShellVersion: 'LatestVersion'
                
                - task: PublishBuildArtifacts@1
                  displayName: 'Publish Deployment Logs'
                  condition: always()
                  inputs:
                    PathtoPublish: 'infrastructure/arm-templates/main-deployment/logs'
                    ArtifactName: 'deployment-logs'
```

### Service Principal Setup

For automation, create a service principal:

```powershell
# Create service principal
$sp = New-AzADServicePrincipal -DisplayName "KBudget-Deployment-SP"

# Assign Contributor role
New-AzRoleAssignment `
    -ApplicationId $sp.ApplicationId `
    -RoleDefinitionName "Contributor" `
    -Scope "/subscriptions/<subscription-id>"

# Get credentials for GitHub/Azure DevOps
$sp | Select-Object ApplicationId, Secret
```

**GitHub Secret Format** (`AZURE_CREDENTIALS`):
```json
{
  "clientId": "<application-id>",
  "clientSecret": "<secret>",
  "subscriptionId": "<subscription-id>",
  "tenantId": "<tenant-id>"
}
```

---

## Best Practices

### 1. Version Control

- **Commit templates and scripts** to Git
- **Use branches** for changes
- **Review changes** via pull requests
- **Tag releases** for production deployments

```bash
git checkout -b feature/update-sql-sku
# Make changes
git add infrastructure/
git commit -m "Update SQL SKU to Standard"
git push origin feature/update-sql-sku
# Create PR
```

### 2. Testing Strategy

1. **Validate templates** before deployment
2. **Test in dev** environment first
3. **Promote to staging** after dev validation
4. **Deploy to production** after staging approval

```powershell
# 1. Validate
.\Validate-Templates.ps1

# 2. Dev deployment
.\Deploy-AzureResources.ps1 -Environment dev

# 3. Test dev
# ... run tests ...

# 4. Staging deployment
.\Deploy-AzureResources.ps1 -Environment staging

# 5. Test staging
# ... run tests ...

# 6. Production deployment
.\Deploy-AzureResources.ps1 -Environment prod
```

### 3. Security Practices

- **Never commit secrets** to source control
- **Use Key Vault** for all sensitive data
- **Use managed identities** where possible
- **Enable soft delete** on Key Vault
- **Implement RBAC** for access control
- **Use private endpoints** for PaaS services (when possible)

```powershell
# Check for secrets in code
git grep -i password
git grep -i secret
git grep -i key

# Should return no sensitive values
```

### 4. Cost Management

- **Use appropriate SKUs** for each environment
- **Implement auto-shutdown** for dev resources
- **Regular cleanup** of old resources
- **Monitor costs** with Azure Cost Management
- **Tag all resources** for cost allocation

```powershell
# Schedule cleanup
.\Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30 -DryRun:$false

# Review costs by tag
Get-AzConsumptionUsageDetail -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) |
    Group-Object { $_.Tags.Environment } |
    Select-Object Name, @{N='Cost';E={($_.Group | Measure-Object -Property PretaxCost -Sum).Sum}}
```

### 5. Documentation

- **Keep documentation updated** with code changes
- **Document parameter changes** in commit messages
- **Maintain runbooks** for common tasks
- **Share knowledge** via team wiki or docs

### 6. Logging and Monitoring

- **Review deployment logs** after each run
- **Archive logs** for audit purposes
- **Set up alerts** for failed deployments
- **Monitor resource health** regularly

```powershell
# Archive logs
$archivePath = "\\fileshare\logs\azure\$(Get-Date -Format 'yyyy-MM')"
Copy-Item -Path ".\logs\*.log" -Destination $archivePath
```

### 7. Idempotency

- **Design for re-runnability**: Scripts should be safe to run multiple times
- **Use incremental mode** for ARM deployments (default)
- **Test redeployment** in dev environment

```powershell
# Run multiple times - should be safe
.\Deploy-AzureResources.ps1 -Environment dev
.\Deploy-AzureResources.ps1 -Environment dev  # Safe to rerun
```

### 8. Disaster Recovery

- **Document recovery procedures**
- **Test recovery process** regularly
- **Maintain backup** of parameter files
- **Export ARM templates** from portal as backup

```powershell
# Export resource group template
Export-AzResourceGroup `
    -ResourceGroupName "kbudget-prod-rg" `
    -Path ".\backups\prod-backup-$(Get-Date -Format 'yyyyMMdd').json"
```

### 9. Change Management

- **Use WhatIf** before applying changes
- **Communicate changes** to team
- **Plan maintenance windows** for production
- **Have rollback plan** ready

```powershell
# Always preview first
.\Deploy-AzureResources.ps1 -Environment prod -WhatIf

# Get approval

# Apply changes
.\Deploy-AzureResources.ps1 -Environment prod
```

### 10. Parameter Management

- **Keep parameter files separate** from templates
- **Use environment-specific** parameter files
- **Validate parameters** before deployment
- **Document parameter changes**

---

## Additional Resources

### Official Documentation

- [Azure PowerShell Documentation](https://docs.microsoft.com/powershell/azure/)
- [ARM Template Reference](https://docs.microsoft.com/azure/azure-resource-manager/templates/)
- [Azure PowerShell Module Reference](https://docs.microsoft.com/powershell/module/az)
- [Azure Resource Manager Overview](https://docs.microsoft.com/azure/azure-resource-manager/management/overview)

### KBudget GPT Documentation

- [Main Deployment README](../infrastructure/arm-templates/main-deployment/README.md)
- [Cleanup README](../infrastructure/arm-templates/resource-groups/CLEANUP-README.md)
- [Azure Infrastructure Overview](azure-infrastructure-overview.md)
- [Resource Group Naming Conventions](azure-resource-group-naming-conventions.md)
- [Resource Group Best Practices](azure-resource-group-best-practices.md)

### Community Resources

- [Azure PowerShell GitHub](https://github.com/Azure/azure-powershell)
- [ARM Template Samples](https://github.com/Azure/azure-quickstart-templates)
- [PowerShell Gallery](https://www.powershellgallery.com/)

---

## Quick Reference

### Essential Commands

```powershell
# Authentication
Connect-AzAccount
Set-AzContext -SubscriptionName "Your Subscription"

# Validation
.\Validate-Templates.ps1

# Deployment
.\Deploy-AzureResources.ps1 -Environment dev

# Cleanup
.\Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30

# Verification
Get-AzResourceGroup | Format-Table
Get-AzResource -ResourceGroupName "kbudget-dev-rg"
```

### Common Troubleshooting

```powershell
# Check modules
Get-Module -ListAvailable Az

# Check authentication
Get-AzContext

# Check permissions
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id

# View deployment errors
Get-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg" |
    Where-Object { $_.ProvisioningState -eq "Failed" }

# Check logs
Get-Content .\logs\deployment_*.log -Tail 50
```

---

## Support and Contact

For questions, issues, or support:

- **Documentation Owner**: Kevin Wilmoth
- **DevOps Team**: devops-team@company.com
- **GitHub Issues**: Submit an issue in the repository
- **Internal Wiki**: Check company Azure documentation

---

## License

*License information to be added*

---

**Last Updated**: 2026-02-07  
**Version**: 1.0.0  
**Maintained By**: DevOps Team
