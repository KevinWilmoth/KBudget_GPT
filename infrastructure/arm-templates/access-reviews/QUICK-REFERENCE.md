# Access Review Quick Reference

## Common Commands

### Quarterly Reviews

```powershell
# All environments
.\Conduct-AccessReview.ps1 -ReviewType Quarterly

# Production only
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType Quarterly

# Development only
.\Conduct-AccessReview.ps1 -Environment dev -ReviewType Quarterly
```

### Monthly Reviews

```powershell
# High-privilege accounts (1st Monday of month)
.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege
```

### Service Principal Reviews

```powershell
# Review all service principals
.\Conduct-AccessReview.ps1 -ReviewType ServicePrincipal

# Production service principals only
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType ServicePrincipal
```

### Annual Review

```powershell
# Comprehensive annual review
.\Conduct-AccessReview.ps1 -ReviewType Annual -DetailedReport
```

## Review Schedule

| Date | Review Type | Command |
|------|-------------|---------|
| 1st Monday of month | High-Privilege | `.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege` |
| Jan 15 - Jan 29 | Q1 Quarterly | `.\Conduct-AccessReview.ps1 -ReviewType Quarterly` |
| Apr 15 - Apr 29 | Q2 Quarterly | `.\Conduct-AccessReview.ps1 -ReviewType Quarterly` |
| Jul 15 - Jul 29 | Q3 Quarterly | `.\Conduct-AccessReview.ps1 -ReviewType Quarterly` |
| Oct 15 - Oct 29 | Q4 Quarterly | `.\Conduct-AccessReview.ps1 -ReviewType Quarterly` |
| Dec 1 - Dec 31 | Annual | `.\Conduct-AccessReview.ps1 -ReviewType Annual` |

## Remediation Commands

### Remove User Access

```powershell
Remove-AzRoleAssignment `
    -SignInName "user@domain.com" `
    -RoleDefinitionName "Contributor" `
    -ResourceGroupName "kbudget-prod-rg"
```

### Remove Service Principal Access

```powershell
$sp = Get-AzADServicePrincipal -DisplayName "service-principal-name"
Remove-AzRoleAssignment `
    -ObjectId $sp.Id `
    -RoleDefinitionName "Owner" `
    -ResourceGroupName "kbudget-prod-rg"
```

### Reduce Permissions

```powershell
# Remove broad permission
Remove-AzRoleAssignment `
    -ObjectId <object-id> `
    -RoleDefinitionName "Contributor" `
    -Scope "/subscriptions/{sub-id}/resourceGroups/kbudget-prod-rg"

# Add specific permission
New-AzRoleAssignment `
    -ObjectId <object-id> `
    -RoleDefinitionName "Storage Blob Data Contributor" `
    -Scope "/subscriptions/{sub-id}/resourceGroups/kbudget-prod-rg/providers/Microsoft.Storage/storageAccounts/kbudgetprodstorage"
```

### Rotate Service Principal Secret

```powershell
# Generate new secret
$sp = Get-AzADServicePrincipal -DisplayName "kbudget-prod-app"
$newSecret = New-AzADServicePrincipalCredential `
    -ObjectId $sp.Id `
    -EndDate (Get-Date).AddDays(365)

# Store in Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-prod-kv" `
    -Name "AppSecret" `
    -SecretValue (ConvertTo-SecureString $newSecret.SecretText -AsPlainText -Force)

# Test application with new secret
# Remove old secret after verification
Remove-AzADServicePrincipalCredential `
    -ObjectId $sp.Id `
    -KeyId <old-key-id>
```

## Verification Commands

### Check Current Role Assignments

```powershell
# For a specific user
Get-AzRoleAssignment -SignInName "user@domain.com"

# For a specific service principal
$sp = Get-AzADServicePrincipal -DisplayName "service-principal-name"
Get-AzRoleAssignment -ObjectId $sp.Id

# For a resource group
Get-AzRoleAssignment -ResourceGroupName "kbudget-prod-rg"
```

### Check Service Principal Details

```powershell
# Get service principal info
$sp = Get-AzADServicePrincipal -DisplayName "kbudget-prod-app"
$sp | Format-List

# Check secret expiration
$sp.PasswordCredentials | Select-Object KeyId, StartDateTime, EndDateTime
```

### Check User Activity

```powershell
# Get user details
Get-AzADUser -UserPrincipalName "user@domain.com"

# Check if account is enabled
$user = Get-AzADUser -UserPrincipalName "user@domain.com"
$user.AccountEnabled
```

## Review Checklist

### Pre-Review
- [ ] Azure PowerShell module installed
- [ ] Authenticated to Azure (`Connect-AzAccount`)
- [ ] Correct subscription selected
- [ ] Review scheduled on calendar

### During Review
- [ ] Run access review script
- [ ] Review generated reports
- [ ] Identify findings (critical, high, medium, low)
- [ ] Document business justifications
- [ ] Get resource owner approvals
- [ ] Create remediation plan

### Remediation
- [ ] Remove orphaned assignments
- [ ] Reduce over-privileged access
- [ ] Rotate expiring secrets
- [ ] Update documentation
- [ ] Test changes in dev first
- [ ] Apply changes to production
- [ ] Verify changes applied correctly

### Post-Review
- [ ] Complete sign-off template
- [ ] Obtain required approvals
  - [ ] Security Team Lead
  - [ ] CISO (for production)
  - [ ] Compliance Officer (for annual)
- [ ] Archive reports and documentation
- [ ] Schedule next review
- [ ] Send summary to stakeholders

## Critical Findings - Immediate Action

### Service Principal with Owner Role
**Priority:** CRITICAL  
**Action:** Reduce to Contributor or resource-specific role within 24 hours

### Orphaned Assignment
**Priority:** HIGH  
**Action:** Remove within 48 hours

### Service Principal Secret Expired
**Priority:** CRITICAL  
**Action:** Rotate immediately

### Service Principal Secret Expiring < 30 Days
**Priority:** HIGH  
**Action:** Schedule rotation within 1 week

### User with Production Owner Role
**Priority:** HIGH  
**Action:** Validate justification and approval, reduce if not justified

## Output Files Quick Reference

| File | Contents |
|------|----------|
| `*_users.csv` | User role assignments |
| `*_service_principals.csv` | Service principal access and secret expiration |
| `*_high_privilege.csv` | Owner/Contributor/UAA roles |
| `*_orphaned.csv` | Deleted/inactive account assignments |
| `*_findings.csv` | Security findings with severity |
| `*.json` | Complete review data |
| `*.xlsx` | Excel workbook with all tabs |
| `*_signoff.txt` | Sign-off form template |
| `*.log` | Execution log |

## Troubleshooting

### Can't Connect to Azure
```powershell
Connect-AzAccount
Set-AzContext -Subscription "subscription-name"
```

### Missing Module
```powershell
Install-Module -Name Az -AllowClobber -Scope CurrentUser
Install-Module -Name ImportExcel -Scope CurrentUser
```

### Permission Denied
- Verify you have Reader role or higher on subscription/resource group
- Contact subscription administrator for access

### Resource Group Not Found
```powershell
# List all resource groups
Get-AzResourceGroup

# Verify you're in correct subscription
Get-AzContext

# Change subscription if needed
Set-AzContext -Subscription "subscription-name"
```

## Contact Information

- **Security Team:** security-team@example.com
- **DevOps Team:** devops-team@example.com
- **CISO:** ciso@example.com

## Related Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| Conduct-AccessReview.ps1 | access-reviews/ | Main access review script |
| Audit-RBAC.ps1 | rbac/ | RBAC audit script |
| Assign-RBAC.ps1 | rbac/ | RBAC assignment script |
| Test-RBAC.ps1 | rbac/ | RBAC compliance testing |

---

**Last Updated:** 2026-02-14  
**Version:** 1.0.0
