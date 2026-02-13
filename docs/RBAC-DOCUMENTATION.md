# Role-Based Access Control (RBAC) Documentation

## Executive Summary

This document provides comprehensive guidance for implementing and managing Role-Based Access Control (RBAC) across Azure resources for the KBudget GPT application. RBAC ensures that only authorized users and services have the appropriate level of access required for their job function, following the principle of least privilege.

## Table of Contents

1. [Overview](#overview)
2. [RBAC Implementation](#rbac-implementation)
3. [Role Assignment Process](#role-assignment-process)
4. [Service Principal Configuration](#service-principal-configuration)
5. [Audit Process](#audit-process)
6. [Compliance and Security](#compliance-and-security)
7. [Troubleshooting](#troubleshooting)
8. [References](#references)

## Overview

### Purpose

RBAC provides fine-grained access management of Azure resources, enabling:
- **Segregation of Duties**: Different roles for different responsibilities
- **Least Privilege**: Minimal permissions required for each task
- **Audit Trail**: Comprehensive logging of access and changes
- **Compliance**: Meet regulatory requirements (SOC 2, ISO 27001, PCI DSS)

### Key Concepts

**Principal**: An identity that can be assigned a role
- **User**: Individual Azure AD user
- **Group**: Azure AD security group
- **Service Principal**: Application or service identity
- **Managed Identity**: Azure-managed service identity

**Role**: A collection of permissions
- **Built-in Roles**: Predefined by Azure (e.g., Owner, Contributor, Reader)
- **Custom Roles**: User-defined roles with specific permissions

**Scope**: The resources to which access applies
- **Subscription**: Entire Azure subscription
- **Resource Group**: Collection of resources
- **Resource**: Individual resource (e.g., storage account, key vault)

### RBAC Model

```
Principal + Role + Scope = Role Assignment

Examples:
- User "john@example.com" + "Contributor" + Resource Group "kbudget-dev-rg"
- Group "Developers" + "Reader" + Resource Group "kbudget-prod-rg"
- Service Principal "kbudget-app" + "Storage Blob Data Reader" + Storage Account "kbudgetstorage"
```

## RBAC Implementation

### Directory Structure

```
infrastructure/arm-templates/rbac/
├── Assign-RBAC.ps1           # Main assignment script
├── Audit-RBAC.ps1             # Audit script
├── Test-RBAC.ps1              # Testing script
├── rbac-config.dev.json       # Dev environment configuration
├── rbac-config.staging.json   # Staging environment configuration
├── rbac-config.prod.json      # Production environment configuration
├── README.md                  # Full documentation
├── QUICK-REFERENCE.md         # Quick reference guide
└── .gitignore                 # Exclude logs and reports
```

### Scripts

#### 1. Assign-RBAC.ps1

Assigns roles to users, groups, and service principals based on configuration files.

**Features**:
- Validates principals exist in Azure AD
- Checks for existing assignments (idempotent)
- Supports WhatIf mode for safe testing
- Detailed logging and error handling
- Supports multiple scope types

**Usage**:
```powershell
.\Assign-RBAC.ps1 -Environment dev
.\Assign-RBAC.ps1 -Environment prod -WhatIf
```

#### 2. Audit-RBAC.ps1

Audits existing RBAC assignments and generates compliance reports.

**Features**:
- Lists all role assignments in scope
- Identifies high-privilege accounts
- Generates JSON and CSV reports
- Supports resource-level audits
- Tracks inherited assignments

**Usage**:
```powershell
.\Audit-RBAC.ps1 -Environment dev
.\Audit-RBAC.ps1 -Environment prod -DetailedReport
```

#### 3. Test-RBAC.ps1

Validates RBAC assignments and tests least-privilege compliance.

**Features**:
- Verifies all configured assignments exist
- Checks for over-privileged accounts
- Validates service principal permissions
- Tests least-privilege compliance
- Generates pass/fail reports

**Usage**:
```powershell
.\Test-RBAC.ps1 -Environment dev
.\Test-RBAC.ps1 -Environment prod -ValidateLeastPrivilege
```

### Configuration Files

Each environment has a dedicated configuration file defining all RBAC assignments.

**Structure**:
```json
{
  "description": "RBAC configuration for {environment}",
  "environment": "dev|staging|prod",
  "roleAssignments": [
    {
      "principalType": "User|Group|ServicePrincipal",
      "principalIdentifier": "name or UPN",
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

## Role Assignment Process

### Step-by-Step Guide

#### Step 1: Define Requirements

Identify:
1. **Who** needs access (users, groups, service principals)
2. **What** they need to do (read, write, manage)
3. **Where** they need access (subscription, resource group, resource)
4. **Why** they need this access (justification)

#### Step 2: Choose Appropriate Roles

Follow the principle of least privilege:

| Scenario | Recommended Role |
|----------|------------------|
| View all resources | `Reader` |
| Manage resources (no RBAC changes) | `Contributor` |
| Full control including RBAC | `Owner` |
| Read/write blob storage | `Storage Blob Data Contributor` |
| Read blob storage only | `Storage Blob Data Reader` |
| Read Key Vault secrets | `Key Vault Secrets User` |
| Security auditing | `Security Reader` |
| View logs and metrics | `Monitoring Reader` |

#### Step 3: Configure Role Assignments

Add entries to the appropriate configuration file:

```json
{
  "principalType": "ServicePrincipal",
  "principalIdentifier": "kbudget-dev-app",
  "role": "Storage Blob Data Contributor",
  "scope": {
    "type": "StorageAccount",
    "name": "kbudgetdevstorage"
  },
  "justification": "App Service needs to read/write blob data for user uploads"
}
```

#### Step 4: Preview Changes

Always preview changes before applying:

```powershell
.\Assign-RBAC.ps1 -Environment dev -WhatIf
```

Review the output to ensure:
- Principals are correctly identified
- Roles are appropriate
- Scopes are correct

#### Step 5: Apply Changes

```powershell
.\Assign-RBAC.ps1 -Environment dev
```

#### Step 6: Verify and Test

```powershell
# Verify assignments exist
.\Test-RBAC.ps1 -Environment dev

# Audit for compliance
.\Audit-RBAC.ps1 -Environment dev
```

#### Step 7: Document

Update documentation with:
- Date of change
- Justification
- Approval (if required)
- Testing results

## Service Principal Configuration

### Least-Privilege Guidelines

Service principals and managed identities should have the minimum permissions required.

#### Best Practices

✅ **DO**:
- Use managed identities instead of service principals when possible
- Assign resource-specific roles (e.g., `Storage Blob Data Reader`)
- Scope permissions to specific resources
- Regularly rotate service principal secrets
- Use `Contributor` or lower for automation

❌ **DON'T**:
- Assign `Owner` role to service principals
- Use `User Access Administrator` for service principals
- Share service principal credentials across environments
- Grant subscription-level access unless absolutely necessary

### Common Service Principal Scenarios

#### App Service Accessing Blob Storage

```json
{
  "principalType": "ServicePrincipal",
  "principalIdentifier": "kbudget-prod-app",
  "role": "Storage Blob Data Contributor",
  "scope": {
    "type": "StorageAccount",
    "name": "kbudgetprodstorage"
  },
  "justification": "App needs read/write access to user-uploaded files"
}
```

#### App Service Reading Key Vault Secrets

```json
{
  "principalType": "ServicePrincipal",
  "principalIdentifier": "kbudget-prod-app",
  "role": "Key Vault Secrets User",
  "scope": {
    "type": "KeyVault",
    "name": "kbudget-prod-kv"
  },
  "justification": "App needs to read connection strings and API keys"
}
```

#### CI/CD Pipeline Deploying Resources

```json
{
  "principalType": "ServicePrincipal",
  "principalIdentifier": "kbudget-automation",
  "role": "Contributor",
  "scope": {
    "type": "ResourceGroup",
    "name": "kbudget-dev-rg"
  },
  "justification": "CI/CD pipeline needs to deploy and update resources"
}
```

### Managed Identity Setup

When using managed identities, enable them on the resource:

```powershell
# Enable system-assigned managed identity on App Service
Set-AzWebApp -ResourceGroupName "kbudget-prod-rg" `
    -Name "kbudget-prod-app" `
    -AssignIdentity $true

# Get the managed identity principal ID
$app = Get-AzWebApp -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-app"
$principalId = $app.Identity.PrincipalId

# Assign role to managed identity
New-AzRoleAssignment -ObjectId $principalId `
    -RoleDefinitionName "Storage Blob Data Contributor" `
    -Scope "/subscriptions/{subscription-id}/resourceGroups/kbudget-prod-rg/providers/Microsoft.Storage/storageAccounts/kbudgetprodstorage"
```

## Audit Process

### Regular Audits

| Audit Type | Frequency | Owner | Deliverables |
|------------|-----------|-------|--------------|
| **Routine Audit** | Monthly | Security Team | Audit report, remediation list |
| **Comprehensive Review** | Quarterly | Security + DevOps | Full compliance report |
| **Post-Deployment Audit** | After each deployment | DevOps Team | Deployment validation |
| **Compliance Audit** | Annually | Compliance Officer | Regulatory compliance report |

### Audit Workflow

#### 1. Generate Audit Report

```powershell
# Run audit script
.\Audit-RBAC.ps1 -Environment prod -DetailedReport

# Output files:
# - logs/rbac_audit_prod_{timestamp}.log
# - reports/rbac_audit_prod_{timestamp}.json
# - reports/rbac_audit_prod_{timestamp}.csv
# - reports/rbac_audit_prod_{timestamp}_high_privilege.csv
```

#### 2. Review Audit Report

Examine the generated reports for:

**High-Priority Issues**:
- Service principals with `Owner` role
- Service principals with `User Access Administrator` role
- Unauthorized production access
- Orphaned role assignments (deleted principals)

**Medium-Priority Issues**:
- Excessive `Contributor` assignments
- Broad scope assignments (subscription vs. resource group)
- Missing justifications

**Best Practice Violations**:
- Individual user assignments instead of groups
- Resource-level permissions using generic roles

#### 3. Remediate Issues

For each issue identified:

1. **Assess Impact**: Determine if removal will affect operations
2. **Create Plan**: Document changes and approvals
3. **Update Config**: Modify configuration files
4. **Test Changes**: Use WhatIf mode
5. **Apply Changes**: Execute assignment script
6. **Verify**: Run test script

#### 4. Document Findings

Maintain audit log with:
- Date of audit
- Issues found
- Remediation actions
- Responsible parties
- Follow-up items

### Key Audit Metrics

Track these metrics over time:

| Metric | Target | Current | Trend |
|--------|--------|---------|-------|
| Service principals with Owner role | 0 | - | - |
| Service principals with UAA role | 0 | - | - |
| High-privilege accounts | < 5 | - | - |
| Orphaned assignments | 0 | - | - |
| Assignments without justification | 0 | - | - |

## Compliance and Security

### Regulatory Compliance

RBAC supports compliance with:

#### SOC 2 (Trust Services Criteria)

- **CC6.1**: Logical access controls
- **CC6.2**: Prior to granting access, organization registers and authorizes new internal users
- **CC6.3**: Organization removes access when appropriate

**Evidence**: Audit reports, role assignment logs, access reviews

#### ISO 27001

- **A.9.1**: Business requirements for access control
- **A.9.2**: User access management
- **A.9.4**: System and application access control

**Evidence**: RBAC policies, access control procedures, audit logs

#### PCI DSS

- **Requirement 7**: Restrict access to cardholder data by business need to know
- **Requirement 8**: Assign unique ID to each person with access

**Evidence**: Role definitions, assignment justifications, audit reports

### Security Controls

#### Authentication
- Azure AD authentication for all principals
- Multi-factor authentication (MFA) required for high-privilege roles
- Conditional access policies for production access

#### Authorization
- Role-based access control (RBAC)
- Least-privilege principle
- Segregation of duties

#### Auditing
- All role assignment changes logged to Azure Activity Log
- Regular audit reports generated
- Security Information and Event Management (SIEM) integration

#### Monitoring
- Azure Monitor alerts for RBAC changes
- Notifications for high-privilege role assignments
- Automated compliance checks

### Security Best Practices

1. **Use Groups for Assignment**
   - Assign roles to groups, not individual users
   - Easier to manage and audit
   - Consistent access patterns

2. **Implement Least Privilege**
   - Start with minimum permissions
   - Add permissions only as needed
   - Regular reviews to remove excess

3. **Separate Environments**
   - Different access levels for dev/staging/prod
   - Developers: Full access to dev, read-only to production
   - Production: Limited to authorized personnel

4. **Protect Service Principal Credentials**
   - Store in Azure Key Vault
   - Rotate regularly (every 90 days)
   - Use managed identities when possible

5. **Enable Just-In-Time (JIT) Access**
   - Azure AD Privileged Identity Management (PIM)
   - Temporary elevated access
   - Approval workflows for production

6. **Monitor and Alert**
   - Alert on Owner role assignments
   - Alert on service principal role changes
   - Review Activity Log regularly

## Troubleshooting

### Common Issues

#### Issue: Permission Denied

**Symptoms**: `Insufficient privileges to complete the operation`

**Cause**: User lacks required permissions to assign roles

**Solution**:
1. Verify current permissions:
   ```powershell
   Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id
   ```
2. Request `Owner` or `User Access Administrator` role
3. Use appropriate account with permissions

#### Issue: Principal Not Found

**Symptoms**: `Cannot find principal in Azure AD`

**Cause**: User, group, or service principal doesn't exist or name is incorrect

**Solution**:
1. Verify principal exists:
   ```powershell
   # For users
   Get-AzADUser -UserPrincipalName "user@domain.com"
   
   # For groups
   Get-AzADGroup -DisplayName "GroupName"
   
   # For service principals
   Get-AzADServicePrincipal -DisplayName "SPName"
   ```
2. Correct the principal identifier in configuration file
3. Create the principal if it doesn't exist

#### Issue: Resource Not Found

**Symptoms**: `Failed to determine scope for resource`

**Cause**: Resource doesn't exist or name is incorrect

**Solution**:
1. List resources in resource group:
   ```powershell
   Get-AzResource -ResourceGroupName "kbudget-dev-rg"
   ```
2. Verify resource name in configuration matches actual name
3. Create resource if it doesn't exist

#### Issue: Role Assignment Already Exists

**Symptoms**: `Role assignment already exists` (Warning, not error)

**Cause**: Assignment already in place (expected behavior)

**Solution**: No action needed. Script is idempotent and skips existing assignments.

### Debugging

#### Enable Verbose Logging

```powershell
.\Assign-RBAC.ps1 -Environment dev -Verbose
```

#### Review Log Files

```powershell
# View recent log entries
Get-Content logs/rbac_assignment_dev_*.log -Tail 50

# Search for errors
Select-String -Path logs/rbac_*.log -Pattern "ERROR"
```

#### Manual Verification

```powershell
# Check specific role assignment
$rg = Get-AzResourceGroup -Name "kbudget-dev-rg"
Get-AzRoleAssignment -Scope $rg.ResourceId

# Check assignments for specific principal
Get-AzRoleAssignment -ObjectId "principal-object-id"
```

## References

### Azure Documentation

- [Azure RBAC Overview](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview)
- [Azure Built-in Roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Azure Custom Roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles)
- [Managed Identities for Azure Resources](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Azure AD Privileged Identity Management](https://docs.microsoft.com/en-us/azure/active-directory/privileged-identity-management/)

### KBudget GPT Documentation

- [RBAC Scripts README](../infrastructure/arm-templates/rbac/README.md)
- [RBAC Quick Reference](../infrastructure/arm-templates/rbac/QUICK-REFERENCE.md)
- [PowerShell Deployment Guide](POWERSHELL-DEPLOYMENT-GUIDE.md)
- [Azure AD Authentication Setup](AAD-AUTHENTICATION-SETUP-GUIDE.md)
- [Compliance Documentation](COMPLIANCE-DOCUMENTATION.md)
- [Azure Resource Group Best Practices](azure-resource-group-best-practices.md)

### Related Resources

- [Azure Security Baseline](https://docs.microsoft.com/en-us/security/benchmark/azure/baselines/azure-resource-manager-security-baseline)
- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [Least Privilege Access](https://docs.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices#enable-password-management)

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-13  
**Owner**: Security and DevOps Team  
**Review Cycle**: Quarterly  
**Next Review**: 2026-05-13
