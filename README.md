# KBudget GPT

A budget management application built with GPT integration.

## Documentation

This repository contains documentation and issue tracking for the KBudget GPT project.

### Project Documentation

- **[PowerShell Deployment Guide](docs/POWERSHELL-DEPLOYMENT-GUIDE.md)** - Comprehensive guide for all PowerShell deployment scripts including prerequisites, usage examples, parameters, troubleshooting, and CI/CD integration
- **[Deployment Validation and Testing Guide](docs/DEPLOYMENT-VALIDATION-GUIDE.md)** - Complete guide for deployment validation, automated testing, CI/CD pipeline integration, and error handling
- [Azure Infrastructure Overview](docs/azure-infrastructure-overview.md) - Complete guide to the Azure architecture, resources, security, and deployment
- [Azure Resource Group Naming Conventions](docs/azure-resource-group-naming-conventions.md) - Standard naming conventions for Azure Resource Groups across all environments
- [Azure Resource Group Best Practices](docs/azure-resource-group-best-practices.md) - Comprehensive guide for managing Azure Resource Groups, including resource organization, tagging strategies, and lifecycle management

## Repository Structure

```
.
├── docs/                           # Project documentation
│   ├── azure-resource-group-naming-conventions.md
│   └── azure-resource-group-best-practices.md
├── infrastructure/                 # Infrastructure as Code
│   └── arm-templates/             # ARM templates
│       ├── resource-groups/       # Resource group templates
│       ├── app-service/           # App Service templates
│       ├── sql-database/          # SQL Database templates
│       ├── storage-account/       # Storage Account templates
│       ├── azure-functions/       # Azure Functions templates
│       ├── key-vault/             # Key Vault templates
│       ├── virtual-network/       # Virtual Network templates
│       └── main-deployment/       # Main orchestration scripts
│           ├── Deploy-AzureResources.ps1
│           └── README.md
├── issues/                        # Issue tracking
├── ISSUES_BACKLOG.md             # Issue templates and backlog
└── README.md                     # This file
```

## Getting Started

### PowerShell Deployment Scripts

The KBudget GPT project uses PowerShell scripts for infrastructure deployment and management. For comprehensive documentation on all scripts, prerequisites, parameters, troubleshooting, and best practices, see the **[PowerShell Deployment Guide](docs/POWERSHELL-DEPLOYMENT-GUIDE.md)**.

#### Quick Start

**1. Prerequisites**:
```powershell
# Install Azure PowerShell module
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Login to Azure
Connect-AzAccount
```

**2. Validate Templates** (recommended before deployment):
```powershell
cd infrastructure/arm-templates/main-deployment
.\Validate-Templates.ps1
```

**3. Deploy Infrastructure**:
```powershell
# Deploy all resources to development
.\Deploy-AzureResources.ps1 -Environment dev

# Deploy all resources to staging
.\Deploy-AzureResources.ps1 -Environment staging

# Deploy all resources to production
.\Deploy-AzureResources.ps1 -Environment prod
```

The deployment includes:
- **Virtual Network**: Network isolation with subnets
- **Key Vault**: Secure storage for secrets and keys
- **Storage Account**: Blob storage for application data
- **SQL Database**: Azure SQL Server and Database
- **App Service**: Web application hosting
- **Azure Functions**: Serverless compute

For detailed instructions, see [Main Deployment README](infrastructure/arm-templates/main-deployment/README.md) or the [PowerShell Deployment Guide](docs/POWERSHELL-DEPLOYMENT-GUIDE.md).

### Individual Resource Deployment

You can also deploy individual resources:

```powershell
# Deploy only Virtual Network and Storage
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("vnet", "storage")

# Deploy only SQL Database
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("sql")
```

### Resource Groups Only

Deploy Azure Resource Groups for dev, staging, and prod environments:

```bash
# Navigate to the resource groups directory
cd infrastructure/arm-templates/resource-groups

# Deploy all environments
./deploy-resource-groups.sh all

# Or deploy individual environments
./deploy-resource-groups.sh dev
./deploy-resource-groups.sh staging
./deploy-resource-groups.sh prod
```

For detailed deployment instructions, see [Resource Groups README](infrastructure/arm-templates/resource-groups/README.md).

### Resource Group Cleanup

Automate cleanup of old or non-production resource groups to manage costs:

```powershell
# Navigate to the resource groups directory
cd infrastructure/arm-templates/resource-groups

# Dry run - see what would be deleted (safe, no deletion)
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30

# Actual deletion (requires confirmation)
./Cleanup-ResourceGroups.ps1 -Environment Development -OlderThanDays 30 -DryRun:$false
```

For detailed cleanup documentation, see [Cleanup README](infrastructure/arm-templates/resource-groups/CLEANUP-README.md).

### Deployment Validation and Testing

All deployment scripts include built-in validation and automated testing:

**Validation Features**:
- ✅ Post-deployment resource verification
- ✅ Status checking and health monitoring  
- ✅ Deployment output collection and storage
- ✅ Automated alerts for critical failures
- ✅ Comprehensive validation summaries

**Testing**:
```powershell
# Run Pester tests locally
cd infrastructure/arm-templates/main-deployment
Install-Module -Name Pester -Force -SkipPublisherCheck
Invoke-Pester -Path Deploy-AzureResources.Tests.ps1
```

**CI/CD Integration**:
- GitHub Actions workflow automatically validates scripts on every commit
- PowerShell syntax validation
- Pester unit tests
- ARM template validation
- Security scanning with PSScriptAnalyzer
- Hardcoded secrets detection

For complete details, see the **[Deployment Validation and Testing Guide](docs/DEPLOYMENT-VALIDATION-GUIDE.md)**.

### Documentation

For DevOps and infrastructure management, please refer to our documentation:
- **[PowerShell Deployment Guide](docs/POWERSHELL-DEPLOYMENT-GUIDE.md)** - Complete guide for all PowerShell deployment scripts with examples, parameters, and troubleshooting
- **[Deployment Validation and Testing Guide](docs/DEPLOYMENT-VALIDATION-GUIDE.md)** - Comprehensive guide for validation, testing, CI/CD integration, and error handling
- **[Main Deployment README](infrastructure/arm-templates/main-deployment/README.md)** - Complete guide for deploying all Azure resources
- **[Azure Resource Group Naming Conventions](docs/azure-resource-group-naming-conventions.md)** - Standard naming patterns for all environments
- **[Azure Resource Group Best Practices](docs/azure-resource-group-best-practices.md)** - Comprehensive guide covering:
  - How to organize and structure Azure resources
  - Recommended tagging strategies for cost management and governance
  - Best practices for resource group lifecycle management

#### Resource-Specific Documentation

- [App Service](infrastructure/arm-templates/app-service/README.md) - Web application hosting
- [SQL Database](infrastructure/arm-templates/sql-database/README.md) - Database server and configuration
- [Storage Account](infrastructure/arm-templates/storage-account/README.md) - Blob storage and file services
- [Azure Functions](infrastructure/arm-templates/azure-functions/README.md) - Serverless compute
- [Key Vault](infrastructure/arm-templates/key-vault/README.md) - Secrets and key management
- [Virtual Network](infrastructure/arm-templates/virtual-network/README.md) - Network isolation and security
- [Resource Groups](infrastructure/arm-templates/resource-groups/README.md) - Resource group deployment

## Azure Infrastructure

### Architecture Overview

The KBudget GPT application uses the following Azure resources:

| Resource | Purpose | Environments |
|----------|---------|--------------|
| **Resource Group** | Logical container for resources | dev, staging, prod |
| **Virtual Network** | Network isolation with subnets | All environments |
| **Key Vault** | Secure storage for secrets, keys, certificates | All environments |
| **Storage Account** | Blob storage for application data | All environments |
| **SQL Database** | Application database (Azure SQL) | All environments |
| **App Service** | Web application hosting (.NET 8.0) | All environments |
| **Azure Functions** | Serverless background processing | All environments |

### Security Features

✅ **Secrets Management**: All passwords and keys stored in Key Vault  
✅ **Managed Identities**: App Service and Functions use system-assigned identities  
✅ **Network Security**: VNet isolation with NSGs and service endpoints  
✅ **Encryption**: TLS 1.2 minimum, encrypted storage and database  
✅ **HTTPS Only**: All web endpoints require HTTPS  
✅ **Access Control**: RBAC and Key Vault access policies

### Deployment Features

✅ **Multi-Environment**: Support for dev, staging, and production  
✅ **Idempotent**: Safe to run deployments multiple times  
✅ **Automated**: PowerShell script orchestrates all resources  
✅ **Flexible**: Deploy all resources or select specific ones  
✅ **Logged**: Detailed logging for troubleshooting  
✅ **Validated**: Pre-deployment prerequisite checks  
✅ **Post-Deployment Validation**: Automatic resource verification after deployment  
✅ **Output Collection**: Deployment results exported to JSON for auditing  
✅ **Automated Testing**: Pester tests for deployment script validation  
✅ **CI/CD Integration**: GitHub Actions workflow for continuous validation  
✅ **Alert System**: Automated notifications for critical failures

### Prerequisites

To deploy the infrastructure, you need:

1. **Azure Subscription** with Contributor or Owner permissions
2. **PowerShell 7.0+** or Windows PowerShell 5.1+
3. **Azure PowerShell Module (Az)**:
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   ```
4. **Azure Authentication**:
   ```powershell
   Connect-AzAccount
   ```

## Contributing

When working with Azure resources for this project, please follow the guidelines outlined in our documentation to ensure consistency and maintainability.

## License

*License information to be added*
