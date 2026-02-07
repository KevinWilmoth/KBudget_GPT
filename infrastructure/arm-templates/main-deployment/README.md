# Azure Resources Deployment - Main Orchestration

This directory contains the main PowerShell deployment script that orchestrates the provisioning of all Azure resources for the KBudget GPT application.

## Overview

The `Deploy-AzureResources.ps1` script automates the deployment of the complete Azure infrastructure including:

- **Resource Groups**: Logical containers for resources
- **Virtual Network (VNet)**: Network isolation with subnets for app, database, and functions
- **Key Vault**: Secure storage for secrets, keys, and certificates
- **Storage Account**: Blob storage for application data and Azure Functions
- **SQL Database**: Azure SQL Server and Database for application data
- **App Service**: Web application hosting with App Service Plan
- **Azure Functions**: Serverless compute for background tasks

## Features

✅ **Environment Support**: Deploy to dev, staging, or production  
✅ **Idempotent**: Safe to run multiple times without side effects  
✅ **Secure**: Passwords stored in Key Vault, HTTPS enforced, TLS 1.2 minimum  
✅ **Flexible**: Deploy all resources or specific resource types  
✅ **Logged**: Detailed logging with timestamps for troubleshooting  
✅ **Validated**: Pre-deployment validation of prerequisites  
✅ **WhatIf Mode**: Preview changes without deploying

## Prerequisites

### Required Software

1. **PowerShell 7.0+** (recommended) or Windows PowerShell 5.1+
   ```powershell
   $PSVersionTable.PSVersion
   ```

2. **Azure PowerShell Module (Az)**
   ```powershell
   # Install Az module
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   
   # Verify installation
   Get-Module -ListAvailable -Name Az
   ```

### Azure Requirements

1. **Active Azure Subscription**
2. **Permissions**: Contributor or Owner role at subscription level
3. **Authentication**: Must be logged in to Azure

## Authentication

Before running the deployment, authenticate to Azure:

```powershell
# Login to Azure
Connect-AzAccount

# Set the correct subscription (if you have multiple)
Set-AzContext -SubscriptionId "<subscription-id>"

# Verify current context
Get-AzContext
```

## Usage

### Basic Deployment

Deploy all resources to an environment:

```powershell
# Deploy to development
.\Deploy-AzureResources.ps1 -Environment dev

# Deploy to staging
.\Deploy-AzureResources.ps1 -Environment staging

# Deploy to production
.\Deploy-AzureResources.ps1 -Environment prod
```

### Advanced Usage

#### Deploy Specific Resources

Deploy only specific resource types:

```powershell
# Deploy only VNet and Storage
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("vnet", "storage")

# Deploy only Key Vault and SQL Database
.\Deploy-AzureResources.ps1 -Environment prod -ResourceTypes @("keyvault", "sql")
```

Available resource types:
- `all` (default)
- `vnet` - Virtual Network
- `keyvault` - Key Vault
- `storage` - Storage Account
- `sql` - SQL Database
- `appservice` - App Service
- `functions` - Azure Functions

#### Custom Location

Deploy to a different Azure region:

```powershell
.\Deploy-AzureResources.ps1 -Environment dev -Location westus2
```

Available locations:
- `eastus` (default)
- `westus`
- `westus2`
- `centralus`
- `northeurope`
- `westeurope`

#### WhatIf Mode

Preview what would be deployed without making changes:

```powershell
.\Deploy-AzureResources.ps1 -Environment dev -WhatIf
```

#### Skip Resource Group

Skip resource group deployment (if already exists):

```powershell
.\Deploy-AzureResources.ps1 -Environment dev -SkipResourceGroup
```

## Resource Naming Convention

All resources follow a consistent naming pattern:

| Resource Type | Naming Pattern | Example (dev) |
|---------------|----------------|---------------|
| Resource Group | `kbudget-{env}-rg` | `kbudget-dev-rg` |
| Virtual Network | `kbudget-{env}-vnet` | `kbudget-dev-vnet` |
| Key Vault | `kbudget-{env}-kv` | `kbudget-dev-kv` |
| Storage Account | `kbudget{env}st` | `kbudgetdevst` |
| SQL Server | `kbudget-{env}-sql` | `kbudget-dev-sql` |
| SQL Database | `kbudget-{env}-db` | `kbudget-dev-db` |
| App Service Plan | `kbudget-{env}-asp` | `kbudget-dev-asp` |
| App Service | `kbudget-{env}-app` | `kbudget-dev-app` |
| Function App | `kbudget-{env}-func` | `kbudget-dev-func` |

## Deployment Order

Resources are deployed in the following order to handle dependencies:

1. **Resource Group** (subscription-level deployment)
2. **Virtual Network** (network foundation)
3. **Key Vault** (secrets storage)
4. **Storage Account** (required for Functions)
5. **SQL Database** (data tier)
6. **App Service** (web tier)
7. **Azure Functions** (serverless tier)

## Security Features

### Secrets Management

- SQL admin passwords are automatically generated (16 characters, complex)
- Passwords stored securely in Key Vault
- SQL Database parameter files reference Key Vault for passwords
- No secrets in code or parameter files

### Network Security

- Virtual Network with isolated subnets
- Network Security Groups (NSGs) for traffic control
- Service endpoints for Azure services
- HTTPS only for App Service and Functions
- TLS 1.2 minimum for all services

### Access Control

- Managed identities for App Service and Functions
- Key Vault access policies for services
- SQL firewall rules for Azure services
- Storage account with secure transfer required

### Encryption

- Blob and file encryption enabled on Storage Account
- SQL Transparent Data Encryption (TDE) enabled
- Key Vault soft delete and purge protection (prod)

## Logging

All deployments create detailed logs in the `logs/` directory:

```
logs/
├── deployment_dev_20240115_143022.log
├── deployment_staging_20240115_150833.log
└── deployment_prod_20240115_153045.log
```

Log entries include:
- Timestamp for each operation
- Deployment status and progress
- Resource IDs and outputs
- Errors with stack traces
- Color-coded messages (INFO, SUCCESS, WARNING, ERROR)

## Verification

After deployment, verify resources were created:

```powershell
# List all resources in the resource group
Get-AzResource -ResourceGroupName "kbudget-dev-rg" | Format-Table

# Check specific resources
Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg"
Get-AzKeyVault -ResourceGroupName "kbudget-dev-rg"
Get-AzStorageAccount -ResourceGroupName "kbudget-dev-rg"
Get-AzSqlServer -ResourceGroupName "kbudget-dev-rg"
Get-AzWebApp -ResourceGroupName "kbudget-dev-rg"

# View deployment history
Get-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg" | Format-Table
```

## Troubleshooting

### Common Issues

#### "Az module not found"
```powershell
Install-Module -Name Az -AllowClobber -Scope CurrentUser
```

#### "Not authenticated to Azure"
```powershell
Connect-AzAccount
```

#### "Insufficient permissions"
- Ensure you have Contributor or Owner role
- Check with: `Get-AzRoleAssignment -SignInName <your-email>`

#### "Resource name already taken"
- Some resources (Storage, Key Vault) require globally unique names
- Update parameter files with unique names

#### "Template validation failed"
Validate individual templates:
```powershell
Test-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "..\app-service\app-service.json" `
    -TemplateParameterFile "..\app-service\parameters.dev.json"
```

### Viewing Logs

```powershell
# View most recent log
Get-Content ".\logs\deployment_*.log" -Tail 50

# View specific log
Get-Content ".\logs\deployment_dev_20240115_143022.log"

# Search logs for errors
Select-String -Path ".\logs\*.log" -Pattern "ERROR"
```

### Rollback

To remove deployed resources:

```powershell
# Remove entire resource group (WARNING: Deletes all resources!)
Remove-AzResourceGroup -Name "kbudget-dev-rg" -Force

# Or use the cleanup script from resource-groups directory
..\resource-groups\Cleanup-ResourceGroups.ps1 -Environment Development
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy Azure Infrastructure

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Infrastructure
        shell: pwsh
        run: |
          cd infrastructure/arm-templates/main-deployment
          ./Deploy-AzureResources.ps1 -Environment dev
```

### Azure DevOps

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzurePowerShell@5
    inputs:
      azureSubscription: 'Azure-Service-Connection'
      ScriptType: 'FilePath'
      ScriptPath: 'infrastructure/arm-templates/main-deployment/Deploy-AzureResources.ps1'
      ScriptArguments: '-Environment dev'
      azurePowerShellVersion: 'LatestVersion'
```

## Updating Existing Resources

The deployment is idempotent - running it again will:
- Skip resources that already exist with correct configuration
- Update resources if parameters have changed
- Add new resources if specified

Example update workflow:

```powershell
# 1. Update parameter files as needed
# 2. Run deployment again
.\Deploy-AzureResources.ps1 -Environment dev

# 3. Check logs to see what was updated
Get-Content ".\logs\deployment_*.log" -Tail 100
```

## Parameter Customization

To customize deployments for your needs:

1. **Edit environment-specific parameter files**:
   - `../app-service/parameters.{env}.json`
   - `../sql-database/parameters.{env}.json`
   - etc.

2. **Common customizations**:
   - SKU sizes (Basic, Standard, Premium)
   - Capacity (number of instances)
   - Location/region
   - Tags for billing and organization
   - Network address spaces

3. **Re-run deployment** to apply changes

## Related Documentation

- [Resource Groups README](../resource-groups/README.md)
- [Azure Resource Group Naming Conventions](../../../docs/azure-resource-group-naming-conventions.md)
- [Azure Resource Group Best Practices](../../../docs/azure-resource-group-best-practices.md)

## Support

For questions or issues:
- Check logs in `logs/` directory
- Review ARM template documentation
- Contact DevOps Team

## License

*License information to be added*
