# KBudget GPT

A budget management application built with GPT integration.

## 🚀 Quick Start - Temporary WIP App

While the main application is being developed, you can deploy a fun 90s retro-themed "Work in Progress" page to Azure:

```bash
# Deploy to Azure using GitHub Actions
# See docs/TEMP-WIP-APP-QUICKSTART.md for complete instructions
```

**[➡️ Deploy the Temporary WIP App](docs/TEMP-WIP-APP-QUICKSTART.md)** - Get started in 5 minutes!

---

## Documentation

This repository contains documentation and issue tracking for the KBudget GPT project.

### Project Documentation

#### Data Models
- **[Data Models Overview](docs/data-models/README.md)** - Overview of all data models for the envelope budgeting system
- **[User Data Model](docs/data-models/USER-DATA-MODEL.md)** - User profile schema, preferences, settings, and validation rules

#### Infrastructure & Deployment
- **[Temporary WIP App Quick Start](docs/TEMP-WIP-APP-QUICKSTART.md)** - Quick start guide for deploying the 90s retro "Work in Progress" temporary application to Azure App Service
- **[PowerShell Deployment Guide](docs/POWERSHELL-DEPLOYMENT-GUIDE.md)** - Comprehensive guide for all PowerShell deployment scripts including prerequisites, usage examples, parameters, troubleshooting, and CI/CD integration
- **[Deployment Validation and Testing Guide](docs/DEPLOYMENT-VALIDATION-GUIDE.md)** - Complete guide for deployment validation, automated testing, CI/CD pipeline integration, and error handling
- **[Network Architecture Guide](docs/NETWORK-ARCHITECTURE.md)** - Detailed network architecture diagrams, subnet layout, traffic flows, and security boundaries for the VNet infrastructure
- [Azure Infrastructure Overview](docs/azure-infrastructure-overview.md) - Complete guide to the Azure architecture, resources, security, and deployment
- [Azure Resource Group Naming Conventions](docs/azure-resource-group-naming-conventions.md) - Standard naming conventions for Azure Resource Groups across all environments
- [Azure Resource Group Best Practices](docs/azure-resource-group-best-practices.md) - Comprehensive guide for managing Azure Resource Groups, including resource organization, tagging strategies, and lifecycle management
- [Monitoring and Observability](docs/MONITORING-OBSERVABILITY.md) - Monitoring and observability implementation guide

#### Security & Compliance
- **[Azure AD Authentication Setup Guide](docs/AAD-AUTHENTICATION-SETUP-GUIDE.md)** - Complete guide for configuring Azure Active Directory authentication including app registration, user management, testing, and troubleshooting
- **[RBAC Documentation](docs/RBAC-DOCUMENTATION.md)** - Complete guide for Role-Based Access Control implementation, including role assignments, service principal configuration, audit process, and compliance
- **[Access Review Process](docs/ACCESS-REVIEW-PROCESS.md)** - Comprehensive guide for conducting regular access reviews, ensuring compliance and least privilege access across all Azure resources
- **[Compliance Documentation](docs/COMPLIANCE-DOCUMENTATION.md)** - Comprehensive audit log retention and regulatory compliance documentation with all log categories, retention timelines, and security policies

## Repository Structure

```
.
├── docs/                           # Project documentation
│   ├── data-models/               # Data model documentation
│   │   ├── README.md              # Data models overview
│   │   └── USER-DATA-MODEL.md     # User entity documentation
│   ├── AAD-AUTHENTICATION-SETUP-GUIDE.md # Azure AD authentication guide
│   ├── ACCESS-REVIEW-PROCESS.md   # Access review process guide
│   ├── TEMP-WIP-APP-QUICKSTART.md # Temporary WIP app deployment guide
│   ├── azure-resource-group-naming-conventions.md
│   ├── azure-resource-group-best-practices.md
│   └── MONITORING-OBSERVABILITY.md # Monitoring and observability guide
├── schemas/                        # JSON Schema definitions
│   ├── README.md                  # Schema validation guide
│   ├── user-schema.json           # User entity JSON Schema
│   └── user-sample.json           # Sample user document
├── temp-app/                       # Temporary WIP application
│   ├── index.html                 # 90s retro WIP page
│   ├── server.js                  # Node.js server
│   ├── Dockerfile                 # Container configuration
│   └── README.md                  # App documentation
├── KBudgetApp/                     # Main application
│   ├── KBudgetApp.csproj          # .NET 8.0 project file
│   └── Program.cs                 # Application entry point
├── infrastructure/                 # Infrastructure as Code
│   └── arm-templates/             # ARM templates
│       ├── resource-groups/       # Resource group templates
│       ├── aad-app-registration/  # Azure AD app registration scripts
│       ├── app-service/           # App Service templates
│       ├── temp-wip-app/          # Temporary WIP app deployment
│       ├── cosmos-database/       # Cosmos DB templates
│       ├── storage-account/       # Storage Account templates
│       ├── azure-functions/       # Azure Functions templates
│       ├── key-vault/             # Key Vault templates
│       ├── virtual-network/       # Virtual Network templates
│       ├── log-analytics/         # Log Analytics Workspace templates
│       ├── monitoring-alerts/     # Azure Monitor alerts templates
│       ├── diagnostic-settings/   # Diagnostic settings templates
│       ├── rbac/                  # Role-Based Access Control (RBAC) scripts
│       ├── access-reviews/        # Access review scripts and templates
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
- **Cosmos DB**: NoSQL database with global distribution
- **App Service**: Web application hosting
- **Azure Functions**: Serverless compute
- **Monitoring & Observability**: Log Analytics, diagnostic settings, and alerts

For detailed instructions, see [Main Deployment README](infrastructure/arm-templates/main-deployment/README.md) or the [PowerShell Deployment Guide](docs/POWERSHELL-DEPLOYMENT-GUIDE.md).

### Individual Resource Deployment

You can also deploy individual resources:

```powershell
# Deploy only Virtual Network and Storage
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("vnet", "storage")

# Deploy only Cosmos DB
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("cosmos")

# Deploy only monitoring resources
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("monitoring")
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
- **[Monitoring and Observability Guide](docs/MONITORING-OBSERVABILITY.md)** - Complete guide for monitoring, logging, and alerting setup
- **[Main Deployment README](infrastructure/arm-templates/main-deployment/README.md)** - Complete guide for deploying all Azure resources
- **[Azure Resource Group Naming Conventions](docs/azure-resource-group-naming-conventions.md)** - Standard naming patterns for all environments
- **[Azure Resource Group Best Practices](docs/azure-resource-group-best-practices.md)** - Comprehensive guide covering:
  - How to organize and structure Azure resources
  - Recommended tagging strategies for cost management and governance
  - Best practices for resource group lifecycle management

#### Resource-Specific Documentation

- [App Service](infrastructure/arm-templates/app-service/README.md) - Web application hosting
- [Cosmos DB](infrastructure/arm-templates/cosmos-database/README.md) - NoSQL database configuration
- [Storage Account](infrastructure/arm-templates/storage-account/README.md) - Blob storage and file services
- [Azure Functions](infrastructure/arm-templates/azure-functions/README.md) - Serverless compute
- [Key Vault](infrastructure/arm-templates/key-vault/README.md) - Secrets and key management
- [Virtual Network](infrastructure/arm-templates/virtual-network/README.md) - Network isolation and security
- [Resource Groups](infrastructure/arm-templates/resource-groups/README.md) - Resource group deployment

#### Monitoring and Observability

- [Log Analytics](infrastructure/arm-templates/log-analytics/README.md) - Centralized logging workspace
- [Monitoring Alerts](infrastructure/arm-templates/monitoring-alerts/README.md) - Metric alerts and action groups
- [Diagnostic Settings](infrastructure/arm-templates/diagnostic-settings/README.md) - Log collection configuration

#### Security and Access Control

- [RBAC](infrastructure/arm-templates/rbac/README.md) - Role-Based Access Control assignment and auditing
- [Access Reviews](infrastructure/arm-templates/access-reviews/README.md) - Regular access review process for compliance and least privilege
- [Azure AD App Registration](infrastructure/arm-templates/aad-app-registration/README.md) - Azure Active Directory authentication setup

## Azure Infrastructure

### Architecture Overview

The KBudget GPT application uses the following Azure resources:

| Resource | Purpose | Environments |
|----------|---------|--------------|
| **Resource Group** | Logical container for resources | dev, staging, prod |
| **Virtual Network** | Network isolation with subnets | All environments |
| **Key Vault** | Secure storage for secrets, keys, certificates | All environments |
| **Storage Account** | Blob storage for application data | All environments |
| **Cosmos DB** | NoSQL database with global distribution | All environments |
| **App Service** | Web application hosting (.NET 8.0) | All environments |
| **Azure Functions** | Serverless background processing | All environments |

### Security Features

✅ **Secrets Management**: All passwords and keys stored in Key Vault  
✅ **Managed Identities**: App Service and Functions use system-assigned identities  
✅ **Network Security**: VNet isolation with NSGs and service endpoints  
✅ **Encryption**: TLS 1.2 minimum, encrypted storage and database  
✅ **HTTPS Only**: All web endpoints require HTTPS  
✅ **Access Control**: RBAC and Key Vault access policies  
✅ **Azure AD Authentication**: Enterprise-grade OAuth 2.0 and OpenID Connect authentication (optional)

### Authentication

The application supports **Azure Active Directory (AAD) authentication** for enterprise-grade security:

- **Single Sign-On**: Users authenticate with their organizational credentials
- **Role-Based Access**: Separate Administrator and User roles
- **Multi-Factor Authentication**: Support for MFA through Azure AD
- **Audit Logging**: Complete authentication audit trail

**Quick Start with AAD:**

```powershell
# 1. Register AAD application
cd infrastructure/arm-templates/aad-app-registration
.\Register-AADApp.ps1 -Environment dev

# 2. Deploy App Service with authentication enabled
cd ../app-service
# Update parameters.dev.json with AAD values
New-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "app-service.json" -TemplateParameterFile "parameters.dev.json"
```

For complete setup instructions, see:
- **[Quick Start Guide](infrastructure/arm-templates/aad-app-registration/QUICKSTART.md)** - Get started in 5 minutes
- **[Azure AD Authentication Setup Guide](docs/AAD-AUTHENTICATION-SETUP-GUIDE.md)** - Complete configuration guide

### Role-Based Access Control (RBAC)

Manage fine-grained access control across Azure resources with automated RBAC assignment and auditing:

- **Role Assignment**: Assign built-in and custom roles to users, groups, and service principals
- **Least Privilege**: Configure service principals with minimal required permissions
- **Audit & Compliance**: Generate audit reports and validate role assignments
- **Multi-Environment**: Separate RBAC configurations for dev, staging, and production

**Quick Start with RBAC:**

```powershell
# Navigate to RBAC directory
cd infrastructure/arm-templates/rbac

# Preview RBAC assignments (WhatIf mode)
.\Assign-RBAC.ps1 -Environment dev -WhatIf

# Assign roles
.\Assign-RBAC.ps1 -Environment dev

# Audit role assignments
.\Audit-RBAC.ps1 -Environment dev -DetailedReport

# Test RBAC compliance
.\Test-RBAC.ps1 -Environment dev -ValidateLeastPrivilege
```

For complete setup instructions, see:
- **[RBAC Scripts README](infrastructure/arm-templates/rbac/README.md)** - Complete guide to RBAC scripts and usage
- **[RBAC Quick Reference](infrastructure/arm-templates/rbac/QUICK-REFERENCE.md)** - Quick reference for common commands
- **[RBAC Documentation](docs/RBAC-DOCUMENTATION.md)** - Comprehensive RBAC implementation guide

### Access Reviews

Conduct regular access reviews to ensure compliance, maintain least privilege, and validate user and service access:

- **Quarterly Reviews**: Comprehensive review of all access across environments
- **Monthly High-Privilege Reviews**: Review Owner/Contributor role assignments
- **Service Principal Reviews**: Validate service principal permissions and secret rotation
- **Compliance**: Supports SOC 2, ISO 27001, PCI DSS, and GDPR requirements

**Quick Start with Access Reviews:**

```powershell
# Navigate to access reviews directory
cd infrastructure/arm-templates/access-reviews

# Run quarterly access review (all environments)
.\Conduct-AccessReview.ps1 -ReviewType Quarterly

# Run production access review
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType Quarterly

# Monthly high-privilege review
.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege

# Service principal review
.\Conduct-AccessReview.ps1 -ReviewType ServicePrincipal
```

**Review Schedule:**
- **Quarterly**: January 15, April 15, July 15, October 15
- **Monthly**: First Monday of each month (high-privilege accounts)
- **Annual**: December 1-31 (comprehensive review)

For complete setup instructions, see:
- **[Access Review Process Guide](docs/ACCESS-REVIEW-PROCESS.md)** - Comprehensive process documentation
- **[Access Reviews README](infrastructure/arm-templates/access-reviews/README.md)** - Scripts and usage guide
- **[Access Review Quick Reference](infrastructure/arm-templates/access-reviews/QUICK-REFERENCE.md)** - Quick reference for common tasks


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
