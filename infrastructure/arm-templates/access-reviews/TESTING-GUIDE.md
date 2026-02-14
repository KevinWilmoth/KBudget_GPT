# Access Review Testing and Validation Guide

## Overview

This guide provides instructions for testing the access review process and validating that it meets all requirements.

## Testing Checklist

### 1. Script Functionality Testing

#### Prerequisites Validation
- [ ] Test without Azure PowerShell module installed
- [ ] Test without Azure authentication
- [ ] Verify error messages are clear and helpful

#### Environment Selection
- [ ] Test with `-Environment dev`
- [ ] Test with `-Environment staging`
- [ ] Test with `-Environment prod`
- [ ] Test with `-Environment all` (default)

#### Review Types
- [ ] Test `-ReviewType Quarterly`
- [ ] Test `-ReviewType Monthly`
- [ ] Test `-ReviewType Annual`
- [ ] Test `-ReviewType HighPrivilege`
- [ ] Test `-ReviewType ServicePrincipal`
- [ ] Test `-ReviewType Custom` with custom date

#### Output Formats
- [ ] Test `-OutputFormat JSON`
- [ ] Test `-OutputFormat CSV`
- [ ] Test `-OutputFormat Excel` (with ImportExcel module)
- [ ] Test `-OutputFormat All`

#### Error Handling
- [ ] Test with non-existent resource group
- [ ] Test with insufficient permissions
- [ ] Test with invalid environment name
- [ ] Test with invalid review type

### 2. Report Validation

#### JSON Report Contents
- [ ] Contains ReviewId
- [ ] Contains ReviewDate
- [ ] Contains ReviewType
- [ ] Contains GeneratedAt timestamp
- [ ] Contains Environments array with data for each environment
- [ ] Contains Summary with aggregate counts
- [ ] All required fields are populated

#### CSV Report Contents
- [ ] Users CSV has all expected columns
- [ ] Service Principals CSV has all expected columns
- [ ] High Privilege CSV has all expected columns
- [ ] Orphaned CSV generated when orphaned assignments exist
- [ ] Findings CSV generated when findings exist

#### Excel Report (if ImportExcel available)
- [ ] Multiple worksheets created
- [ ] Headers are bold and frozen
- [ ] Columns are auto-sized
- [ ] Data is properly formatted

### 3. Findings Detection

#### Critical Findings
- [ ] Detects service principals with Owner role
- [ ] Detects expired service principal secrets
- [ ] All critical findings flagged with correct severity

#### High Findings
- [ ] Detects service principal secrets expiring < 30 days
- [ ] Detects orphaned assignments (deleted principals)
- [ ] All high findings flagged with correct severity

#### Recommended Actions
- [ ] Each finding has a recommended action
- [ ] Recommended actions are specific and actionable

### 4. Sign-Off Template

- [ ] Template file created in templates/ directory
- [ ] Template contains ReviewId
- [ ] Template contains ReviewDate
- [ ] Template contains ReviewType
- [ ] Template has sections for all required approvals
- [ ] Template has sections for findings summary
- [ ] Template has sections for remediation actions

### 5. Documentation Validation

#### Process Documentation
- [ ] Access review schedule is clear
- [ ] Review phases are well-defined
- [ ] Remediation procedures are detailed
- [ ] Sign-off process is documented
- [ ] Compliance mappings are accurate

#### Script Documentation
- [ ] README has clear usage examples
- [ ] All parameters are documented
- [ ] Examples cover common scenarios
- [ ] Troubleshooting section is comprehensive

#### Quick Reference
- [ ] Common commands are listed
- [ ] Review schedule is included
- [ ] Remediation commands are provided
- [ ] Contact information is present

### 6. Integration Testing

#### With Existing RBAC Scripts
- [ ] Access review script can use RBAC audit data
- [ ] Scripts can run in sequence
- [ ] No conflicts in directory structure
- [ ] Output formats are consistent

#### With Main Documentation
- [ ] README.md links to access review docs
- [ ] Repository structure is updated
- [ ] Access reviews listed in security section

### 7. Compliance Validation

#### SOC 2 Type II
- [ ] Quarterly review schedule documented
- [ ] Access removal procedures defined
- [ ] Audit trail maintained
- [ ] Sign-off process in place

#### ISO 27001
- [ ] Access review procedures documented
- [ ] Review frequency defined
- [ ] Evidence collection process defined

#### PCI DSS
- [ ] Quarterly access reviews scheduled
- [ ] High-privilege accounts reviewed
- [ ] Documentation and sign-off required

#### GDPR
- [ ] Access controls validated
- [ ] Data processing records maintained
- [ ] Security measures documented

## Test Scenarios

### Scenario 1: First-Time Quarterly Review

**Setup:**
1. Fresh environment with existing RBAC assignments
2. Mix of users, groups, and service principals
3. Some high-privilege accounts

**Expected Results:**
- Script runs successfully
- All assignments discovered
- Reports generated in all formats
- High-privilege accounts identified
- Sign-off template created

**Validation:**
```powershell
# Run quarterly review
.\Conduct-AccessReview.ps1 -ReviewType Quarterly

# Check outputs
Get-ChildItem reports/ | Should -Not -BeNullOrEmpty
Get-ChildItem templates/ | Should -Not -BeNullOrEmpty
Get-ChildItem logs/ | Should -Not -BeNullOrEmpty
```

### Scenario 2: High-Privilege Monthly Review

**Setup:**
1. Production environment
2. Multiple Owner and Contributor role assignments
3. Service principals with high privileges

**Expected Results:**
- Only high-privilege accounts included in report
- Critical findings for service principals with Owner role
- Recommendations provided for each finding

**Validation:**
```powershell
# Run high-privilege review
.\Conduct-AccessReview.ps1 -Environment prod -ReviewType HighPrivilege

# Verify only high-privilege roles in output
# Check for critical findings
```

### Scenario 3: Service Principal Secret Expiration

**Setup:**
1. Service principal with secret expiring in 20 days
2. Service principal with expired secret
3. Service principal with valid secret (>30 days)

**Expected Results:**
- Finding for secret expiring in 20 days (High severity)
- Finding for expired secret (Critical severity)
- No finding for valid secret

**Validation:**
```powershell
# Run service principal review
.\Conduct-AccessReview.ps1 -ReviewType ServicePrincipal

# Check findings CSV for secret expiration warnings
```

### Scenario 4: Orphaned Assignments

**Setup:**
1. Role assignments for deleted user
2. Role assignments for deleted service principal
3. Valid role assignments

**Expected Results:**
- Orphaned assignments detected and reported
- Findings generated for each orphaned assignment
- Recommendation to remove orphaned assignments

**Validation:**
```powershell
# Run review
.\Conduct-AccessReview.ps1 -Environment dev -ReviewType Quarterly

# Check orphaned assignments CSV
# Verify orphaned assignments are flagged
```

### Scenario 5: Multi-Environment Review

**Setup:**
1. Dev, staging, and production environments
2. Different access patterns in each

**Expected Results:**
- Data collected from all three environments
- Separate environment sections in JSON report
- Combined CSV files with environment column
- Summary statistics for each environment

**Validation:**
```powershell
# Run review for all environments
.\Conduct-AccessReview.ps1 -ReviewType Quarterly

# Verify JSON has data for all environments
# Check CSV files have environment column populated
```

## Manual Verification Steps

### Step 1: Review Generated Reports

1. Open JSON report and verify structure:
   ```json
   {
     "ReviewId": "AR-2026-Q1-...",
     "ReviewDate": "2026-02-14",
     "ReviewType": "Quarterly",
     "Environments": [...],
     "Summary": {...}
   }
   ```

2. Open CSV files and verify:
   - Headers are correct
   - Data is properly formatted
   - No missing required columns

3. Open Excel file (if available) and verify:
   - All worksheets present
   - Data is readable
   - Formatting is applied

### Step 2: Review Sign-Off Template

1. Open sign-off template in templates/ directory
2. Verify all sections are present:
   - Review information
   - Summary statistics
   - Findings breakdown
   - Remediation actions
   - Compliance status
   - Approval signatures

### Step 3: Review Log File

1. Open log file in logs/ directory
2. Verify:
   - No ERROR entries (unless expected)
   - All phases completed
   - Timing information present
   - Summary statistics logged

### Step 4: Validate Against Azure

1. Compare report data with actual Azure assignments:
   ```powershell
   # Get actual assignments
   $rg = Get-AzResourceGroup -Name "kbudget-dev-rg"
   $actual = Get-AzRoleAssignment -Scope $rg.ResourceId
   
   # Compare with report
   # Verify counts match
   # Verify principal names match
   ```

### Step 5: Test Remediation Commands

1. Test access removal (in dev):
   ```powershell
   # Find a test assignment to remove
   # Run removal command from documentation
   # Verify removal successful
   # Re-run review to confirm removed
   ```

2. Test permission reduction (in dev):
   ```powershell
   # Find high-privilege assignment
   # Remove high-privilege role
   # Add lower-privilege role
   # Verify change successful
   ```

## Performance Testing

### Metrics to Collect

- Script execution time for single environment
- Script execution time for all environments
- Time to generate JSON report
- Time to generate CSV reports
- Time to generate Excel report
- Memory usage during execution

### Expected Performance

- Single environment: < 2 minutes
- All environments: < 5 minutes
- Report generation: < 30 seconds
- Memory usage: < 200 MB

## Security Testing

### Sensitive Data Handling

- [ ] No secrets in reports
- [ ] No passwords in logs
- [ ] Object IDs used instead of sensitive data where appropriate
- [ ] Reports marked as confidential

### Access Control

- [ ] Script requires appropriate Azure permissions
- [ ] Read-only access sufficient for review
- [ ] No modifications made to Azure resources during review

## Regression Testing

After any changes to the script or documentation:

1. Run full test suite
2. Verify all test scenarios pass
3. Check for any new warnings or errors
4. Validate output format hasn't changed unexpectedly
5. Ensure backward compatibility with existing reports

## Test Results Template

```
Access Review Testing - Test Run Report

Date: _______________
Tester: _______________
Version: _______________

Test Summary:
- Total Tests: _____
- Passed: _____
- Failed: _____
- Skipped: _____

Script Functionality:
- Prerequisites Validation: ☐ Pass ☐ Fail
- Environment Selection: ☐ Pass ☐ Fail
- Review Types: ☐ Pass ☐ Fail
- Output Formats: ☐ Pass ☐ Fail
- Error Handling: ☐ Pass ☐ Fail

Report Validation:
- JSON Report: ☐ Pass ☐ Fail
- CSV Reports: ☐ Pass ☐ Fail
- Excel Report: ☐ Pass ☐ Fail

Findings Detection:
- Critical Findings: ☐ Pass ☐ Fail
- High Findings: ☐ Pass ☐ Fail
- Recommendations: ☐ Pass ☐ Fail

Documentation:
- Process Documentation: ☐ Pass ☐ Fail
- Script Documentation: ☐ Pass ☐ Fail
- Quick Reference: ☐ Pass ☐ Fail

Integration:
- RBAC Integration: ☐ Pass ☐ Fail
- Documentation Integration: ☐ Pass ☐ Fail

Compliance:
- SOC 2: ☐ Pass ☐ Fail
- ISO 27001: ☐ Pass ☐ Fail
- PCI DSS: ☐ Pass ☐ Fail
- GDPR: ☐ Pass ☐ Fail

Issues Found:
1. ___________________________________________________________________
2. ___________________________________________________________________
3. ___________________________________________________________________

Recommendations:
1. ___________________________________________________________________
2. ___________________________________________________________________

Overall Result: ☐ PASS ☐ FAIL

Tester Signature: _______________    Date: _______________
```

## Next Steps After Testing

1. Document any issues found
2. Fix critical and high-priority issues
3. Update documentation based on feedback
4. Conduct user acceptance testing
5. Schedule first production run
6. Train security team on process

---

**Document Version:** 1.0.0  
**Last Updated:** 2026-02-14  
**Owner:** DevOps Team
