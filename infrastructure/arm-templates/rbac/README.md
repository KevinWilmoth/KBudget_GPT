# Role-Based Access Control (RBAC) for Azure Resources

## Overview

This directory contains PowerShell scripts and configuration files for implementing and managing Role-Based Access Control (RBAC) across Azure resources for the KBudget GPT application.

**Purpose**: Ensure that only authorized users and services have the appropriate level of access required for their job function, following the principle of least privilege.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Scripts](#scripts)
- [Configuration Files](#configuration-files)
- [Role Definitions](#role-definitions)
- [Best Practices](#best-practices)
- [Audit Process](#audit-process)
- [Troubleshooting](#troubleshooting)

## Features

✅ **Role Assignment**: Assign built-in and custom roles to users, groups, and service principals  
✅ **Least Privilege**: Configure service principals with minimal required permissions  
✅ **Multi-Environment**: Support for dev, staging, and production environments  
✅ **Audit & Compliance**: Generate audit reports and validate role assignments  
✅ **Testing**: Automated testing of RBAC configurations  
✅ **Detailed Logging**: Comprehensive logs for all RBAC operations

## Prerequisites

### Required Software

1. **PowerShell**: 7.0+ or Windows PowerShell 5.1+
2. **Azure PowerShell Module**: Az module (version 8.0.0 or later)
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   ```

### Required Permissions

To manage RBAC, you need one of the following roles:
- **Owner** role on the subscription or resource group
- **User Access Administrator** role on the subscription or resource group

### Verify Your Access

```powershell
# Connect to Azure
Connect-AzAccount

# Check your current role assignments
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id
```

## Quick Start

### 1. Assign RBAC Roles

```powershell
# Navigate to RBAC directory
cd infrastructure/arm-templates/rbac

# Preview changes (WhatIf mode)
.\Assign-RBAC.ps1 -Environment dev -WhatIf

# Assign roles for development environment
.\Assign-RBAC.ps1 -Environment dev

# Assign roles for staging environment
.\Assign-RBAC.ps1 -Environment staging

# Assign roles for production environment
.\Assign-RBAC.ps1 -Environment prod
```

### 2. Audit RBAC Assignments

```powershell
# Audit development environment
.\Audit-RBAC.ps1 -Environment dev

# Audit with detailed resource-level report
.\Audit-RBAC.ps1 -Environment prod -DetailedReport

# Export audit report in JSON format only
.\Audit-RBAC.ps1 -Environment staging -OutputFormat JSON
```

### 3. Test RBAC Configuration

```powershell
# Test role assignments
.\Test-RBAC.ps1 -Environment dev

# Test with least-privilege validation
.\Test-RBAC.ps1 -Environment prod -ValidateLeastPrivilege
```

## Scripts

### Assign-RBAC.ps1

**Purpose**: Assign roles to users, groups, and service principals based on configuration files.

**Parameters**:
- `-Environment` (Required): Target environment (`dev`, `staging`, `prod`)
- `-ConfigFile` (Optional): Path to configuration file (defaults to `rbac-config.{env}.json`)
- `-ResourceGroupName` (Optional): Target resource group (defaults to `kbudget-{env}-rg`)
- `-WhatIf` (Optional): Preview changes without making them
- `-Force` (Optional): Skip confirmation prompts

**Examples**:
```powershell
# Standard assignment
.\Assign-RBAC.ps1 -Environment dev

# Preview changes
.\Assign-RBAC.ps1 -Environment dev -WhatIf

# Use custom config file
.\Assign-RBAC.ps1 -Environment dev -ConfigFile "custom-rbac.json"

# Target specific resource group
.\Assign-RBAC.ps1 -Environment dev -ResourceGroupName "my-custom-rg"
```

**Output**:
- Log file: `logs/rbac_assignment_{environment}_{timestamp}.log`
- Console output with color-coded status messages

### Audit-RBAC.ps1

**Purpose**: Audit existing RBAC assignments and generate compliance reports.

**Parameters**:
- `-Environment` (Required): Target environment (`dev`, `staging`, `prod`)
- `-ResourceGroupName` (Optional): Target resource group
- `-OutputFormat` (Optional): Report format (`JSON`, `CSV`, `Both`) - default: `Both`
- `-IncludeInheritedAssignments` (Optional): Include assignments inherited from parent scopes
- `-DetailedReport` (Optional): Include resource-level assignments

**Examples**:
```powershell
# Basic audit
.\Audit-RBAC.ps1 -Environment dev

# Detailed audit with resource-level assignments
.\Audit-RBAC.ps1 -Environment prod -DetailedReport

# Generate JSON report only
.\Audit-RBAC.ps1 -Environment staging -OutputFormat JSON

# Include inherited assignments
.\Audit-RBAC.ps1 -Environment dev -IncludeInheritedAssignments
```

**Output**:
- Log file: `logs/rbac_audit_{environment}_{timestamp}.log`
- Report files: `reports/rbac_audit_{environment}_{timestamp}.{json|csv}`
- High-privilege accounts report: `reports/rbac_audit_{environment}_{timestamp}_high_privilege.csv`

### Test-RBAC.ps1

**Purpose**: Validate RBAC assignments and test least-privilege compliance.

**Parameters**:
- `-Environment` (Required): Target environment (`dev`, `staging`, `prod`)
- `-ConfigFile` (Optional): Path to configuration file
- `-ResourceGroupName` (Optional): Target resource group
- `-ValidateLeastPrivilege` (Optional): Check for over-privileged accounts

**Examples**:
```powershell
# Basic testing
.\Test-RBAC.ps1 -Environment dev

# Test with least-privilege validation
.\Test-RBAC.ps1 -Environment prod -ValidateLeastPrivilege

# Use custom config file
.\Test-RBAC.ps1 -Environment dev -ConfigFile "custom-rbac.json"
```

**Output**:
- Log file: `logs/rbac_test_{environment}_{timestamp}.log`
- Test results with pass/fail status
- Least-privilege compliance issues

## Configuration Files

Configuration files define the RBAC assignments for each environment:
- `rbac-config.dev.json` - Development environment
- `rbac-config.staging.json` - Staging environment
- `rbac-config.prod.json` - Production environment

### Configuration File Structure

```json
{
  "description": "RBAC configuration for {environment}",
  "environment": "dev|staging|prod",
  "roleAssignments": [
    {
      "principalType": "User|Group|ServicePrincipal",
      "principalIdentifier": "name or UPN or App ID",
      "role": "Role Definition Name",
      "scope": {
        "type": "ResourceGroup|StorageAccount|KeyVault|etc",
        "name": "resource-name"
      },
      "justification": "Why this permission is needed"
    }
  ]
}
```

### Example Configuration Entry

```json
{
  "principalType": "ServicePrincipal",
  "principalIdentifier": "kbudget-dev-app",
  "role": "Storage Blob Data Contributor",
  "scope": {
    "type": "StorageAccount",
    "name": "kbudgetdevstorage"
  },
  "justification": "App Service needs to read/write blob data"
}
```

### Supported Scope Types

- `ResourceGroup` - Entire resource group
- `Subscription` - Entire subscription
- `StorageAccount` - Storage account
- `KeyVault` - Key Vault
- `SQLDatabase` - SQL Database (format: `server/database`)
- `AppService` - App Service / Web App
- `FunctionApp` - Azure Functions
- `LogAnalytics` - Log Analytics workspace

## Role Definitions

### Built-in Roles Used

#### High-Privilege Roles (Use Sparingly)

| Role | Permissions | Use Case |
|------|-------------|----------|
| **Owner** | Full access including RBAC management | Production administrators only |
| **Contributor** | Full access except RBAC management | DevOps teams, CI/CD pipelines |
| **User Access Administrator** | Manage user access only | Security administrators |

#### Read-Only Roles

| Role | Permissions | Use Case |
|------|-------------|----------|
| **Reader** | Read-only access to all resources | QA teams, support staff |
| **Security Reader** | Read security configurations | Security audit teams |
| **Monitoring Reader** | Read monitoring data | Monitoring teams |

#### Resource-Specific Roles (Least Privilege)

| Role | Permissions | Use Case |
|------|-------------|----------|
| **Storage Blob Data Contributor** | Read/write blobs | App services accessing blob storage |
| **Storage Blob Data Reader** | Read-only blob access | Services that only need to read blobs |
| **Key Vault Secrets User** | Read secrets | App services reading configuration |
| **Log Analytics Reader** | Read logs and metrics | Monitoring and troubleshooting |

### Custom Roles

Custom roles can be created for specific needs. See [Azure Custom Roles Documentation](https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles).

## Best Practices

### 1. Principle of Least Privilege

✅ **DO**: Assign the minimum permissions required for each task  
✅ **DO**: Use resource-specific roles (e.g., `Storage Blob Data Reader`) over broad roles  
✅ **DO**: Assign roles at the lowest necessary scope (resource > resource group > subscription)

❌ **DON'T**: Assign `Owner` role to service principals  
❌ **DON'T**: Use `Contributor` when a more specific role is available  
❌ **DON'T**: Assign roles at subscription level when resource group scope is sufficient

### 2. Service Principal Permissions

✅ **DO**: Use managed identities instead of service principals when possible  
✅ **DO**: Assign `Contributor` or lower to automation service principals  
✅ **DO**: Use resource-specific roles for application identities

❌ **DON'T**: Give service principals `Owner` or `User Access Administrator` roles  
❌ **DON'T**: Share service principal credentials across environments

### 3. User and Group Management

✅ **DO**: Use Azure AD groups for role assignments  
✅ **DO**: Separate production access from non-production  
✅ **DO**: Regularly review and remove unused assignments

❌ **DON'T**: Assign roles to individual users when groups are available  
❌ **DON'T**: Give developers `Contributor` access to production

### 4. Environment Separation

| Environment | Typical Access Pattern |
|-------------|------------------------|
| **Development** | Developers: `Contributor`<br>QA: `Reader`<br>Security: `Security Reader` |
| **Staging** | DevOps: `Contributor`<br>Developers: `Reader`<br>QA: `Reader` |
| **Production** | Production Admins: `Owner`<br>DevOps: `Contributor`<br>Support: `Reader` |

### 5. Justification and Documentation

✅ **DO**: Document the justification for each role assignment  
✅ **DO**: Include business context and security rationale  
✅ **DO**: Review and update justifications during audits

## Audit Process

### Recommended Audit Schedule

| Audit Type | Frequency | Owner |
|------------|-----------|-------|
| **Routine Audit** | Monthly | Security Team |
| **Comprehensive Review** | Quarterly | Security + DevOps |
| **Production Audit** | After each deployment | DevOps Team |
| **Compliance Audit** | Annually | Compliance Officer |

### Audit Workflow

1. **Run Audit Script**
   ```powershell
   .\Audit-RBAC.ps1 -Environment prod -DetailedReport
   ```

2. **Review Report**
   - Check for unauthorized assignments
   - Identify over-privileged accounts
   - Verify service principal permissions

3. **Address Issues**
   - Remove unnecessary assignments
   - Replace broad roles with specific ones
   - Update configuration files

4. **Test Changes**
   ```powershell
   .\Test-RBAC.ps1 -Environment prod -ValidateLeastPrivilege
   ```

5. **Document Findings**
   - Save audit reports
   - Update RBAC documentation
   - Track remediation actions

### Key Audit Checks

- ✓ No service principals with `Owner` role
- ✓ No service principals with `User Access Administrator` role
- ✓ Production access limited to authorized personnel
- ✓ All assignments have valid justifications
- ✓ No orphaned role assignments (deleted principals)
- ✓ Resource-level permissions follow least privilege

## Troubleshooting

### Common Issues

#### 1. Permission Denied

**Error**: `Insufficient privileges to complete the operation`

**Cause**: User lacks `Owner` or `User Access Administrator` role

**Solution**:
```powershell
# Request access from subscription administrator
# Or use an account with appropriate permissions
Connect-AzAccount -TenantId "your-tenant-id"
```

#### 2. Principal Not Found

**Error**: `Principal not found in Azure AD`

**Cause**: User, group, or service principal doesn't exist or name is incorrect

**Solution**:
```powershell
# Verify user exists
Get-AzADUser -UserPrincipalName "user@domain.com"

# Verify group exists
Get-AzADGroup -DisplayName "KBudget-Developers"

# Verify service principal exists
Get-AzADServicePrincipal -DisplayName "kbudget-dev-app"
```

#### 3. Role Assignment Already Exists

**Warning**: `Role assignment already exists`

**Cause**: Role is already assigned (not an error, just informational)

**Solution**: No action needed. The script detects and skips existing assignments.

#### 4. Resource Not Found

**Error**: `Failed to determine scope for resource`

**Cause**: Resource doesn't exist or name is incorrect in config file

**Solution**:
```powershell
# Verify resource exists
Get-AzResource -ResourceGroupName "kbudget-dev-rg"

# Check resource names in configuration file
```

### Debugging

Enable verbose logging:
```powershell
# Run with verbose output
.\Assign-RBAC.ps1 -Environment dev -Verbose

# Check log files
Get-Content logs/rbac_assignment_dev_*.log -Tail 50
```

## Security Considerations

### Protecting Service Principal Credentials

1. **Never commit secrets to source control**
2. **Store credentials in Azure Key Vault**
3. **Use managed identities instead of service principals when possible**
4. **Rotate service principal secrets regularly**

### Monitoring RBAC Changes

Set up Azure Monitor alerts for RBAC changes:
- Alert on `Owner` role assignments
- Alert on `User Access Administrator` assignments
- Alert on role assignments to service principals

### Compliance

This RBAC implementation supports:
- **SOC 2**: Access control and segregation of duties
- **ISO 27001**: Information security management
- **PCI DSS**: Access control requirements
- **HIPAA**: Access control and audit requirements

## Additional Resources

### Documentation

- [Azure RBAC Documentation](https://docs.microsoft.com/en-us/azure/role-based-access-control/)
- [Azure Built-in Roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Managed Identities](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)

### Related KBudget GPT Documentation

- [PowerShell Deployment Guide](../../../docs/POWERSHELL-DEPLOYMENT-GUIDE.md)
- [Azure AD Authentication Setup Guide](../../../docs/AAD-AUTHENTICATION-SETUP-GUIDE.md)
- [Compliance Documentation](../../../docs/COMPLIANCE-DOCUMENTATION.md)
- [Azure Resource Group Best Practices](../../../docs/azure-resource-group-best-practices.md)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review log files in the `logs/` directory
3. Consult Azure RBAC documentation
4. Contact the DevOps or Security team

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-13  
**Maintainer**: Security and DevOps Team
