# Azure Access Reviews

## Overview

This directory contains scripts and templates for conducting regular access reviews of Azure resources in the KBudget GPT budgeting solution. Access reviews ensure compliance with security policies, maintain least privilege access, and meet regulatory requirements.

## Contents

- **Conduct-AccessReview.ps1** - Main script for conducting automated access reviews
- **templates/** - Sign-off forms and documentation templates
- **reports/** - Generated access review reports (CSV, JSON, Excel)
- **logs/** - Execution logs and audit trails

## Quick Start

### Prerequisites

1. **Azure PowerShell Module**
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   ```

2. **Azure Authentication**
   ```powershell
   Connect-AzAccount
   ```

3. **ImportExcel Module** (Optional, for Excel reports)
   ```powershell
   Install-Module -Name ImportExcel -Scope CurrentUser
   ```

### Running Access Reviews

**Quarterly Review (All Environments):**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType Quarterly
```

**Production Environment Only:**
```powershell
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType Quarterly
```

**Monthly High-Privilege Review:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege
```

**Service Principal Review:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType ServicePrincipal
```

**Annual Comprehensive Review:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType Annual -OutputFormat All
```

## Review Schedule

| Review Type | Frequency | Command |
|-------------|-----------|---------|
| **Quarterly Review** | Every 3 months (Jan 15, Apr 15, Jul 15, Oct 15) | `.\Conduct-AccessReview.ps1 -ReviewType Quarterly` |
| **High-Privilege Review** | Monthly (1st Monday) | `.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege` |
| **Service Principal Review** | Quarterly | `.\Conduct-AccessReview.ps1 -ReviewType ServicePrincipal` |
| **Annual Review** | December 1-31 | `.\Conduct-AccessReview.ps1 -ReviewType Annual` |

## Review Process

### 1. Preparation (Days 1-2)

Run the access review script to generate reports:

```powershell
# Generate comprehensive reports
.\Conduct-AccessReview.ps1 -ReviewType Quarterly -OutputFormat All

# Review the generated reports in the reports/ directory
```

### 2. Review and Validation (Days 3-10)

Review the generated reports:
- **users.csv** - All user role assignments
- **service_principals.csv** - Service principal access
- **high_privilege.csv** - Accounts with Owner/Contributor roles
- **orphaned.csv** - Assignments for deleted/inactive accounts
- **findings.csv** - Security findings requiring attention

For each assignment, verify:
- [ ] User/service principal is still active
- [ ] Access is still required
- [ ] Role is appropriate (least privilege)
- [ ] Scope is as narrow as possible
- [ ] Business justification exists

### 3. Remediation (Days 11-13)

Implement approved changes:

**Remove Access:**
```powershell
Remove-AzRoleAssignment `
    -SignInName "user@domain.com" `
    -RoleDefinitionName "Contributor" `
    -ResourceGroupName "kbudget-prod-rg"
```

**Reduce Permissions:**
```powershell
# Remove high-privilege role
Remove-AzRoleAssignment -ObjectId <object-id> -RoleDefinitionName "Contributor" -Scope <scope>

# Add resource-specific role
New-AzRoleAssignment -ObjectId <object-id> -RoleDefinitionName "Storage Blob Data Contributor" -Scope <storage-scope>
```

**Update RBAC Configuration:**
```powershell
cd ../rbac
# Edit rbac-config.prod.json
.\Assign-RBAC.ps1 -Environment prod
```

### 4. Documentation and Sign-Off (Days 14-15)

Complete the sign-off template:
1. Fill out the generated sign-off form in `templates/`
2. Obtain required approvals:
   - Security Team Lead (all reviews)
   - CISO (production reviews)
   - Compliance Officer (annual review)
3. Archive completed forms and reports

## Script Parameters

### Conduct-AccessReview.ps1

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Environment` | string | No | "all" | Environment to review: dev, staging, prod, all |
| `-ReviewType` | string | Yes | - | Type of review: Quarterly, Monthly, Annual, HighPrivilege, ServicePrincipal, Custom |
| `-ReviewDate` | string | No | Today | Date of the review (yyyy-MM-dd) |
| `-ReviewId` | string | No | Auto-generated | Unique review identifier |
| `-OutputFormat` | string | No | "All" | Output format: JSON, CSV, Excel, All |
| `-DetailedReport` | switch | No | False | Include detailed resource-level analysis |

### Examples

**Basic Quarterly Review:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType Quarterly
```

**Production Review with Custom ID:**
```powershell
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType Quarterly -ReviewId "AR-2026-Q1-PROD"
```

**High-Privilege Review (JSON only):**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege -OutputFormat JSON
```

**Detailed Annual Review:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType Annual -DetailedReport
```

## Output Files

The script generates the following files in the `reports/` directory:

### Reports

- `access_review_{ReviewId}_{timestamp}.json` - Complete review data in JSON format
- `access_review_{ReviewId}_{timestamp}_users.csv` - User role assignments
- `access_review_{ReviewId}_{timestamp}_service_principals.csv` - Service principal access
- `access_review_{ReviewId}_{timestamp}_high_privilege.csv` - High-privilege accounts
- `access_review_{ReviewId}_{timestamp}_orphaned.csv` - Orphaned/inactive assignments
- `access_review_{ReviewId}_{timestamp}_findings.csv` - Security findings
- `access_review_{ReviewId}_{timestamp}.xlsx` - Excel workbook with all data (requires ImportExcel module)

### Templates

- `access_review_signoff_{ReviewId}.txt` - Sign-off form template

### Logs

- `access_review_{ReviewId}_{timestamp}.log` - Execution log

## Report Structure

### Users CSV
- DisplayName
- SignInName
- UserPrincipalName
- ObjectType
- RoleDefinitionName
- Scope
- Environment
- AccountEnabled
- IsOrphaned

### Service Principals CSV
- DisplayName
- ApplicationId
- ObjectType
- RoleDefinitionName
- Scope
- Environment
- ServicePrincipalType
- SecretExpiration
- DaysUntilSecretExpiry

### Findings CSV
- Severity (Critical, High, Medium, Low)
- Type
- Principal
- Description
- RecommendedAction

## Common Findings and Remediation

### Critical Findings

**Service Principal with Owner Role**
- **Risk:** Service principals should never have Owner role
- **Action:** Reduce to Contributor or resource-specific role
- **Command:**
  ```powershell
  Remove-AzRoleAssignment -ObjectId <sp-id> -RoleDefinitionName "Owner" -Scope <scope>
  New-AzRoleAssignment -ObjectId <sp-id> -RoleDefinitionName "Storage Blob Data Contributor" -Scope <storage-scope>
  ```

### High Findings

**Service Principal Secret Expiring Soon**
- **Risk:** Expired secrets cause application failures
- **Action:** Rotate service principal secret
- **Command:**
  ```powershell
  $sp = Get-AzADServicePrincipal -DisplayName "kbudget-prod-app"
  $newSecret = New-AzADServicePrincipalCredential -ObjectId $sp.Id -EndDate (Get-Date).AddDays(365)
  # Update Key Vault with new secret
  Set-AzKeyVaultSecret -VaultName "kbudget-prod-kv" -Name "AppSecret" -SecretValue (ConvertTo-SecureString $newSecret.SecretText -AsPlainText -Force)
  ```

**Orphaned Assignment**
- **Risk:** Access for deleted accounts is a security vulnerability
- **Action:** Remove orphaned assignment
- **Command:**
  ```powershell
  Remove-AzRoleAssignment -ObjectId <object-id> -RoleDefinitionName <role> -Scope <scope>
  ```

### Medium Findings

**User with Unnecessary Contributor Role**
- **Risk:** Over-privileged access violates least privilege
- **Action:** Reduce to Reader or resource-specific role
- **Command:**
  ```powershell
  Remove-AzRoleAssignment -SignInName "user@domain.com" -RoleDefinitionName "Contributor" -Scope <scope>
  New-AzRoleAssignment -SignInName "user@domain.com" -RoleDefinitionName "Reader" -Scope <scope>
  ```

## Compliance

This access review process supports compliance with:

- **SOC 2 Type II** - CC6.3 (Access removal when appropriate)
- **ISO 27001** - A.9.2.5 (Review of user access rights)
- **PCI DSS** - Requirement 7.2 (Review user access rights)
- **GDPR** - Article 32 (Security of processing)
- **NIST 800-53** - AC-2 (Account Management)

## Troubleshooting

### Issue: Permission Denied

**Error:** `Insufficient privileges to complete the operation`

**Solution:**
1. Ensure you're authenticated: `Connect-AzAccount`
2. Verify you have Reader role or higher on the subscription/resource group
3. Contact subscription administrator to grant appropriate permissions

### Issue: Module Not Found

**Error:** `The term 'Get-AzRoleAssignment' is not recognized`

**Solution:**
```powershell
Install-Module -Name Az -AllowClobber -Scope CurrentUser
Import-Module Az
```

### Issue: Excel Export Failed

**Error:** `Failed to create Excel report`

**Solution:**
```powershell
Install-Module -Name ImportExcel -Scope CurrentUser
```

### Issue: Resource Group Not Found

**Error:** `Failed to get resource group`

**Solution:**
1. Verify resource group exists: `Get-AzResourceGroup -Name "kbudget-prod-rg"`
2. Check you're in the correct subscription: `Get-AzContext`
3. Set the correct subscription: `Set-AzContext -Subscription "subscription-name"`

## Best Practices

1. **Schedule Regular Reviews**
   - Set calendar reminders for quarterly reviews
   - Automate review execution with Azure Automation or scheduled tasks

2. **Document Everything**
   - Maintain justification for all access
   - Keep sign-off forms for 7 years
   - Track remediation actions

3. **Follow Least Privilege**
   - Start with minimal permissions
   - Grant additional access only when justified
   - Use resource-specific roles instead of generic roles

4. **Monitor Continuously**
   - Review high-privilege accounts monthly
   - Set up alerts for new Owner/Contributor assignments
   - Audit service principal secret expirations

5. **Automate Remediation**
   - Use RBAC configuration files for consistent assignments
   - Implement Infrastructure as Code for reproducibility
   - Test changes in dev before applying to production

## Related Documentation

- [Access Review Process Guide](../../../docs/ACCESS-REVIEW-PROCESS.md) - Complete process documentation
- [RBAC Documentation](../../../docs/RBAC-DOCUMENTATION.md) - RBAC implementation guide
- [Compliance Documentation](../../../docs/COMPLIANCE-DOCUMENTATION.md) - Audit and compliance requirements
- [RBAC Scripts](../rbac/README.md) - RBAC assignment and audit scripts

## Support

For questions or issues with access reviews:
- **Security Team**: security-team@example.com
- **DevOps Team**: devops-team@example.com

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-02-14 | Initial access review implementation | DevOps Team |

---

**Document Classification:** Internal - Security and Compliance  
**Owner:** Security Team  
**Review Cycle:** Annually
