# Azure Access Review Process

## Executive Summary

This document defines the comprehensive access review process for Azure resources in the KBudget GPT budgeting solution. Regular access reviews ensure compliance with security policies, regulatory requirements, and the principle of least privilege.

## Table of Contents

1. [Overview](#overview)
2. [Access Review Schedule](#access-review-schedule)
3. [Scope of Access Reviews](#scope-of-access-reviews)
4. [Review Process](#review-process)
5. [Automated Review Script](#automated-review-script)
6. [Remediation Procedures](#remediation-procedures)
7. [Documentation and Sign-Off](#documentation-and-sign-off)
8. [Compliance and Audit](#compliance-and-audit)
9. [Roles and Responsibilities](#roles-and-responsibilities)

## Overview

### Purpose

Access reviews are conducted to:
- Ensure users and service principals have only the access they need
- Identify and remove orphaned or unauthorized access
- Maintain compliance with security policies and regulations
- Document access patterns for audit purposes
- Validate segregation of duties

### Regulatory Compliance

This process supports compliance with:
- **SOC 2 Type II** - CC6.3 (Access removal when appropriate)
- **ISO 27001** - A.9.2.5 (Review of user access rights)
- **PCI DSS** - Requirement 7.2 (Review user access rights)
- **GDPR** - Article 32 (Security of processing)
- **NIST 800-53** - AC-2 (Account Management)

### Principles

1. **Least Privilege**: Users should have minimum permissions required
2. **Need-to-Know**: Access based on business requirements only
3. **Regular Review**: Periodic validation of all access
4. **Documented Approval**: All changes require proper authorization
5. **Audit Trail**: Complete logging of review activities

## Access Review Schedule

### Review Frequency

| Review Type | Frequency | Owner | Duration |
|-------------|-----------|-------|----------|
| **Standard Access Review** | Quarterly | Security Team | 2 weeks |
| **High-Privilege Review** | Monthly | Security Team | 1 week |
| **Service Principal Review** | Quarterly | DevOps Team | 1 week |
| **Production Access Review** | Quarterly | Security Team + Manager | 2 weeks |
| **Annual Comprehensive Review** | Annually | CISO + Security Team | 1 month |

### Review Calendar

**Quarterly Reviews:**
- **Q1 Review**: January 15 - January 29
- **Q2 Review**: April 15 - April 29
- **Q3 Review**: July 15 - July 29
- **Q4 Review**: October 15 - October 29

**Monthly High-Privilege Reviews:**
- First Monday of each month
- Due by second Friday of the month

**Annual Comprehensive Review:**
- Starts: December 1
- Completed: December 31
- Sign-off required by January 15

## Scope of Access Reviews

### Azure Resources Covered

All access reviews must include the following resources:

#### 1. Resource Groups
- **Development** (`kbudget-dev-rg`)
- **Staging** (`kbudget-staging-rg`)
- **Production** (`kbudget-prod-rg`)

#### 2. Key Vault
- Secret access permissions
- Key access permissions
- Certificate access permissions
- Service principal access

#### 3. Storage Accounts
- Blob data access (read/write)
- Queue access
- Table access
- Container-level permissions

#### 4. Cosmos DB Database
- Database roles and permissions
- Server-level access
- Firewall rules
- AAD administrators

#### 5. App Service
- Deployment slots access
- Configuration settings access
- Log access
- FTP/SCM credentials

#### 6. Azure Functions
- Function app access
- Configuration access
- Deployment access

#### 7. Log Analytics Workspace
- Query access
- Configuration access
- Data export permissions

#### 8. Subscription-Level
- Subscription Owner/Contributor roles
- User Access Administrator role
- Custom role assignments

### Access Types Reviewed

1. **User Access**
   - Individual user role assignments
   - User group memberships
   - Guest user access
   - Inactive user accounts

2. **Service Principal Access**
   - Application service principals
   - Managed identities
   - CI/CD pipeline identities
   - Automation account identities

3. **Group Access**
   - Azure AD group assignments
   - Group membership validity
   - Group ownership

4. **Administrative Access**
   - Owner role assignments
   - Contributor role assignments
   - User Access Administrator
   - Custom high-privilege roles

## Review Process

### Phase 1: Preparation (Days 1-2)

#### Step 1: Generate Access Reports

Run the automated access review script:

```powershell
cd infrastructure/arm-templates/access-reviews

# Generate comprehensive access review reports for all environments
.\Conduct-AccessReview.ps1 -ReviewType Quarterly

# Generate specific environment review
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType Quarterly

# Generate high-privilege review
.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege
```

#### Step 2: Review Generated Reports

The script generates the following reports:
- `access_review_{env}_{date}.xlsx` - Main review workbook
- `access_review_{env}_{date}.json` - Detailed JSON report
- `high_privilege_accounts_{date}.csv` - High-privilege accounts list
- `orphaned_assignments_{date}.csv` - Orphaned/inactive assignments
- `service_principals_{date}.csv` - Service principal access list

#### Step 3: Distribute Review Packages

Send review packages to appropriate reviewers:
- **Resource Owners**: Review access to their resources
- **Team Managers**: Review team member access
- **Security Team**: Review all high-privilege access
- **CISO**: Sign-off on production access

### Phase 2: Review and Validation (Days 3-10)

#### Step 1: User Access Validation

For each user assignment, verify:

✅ **User is Active**: User is still employed/active in the organization  
✅ **Role is Appropriate**: Role matches job function and responsibilities  
✅ **Scope is Correct**: Access scope is as narrow as possible  
✅ **Business Justification**: Valid business need for access  
✅ **No Duplication**: No redundant role assignments

**Review Questions:**
1. Does this user still need this access?
2. Is this the minimum level of access required?
3. Has the user's role changed since last review?
4. Are there any access violations or anomalies?

#### Step 2: Service Principal Validation

For each service principal, verify:

✅ **Active and In-Use**: Service principal is actively being used  
✅ **Least Privilege**: Has minimum permissions required  
✅ **Proper Scope**: Scoped to specific resources, not subscription  
✅ **Secret Rotation**: Secrets rotated within policy (90 days)  
✅ **Owner Identified**: Clear ownership and purpose documented

**Service Principal Review Checklist:**
- [ ] Service principal name is descriptive and follows naming convention
- [ ] Purpose and owner are documented
- [ ] Permissions follow least privilege principle
- [ ] No Owner or User Access Administrator role (unless justified)
- [ ] Secrets/certificates are current and rotated regularly
- [ ] Service principal is still actively used (check last sign-in)

#### Step 3: High-Privilege Account Review

**High-Privilege Roles:**
- Owner
- Contributor (on production)
- User Access Administrator
- Custom roles with write permissions on production

**Special Scrutiny Required:**
- Justification must be documented
- Manager approval required
- MFA enforcement verified
- Conditional access policies applied
- Access should be time-limited when possible

**Red Flags:**
- ❌ Service principal with Owner role
- ❌ Guest users with Contributor or higher
- ❌ Individual user with subscription-level Owner
- ❌ Shared accounts or service accounts
- ❌ Access without documented justification

### Phase 3: Remediation (Days 11-13)

#### Remediation Actions

Based on review findings, take appropriate actions:

**1. Remove Access**
- Terminated employees
- Obsolete service principals
- Temporary access that has expired
- Access no longer required

**2. Reduce Permissions**
- Downgrade from Owner to Contributor
- Change from Contributor to Reader
- Narrow scope from resource group to resource
- Switch to resource-specific roles

**3. Update Documentation**
- Add missing justifications
- Update ownership information
- Correct resource descriptions
- Update contact information

**4. Security Improvements**
- Enable MFA where missing
- Apply conditional access policies
- Rotate service principal secrets
- Enable managed identities

#### Remediation Workflow

```
┌─────────────────────────────────────────────┐
│ 1. Identify Access to Remove/Modify        │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│ 2. Document Remediation Plan               │
│    - What will change                       │
│    - Why it's changing                      │
│    - Impact assessment                      │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│ 3. Get Approval                            │
│    - Resource owner approval                │
│    - Security team approval                 │
│    - Manager approval (for user access)     │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│ 4. Implement Changes                       │
│    - Use RBAC scripts                       │
│    - Update configuration files             │
│    - Test access after changes              │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│ 5. Verify and Document                     │
│    - Confirm changes were applied           │
│    - Update access review records           │
│    - Notify affected users                  │
└─────────────────────────────────────────────┘
```

### Phase 4: Documentation and Sign-Off (Days 14-15)

#### Finalize Documentation

Complete the access review documentation:

1. **Executive Summary**
   - Total accounts reviewed
   - Number of findings
   - Remediation actions taken
   - Outstanding issues

2. **Detailed Findings**
   - List of all access reviewed
   - Changes made
   - Justifications
   - Approvals obtained

3. **Compliance Status**
   - Compliance with policy
   - Exceptions granted
   - Risk assessment

4. **Next Steps**
   - Follow-up actions required
   - Next review date
   - Policy updates needed

#### Obtain Sign-Off

Required approvals:

**Security Team Lead:**
- Reviews all findings
- Approves remediation actions
- Signs off on security compliance

**CISO (for Production):**
- Reviews production access
- Approves high-privilege access
- Signs off on risk acceptance

**Compliance Officer (Annual Review):**
- Reviews compliance status
- Validates audit trail
- Signs off on regulatory compliance

## Automated Review Script

### Script Location

```
infrastructure/arm-templates/access-reviews/Conduct-AccessReview.ps1
```

### Usage Examples

**Quarterly Review - All Environments:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType Quarterly
```

**Production Environment Only:**
```powershell
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType Quarterly
```

**High-Privilege Accounts Monthly Review:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege
```

**Service Principal Review:**
```powershell
.\Conduct-AccessReview.ps1 -ReviewType ServicePrincipal
```

**Custom Review with Specific Date:**
```powershell
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType Custom -ReviewDate "2026-03-15"
```

### Script Features

✅ Automated data collection from Azure  
✅ Generates comprehensive Excel reports  
✅ Identifies high-privilege accounts  
✅ Detects orphaned assignments  
✅ Checks service principal secret expiration  
✅ Validates MFA enforcement  
✅ Creates audit trail  
✅ Supports multiple output formats (JSON, CSV, Excel)  

### Report Contents

The access review report includes:

1. **Summary Dashboard**
   - Total users, groups, service principals
   - High-privilege account count
   - Orphaned assignment count
   - Compliance status

2. **User Access Tab**
   - User name and email
   - Role assignments
   - Resource scope
   - Last sign-in date
   - MFA status
   - Review status

3. **Service Principal Tab**
   - Service principal name
   - Application ID
   - Role assignments
   - Secret expiration
   - Last used date
   - Owner

4. **High Privilege Tab**
   - Principal name
   - Principal type
   - Role (Owner/Contributor/etc.)
   - Scope
   - Justification
   - Approval status

5. **Findings Tab**
   - Issue description
   - Severity (Critical/High/Medium/Low)
   - Recommended action
   - Status
   - Assigned to

## Remediation Procedures

### Removing User Access

**PowerShell Script:**
```powershell
# Remove specific role assignment
Remove-AzRoleAssignment `
    -SignInName "user@domain.com" `
    -RoleDefinitionName "Contributor" `
    -ResourceGroupName "kbudget-prod-rg"

# Verify removal
Get-AzRoleAssignment -SignInName "user@domain.com" `
    -ResourceGroupName "kbudget-prod-rg"
```

**Documentation Required:**
- [ ] Date of removal
- [ ] User name and email
- [ ] Role and scope removed
- [ ] Reason for removal
- [ ] Approver name and signature
- [ ] User notification sent

### Modifying Service Principal Permissions

**Step 1: Remove Existing Assignment**
```powershell
# Get service principal object ID
$sp = Get-AzADServicePrincipal -DisplayName "kbudget-prod-app"

# Remove current assignment
Remove-AzRoleAssignment `
    -ObjectId $sp.Id `
    -RoleDefinitionName "Contributor" `
    -ResourceGroupName "kbudget-prod-rg"
```

**Step 2: Add New Assignment with Lower Privilege**
```powershell
# Assign more specific role
New-AzRoleAssignment `
    -ObjectId $sp.Id `
    -RoleDefinitionName "Storage Blob Data Contributor" `
    -Scope "/subscriptions/{sub-id}/resourceGroups/kbudget-prod-rg/providers/Microsoft.Storage/storageAccounts/kbudgetprodstorage"
```

**Step 3: Update Configuration**
```powershell
# Update RBAC configuration file
cd infrastructure/arm-templates/rbac
# Edit rbac-config.prod.json to reflect new permissions
```

**Step 4: Test Application**
- [ ] Verify application still functions correctly
- [ ] Check application logs for permission errors
- [ ] Test all critical workflows
- [ ] Monitor for 24 hours

### Rotating Service Principal Secrets

**When Required:**
- Service principal secret expiring within 30 days
- Security incident or breach
- Quarterly rotation policy
- Access review finding

**Rotation Process:**
```powershell
# Create new secret
$sp = Get-AzADServicePrincipal -DisplayName "kbudget-prod-app"
$newSecret = New-AzADServicePrincipalCredential `
    -ObjectId $sp.Id `
    -EndDate (Get-Date).AddDays(365)

# Store new secret in Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-prod-kv" `
    -Name "AppServicePrincipalSecret" `
    -SecretValue (ConvertTo-SecureString $newSecret.SecretText -AsPlainText -Force)

# Update application configuration
# Test with new secret
# Remove old secret after verification
```

### Disabling Inactive Accounts

**Identification:**
- No sign-in activity in last 90 days
- Account marked as inactive in HR system
- User no longer with organization

**Procedure:**
1. **Verify Inactivity**: Check last sign-in date
2. **Notify Manager**: Confirm user should lose access
3. **Remove Azure Access**: Remove all RBAC assignments
4. **Disable AAD Account**: Disable in Azure AD (if applicable)
5. **Document**: Record in access review log

## Documentation and Sign-Off

### Access Review Log

Maintain a complete log of all access reviews:

**Location:** `infrastructure/arm-templates/access-reviews/logs/`

**Log Entry Format:**
```json
{
  "reviewId": "AR-2026-Q1-001",
  "reviewDate": "2026-01-15",
  "reviewType": "Quarterly",
  "environment": "Production",
  "reviewer": "security.team@example.com",
  "totalAccountsReviewed": 45,
  "findings": 12,
  "remediationActions": 8,
  "completionDate": "2026-01-29",
  "status": "Completed",
  "signOff": {
    "securityLead": {
      "name": "John Doe",
      "email": "john.doe@example.com",
      "date": "2026-01-29",
      "signature": "approved"
    },
    "ciso": {
      "name": "Jane Smith",
      "email": "jane.smith@example.com",
      "date": "2026-01-30",
      "signature": "approved"
    }
  }
}
```

### Sign-Off Template

**Access Review Approval Form**

```
================================================================================
AZURE ACCESS REVIEW - APPROVAL FORM
================================================================================

Review ID: AR-{YEAR}-{QUARTER}-{NUMBER}
Review Date: {DATE}
Review Type: {Quarterly/Monthly/Annual}
Environment(s): {Development/Staging/Production/All}

Review Summary:
---------------
Total Accounts Reviewed: ___________
  - Users: ___________
  - Groups: ___________
  - Service Principals: ___________

Findings:
---------
Critical: ___________
High: ___________
Medium: ___________
Low: ___________

Remediation Actions Taken:
--------------------------
Access Removed: ___________
Permissions Reduced: ___________
Documentation Updated: ___________
No Action Required: ___________

Outstanding Issues:
-------------------
☐ None
☐ List attached

Compliance Status:
------------------
☑ SOC 2 Type II - Compliant
☑ ISO 27001 - Compliant
☑ PCI DSS - Compliant
☑ GDPR - Compliant
☐ Exceptions (list below):
_________________________________________________________________________

Risk Assessment:
----------------
Overall Risk Level: ☐ Low  ☐ Medium  ☐ High
Risk Mitigation: ___________________________________________________________

Approvals:
----------

Security Team Lead:
Name: _________________________    Date: _______________
Signature: _____________________   Email: ______________

☐ Approved    ☐ Approved with Conditions    ☐ Rejected

Comments: ______________________________________________________________
_________________________________________________________________________


CISO (Required for Production):
Name: _________________________    Date: _______________
Signature: _____________________   Email: ______________

☐ Approved    ☐ Approved with Conditions    ☐ Rejected

Comments: ______________________________________________________________
_________________________________________________________________________


Compliance Officer (Required for Annual Review):
Name: _________________________    Date: _______________
Signature: _____________________   Email: ______________

☐ Approved    ☐ Approved with Conditions    ☐ Rejected

Comments: ______________________________________________________________
_________________________________________________________________________

Next Review Scheduled: _______________

================================================================================
```

### Audit Trail

All access review activities must be logged for audit purposes:

**Required Audit Information:**
- Date and time of review
- Reviewer identity
- Resources reviewed
- Findings identified
- Actions taken
- Approvals obtained
- Exception justifications

**Retention:**
- Review logs: 7 years
- Supporting documentation: 7 years
- Sign-off forms: 7 years (physical and electronic)

## Compliance and Audit

### Regulatory Mapping

| Regulation | Requirement | Implementation | Evidence |
|------------|-------------|----------------|----------|
| **SOC 2 Type II** | CC6.3 - Access removal | Quarterly access reviews | Review logs, sign-off forms |
| **ISO 27001** | A.9.2.5 - Access review | Automated review process | Access review reports |
| **PCI DSS** | 7.2 - Access review | Quarterly reviews with sign-off | Approval forms, audit logs |
| **GDPR** | Article 32 - Security measures | Access controls validation | Review documentation |
| **NIST 800-53** | AC-2 - Account management | Regular account reviews | Access review reports |

### Audit Checklist

During compliance audits, auditors will verify:

- [ ] Access reviews conducted on schedule
- [ ] All environments reviewed (dev, staging, production)
- [ ] High-privilege accounts reviewed monthly
- [ ] Service principals reviewed quarterly
- [ ] Findings documented and remediated
- [ ] Appropriate approvals obtained
- [ ] Audit trail maintained
- [ ] Policy exceptions documented and approved
- [ ] Access removal procedures followed
- [ ] Documentation retained per policy

### Metrics and Reporting

**Key Performance Indicators (KPIs):**

| Metric | Target | Reporting Frequency |
|--------|--------|-------------------|
| Review completion rate | 100% | Quarterly |
| Average time to remediate findings | < 5 days | Monthly |
| High-privilege accounts | < 5% of total | Monthly |
| Orphaned assignments | 0 | Quarterly |
| Service principal secret expiration | 0 expired | Monthly |
| MFA enforcement for admins | 100% | Monthly |

**Quarterly Report Template:**

```
Access Review Quarterly Report - Q{X} {YEAR}

Executive Summary:
- Reviews Completed: ___ of ___ (target: 100%)
- Total Accounts Reviewed: ___
- Findings Identified: ___
- Remediation Completion: ___% (target: 100%)
- High-Privilege Accounts: ___ (___%)
- Compliance Status: ☐ Compliant ☐ Non-Compliant

Trends:
- User access changes: +/- ___
- Service principal changes: +/- ___
- Policy violations: ___ (trend: ↑↓→)

Recommendations:
1. ___________________________________________________________
2. ___________________________________________________________
3. ___________________________________________________________

Next Quarter Focus:
___________________________________________________________________
```

## Roles and Responsibilities

### Security Team

**Responsibilities:**
- Conduct quarterly access reviews
- Review high-privilege accounts monthly
- Analyze review findings
- Coordinate remediation efforts
- Maintain review documentation
- Report to CISO

**Skills Required:**
- Azure RBAC expertise
- Security policy knowledge
- PowerShell scripting
- Compliance frameworks

### DevOps Team

**Responsibilities:**
- Review service principal access quarterly
- Rotate service principal secrets
- Implement RBAC changes
- Test access changes
- Maintain automation scripts

**Skills Required:**
- Azure PowerShell
- CI/CD pipeline management
- Infrastructure as Code
- Azure resource management

### Resource Owners

**Responsibilities:**
- Validate access to their resources
- Approve/reject access requests
- Provide business justification
- Report access issues

**Skills Required:**
- Resource knowledge
- Business requirements understanding

### Managers

**Responsibilities:**
- Review team member access
- Approve access changes
- Validate business need
- Report team changes (hires/departures)

**Skills Required:**
- Team knowledge
- Business process understanding

### CISO

**Responsibilities:**
- Sign off on production access reviews
- Approve high-privilege access
- Accept risk for exceptions
- Review compliance status

**Authority:**
- Final approval on security decisions
- Policy exception approval
- Audit sign-off

## Appendix

### A. Quick Reference Guide

**Monthly Tasks:**
```powershell
# First Monday of each month
cd infrastructure/arm-templates/access-reviews
.\Conduct-AccessReview.ps1 -ReviewType HighPrivilege
# Review output, remediate findings, get sign-off
```

**Quarterly Tasks:**
```powershell
# 15th of Jan, Apr, Jul, Oct
cd infrastructure/arm-templates/access-reviews
.\Conduct-AccessReview.ps1 -ReviewType Quarterly
# Distribute to reviewers
# Collect feedback
# Implement remediation
# Obtain sign-offs
# File documentation
```

**Annual Tasks:**
```powershell
# December 1
cd infrastructure/arm-templates/access-reviews
.\Conduct-AccessReview.ps1 -ReviewType Annual
# Comprehensive review
# Policy update assessment
# Compliance validation
# CISO sign-off
# Archive documentation
```

### B. Related Documentation

- [RBAC Documentation](RBAC-DOCUMENTATION.md)
- [Compliance Documentation](COMPLIANCE-DOCUMENTATION.md)
- [Azure AD Authentication Setup](AAD-AUTHENTICATION-SETUP-GUIDE.md)
- [Monitoring and Observability](MONITORING-OBSERVABILITY.md)

### C. Contact Information

**Security Team**: security-team@example.com  
**DevOps Team**: devops-team@example.com  
**CISO**: ciso@example.com  
**Compliance Officer**: compliance@example.com

### D. Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-02-14 | Initial access review process documentation | DevOps Team |

---

**Document Classification:** Internal - Security and Compliance  
**Review Cycle:** Annually  
**Next Review Date:** 2027-02-14  
**Owner:** Security Team
