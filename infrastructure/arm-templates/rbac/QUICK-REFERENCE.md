# RBAC Quick Reference Guide

## Quick Commands

### Assign Roles
```powershell
# Development
.\Assign-RBAC.ps1 -Environment dev

# Staging
.\Assign-RBAC.ps1 -Environment staging

# Production (preview first)
.\Assign-RBAC.ps1 -Environment prod -WhatIf
.\Assign-RBAC.ps1 -Environment prod
```

### Audit Roles
```powershell
# Quick audit
.\Audit-RBAC.ps1 -Environment dev

# Detailed audit
.\Audit-RBAC.ps1 -Environment prod -DetailedReport
```

### Test Roles
```powershell
# Test assignments
.\Test-RBAC.ps1 -Environment dev

# Test with security validation
.\Test-RBAC.ps1 -Environment prod -ValidateLeastPrivilege
```

## Common Role Assignments

### Users and Groups

```json
{
  "principalType": "Group",
  "principalIdentifier": "KBudget-Developers",
  "role": "Contributor",
  "scope": { "type": "ResourceGroup", "name": "kbudget-dev-rg" }
}
```

### Service Principals (Least Privilege)

```json
{
  "principalType": "ServicePrincipal",
  "principalIdentifier": "kbudget-dev-app",
  "role": "Storage Blob Data Contributor",
  "scope": { "type": "StorageAccount", "name": "kbudgetdevstorage" }
}
```

## Role Decision Matrix

| Need | Recommended Role |
|------|------------------|
| Read resources only | `Reader` |
| Manage resources (no RBAC) | `Contributor` |
| Full control (with RBAC) | `Owner` |
| Read/write blobs | `Storage Blob Data Contributor` |
| Read blobs only | `Storage Blob Data Reader` |
| Read Key Vault secrets | `Key Vault Secrets User` |
| Security auditing | `Security Reader` |
| View monitoring data | `Monitoring Reader` |

## Troubleshooting Quick Fixes

### Permission Denied
```powershell
# Check your permissions
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id
```

### Principal Not Found
```powershell
# Find users
Get-AzADUser -SearchString "username"

# Find groups
Get-AzADGroup -SearchString "groupname"

# Find service principals
Get-AzADServicePrincipal -SearchString "appname"
```

### Verify Resource Exists
```powershell
# List all resources in resource group
Get-AzResource -ResourceGroupName "kbudget-dev-rg"
```

## Security Checklist

- [ ] No service principals with `Owner` role
- [ ] No service principals with `User Access Administrator` role
- [ ] All assignments documented with justification
- [ ] Separate production access from non-production
- [ ] Regular audit reports generated
- [ ] Least-privilege roles used where possible

## Output Locations

- **Logs**: `logs/rbac_*_{environment}_{timestamp}.log`
- **Reports**: `reports/rbac_audit_{environment}_{timestamp}.{json|csv}`
- **Config**: `rbac-config.{environment}.json`

## Best Practices Summary

1. **Use groups** instead of individual users
2. **Assign roles** at the lowest necessary scope
3. **Document** all assignments with justifications
4. **Audit** regularly (monthly for production)
5. **Test** after making changes
6. **Use managed identities** instead of service principals when possible

---

For detailed documentation, see [README.md](README.md)
