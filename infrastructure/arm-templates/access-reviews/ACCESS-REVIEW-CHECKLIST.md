# Access Review Checklist Template

## Review Information
- **Review ID:** _______________
- **Review Type:** ☐ Quarterly ☐ Monthly ☐ Annual ☐ High-Privilege ☐ Service Principal
- **Environment(s):** ☐ Development ☐ Staging ☐ Production ☐ All
- **Review Date:** _______________
- **Reviewer:** _______________
- **Completion Date:** _______________

---

## Phase 1: Preparation

### Data Collection
- [ ] Connect to Azure (`Connect-AzAccount`)
- [ ] Verify correct subscription selected
- [ ] Run access review script
  ```powershell
  .\Conduct-AccessReview.ps1 -ReviewType <type>
  ```
- [ ] Verify reports generated successfully
- [ ] Review log file for errors or warnings

### Report Distribution
- [ ] Send user access reports to team managers
- [ ] Send service principal report to DevOps team
- [ ] Send high-privilege report to security team
- [ ] Send production access report to CISO
- [ ] Set deadline for feedback (7 days)

---

## Phase 2: Review and Validation

### User Access Review
- [ ] Review all user role assignments
- [ ] Verify users are still active/employed
- [ ] Confirm roles match job responsibilities
- [ ] Check for dormant/inactive accounts
- [ ] Validate MFA enforcement for privileged users
- [ ] Document business justification for each access
- [ ] Identify users for access removal
- [ ] Identify users for permission reduction

**Users Reviewed:** _____ / _____  
**Issues Identified:** _____

### Service Principal Review
- [ ] Review all service principal assignments
- [ ] Verify service principals are actively used
- [ ] Check for Owner role assignments (should be 0)
- [ ] Review secret expiration dates
- [ ] Identify secrets expiring within 30 days
- [ ] Validate least privilege principle
- [ ] Confirm proper scope (resource vs resource group)
- [ ] Document purpose and owner for each SP

**Service Principals Reviewed:** _____ / _____  
**Issues Identified:** _____

### High-Privilege Account Review
- [ ] Review all Owner role assignments
- [ ] Review all Contributor role assignments (production)
- [ ] Review all User Access Administrator assignments
- [ ] Verify business justification for each
- [ ] Confirm manager approval exists
- [ ] Check MFA enforcement
- [ ] Review conditional access policies
- [ ] Identify accounts for downgrade

**High-Privilege Accounts Reviewed:** _____ / _____  
**Issues Identified:** _____

### Group Access Review
- [ ] Review all group role assignments
- [ ] Verify group membership is current
- [ ] Check group ownership
- [ ] Validate group purpose and description
- [ ] Identify orphaned or unused groups

**Groups Reviewed:** _____ / _____  
**Issues Identified:** _____

### Orphaned Assignments
- [ ] Review all orphaned assignment findings
- [ ] Confirm principals are deleted/inactive
- [ ] Document removal plan
- [ ] Prioritize removal (all should be removed)

**Orphaned Assignments Found:** _____  
**All identified for removal:** ☐ Yes ☐ No

---

## Phase 3: Findings Analysis

### Critical Findings (Immediate Action Required)
| # | Finding | Principal | Severity | Action | Owner | Due Date |
|---|---------|-----------|----------|--------|-------|----------|
| 1 | | | Critical | | | |
| 2 | | | Critical | | | |

### High Findings (Action Required Within 1 Week)
| # | Finding | Principal | Severity | Action | Owner | Due Date |
|---|---------|-----------|----------|--------|-------|----------|
| 1 | | | High | | | |
| 2 | | | High | | | |

### Medium/Low Findings
| # | Finding | Principal | Severity | Action | Owner | Due Date |
|---|---------|-----------|----------|--------|-------|----------|
| 1 | | | Medium/Low | | | |

---

## Phase 4: Remediation Plan

### Access Removal
- [ ] List all access to be removed
- [ ] Obtain manager/resource owner approval
- [ ] Notify affected users
- [ ] Schedule removal (test in dev first if applicable)
- [ ] Execute removal commands
- [ ] Verify removal successful

**Total Removals:** _____  
**Completed:** _____ / _____

### Permission Reduction
- [ ] List all permissions to be reduced
- [ ] Document new permission level
- [ ] Obtain approvals
- [ ] Test reduced permissions in dev
- [ ] Apply to production
- [ ] Verify applications still function

**Total Reductions:** _____  
**Completed:** _____ / _____

### Secret Rotation
- [ ] List service principals requiring rotation
- [ ] Schedule rotation with application owners
- [ ] Generate new secrets
- [ ] Update Key Vault
- [ ] Update application configurations
- [ ] Test applications
- [ ] Remove old secrets

**Total Rotations:** _____  
**Completed:** _____ / _____

### Documentation Updates
- [ ] Update RBAC configuration files
- [ ] Update service principal inventory
- [ ] Update access justification documentation
- [ ] Update contact information
- [ ] Record exceptions and approvals

**Documentation Updates:** _____  
**Completed:** _____ / _____

---

## Phase 5: Verification

### Post-Remediation Validation
- [ ] Re-run access review script
- [ ] Verify all critical findings resolved
- [ ] Verify all high findings resolved
- [ ] Confirm orphaned assignments removed
- [ ] Test affected applications
- [ ] Review new reports for accuracy

**Critical Findings Remaining:** _____ (Target: 0)  
**High Findings Remaining:** _____ (Target: 0)

### Testing
- [ ] Applications function correctly
- [ ] No permission errors in logs
- [ ] Users can access required resources
- [ ] Service principals authenticated successfully
- [ ] No unexpected access denials

**Testing Status:** ☐ Passed ☐ Failed (describe):
_____________________________________________________________________________

---

## Phase 6: Documentation and Sign-Off

### Documentation Complete
- [ ] Executive summary written
- [ ] Detailed findings documented
- [ ] Remediation actions recorded
- [ ] Test results documented
- [ ] Exceptions documented with justification
- [ ] Next steps identified

### Compliance Validation
- [ ] SOC 2 Type II requirements met
- [ ] ISO 27001 requirements met
- [ ] PCI DSS requirements met
- [ ] GDPR requirements met
- [ ] Company policy requirements met

**Compliance Status:** ☐ Compliant ☐ Non-Compliant (explain):
_____________________________________________________________________________

### Reports Prepared
- [ ] Executive summary report
- [ ] Detailed access review report
- [ ] Findings and remediation report
- [ ] Metrics and trends report
- [ ] Sign-off form completed

### Approvals Obtained

**Security Team Lead:**
- Name: _________________________
- Date: _________________________
- Status: ☐ Approved ☐ Approved with Conditions ☐ Rejected
- Comments: ___________________________________________________________________

**CISO (Production Reviews):**
- Name: _________________________
- Date: _________________________
- Status: ☐ Approved ☐ Approved with Conditions ☐ Rejected
- Comments: ___________________________________________________________________

**Compliance Officer (Annual Reviews):**
- Name: _________________________
- Date: _________________________
- Status: ☐ Approved ☐ Approved with Conditions ☐ Rejected
- Comments: ___________________________________________________________________

---

## Summary Statistics

### Review Coverage
- Total Accounts Reviewed: _____
  - Users: _____
  - Groups: _____
  - Service Principals: _____
- High-Privilege Accounts: _____
- Orphaned Assignments: _____

### Findings
- Critical: _____
- High: _____
- Medium: _____
- Low: _____
- **Total: _____**

### Remediation Actions
- Access Removed: _____
- Permissions Reduced: _____
- Secrets Rotated: _____
- Documentation Updated: _____
- No Action Required: _____
- **Total Actions: _____**

### Remediation Completion
- Actions Planned: _____
- Actions Completed: _____
- **Completion Rate: _____% (Target: 100%)**

---

## Outstanding Items

| # | Item | Priority | Owner | Due Date | Status |
|---|------|----------|-------|----------|--------|
| 1 | | | | | |
| 2 | | | | | |

---

## Next Review

- **Next Review Date:** _______________
- **Review Type:** _______________
- **Special Focus Areas:** _______________________________________________
- **Follow-up Items:** ____________________________________________________

---

## Lessons Learned

**What went well:**
_____________________________________________________________________________
_____________________________________________________________________________

**What could be improved:**
_____________________________________________________________________________
_____________________________________________________________________________

**Process improvements for next review:**
_____________________________________________________________________________
_____________________________________________________________________________

---

## Archive Information

- [ ] Reports archived to secure location
- [ ] Sign-off forms filed (physical and electronic)
- [ ] Audit trail documented
- [ ] Retention policy applied (7 years)
- [ ] Next review scheduled on calendar

**Archive Location:** _________________________________________________________
**Archive Date:** _____________________________________________________________
**Archived By:** ______________________________________________________________

---

**Review Complete:** ☐ Yes ☐ No  
**Final Sign-Off Date:** _______________  
**Next Review Due:** _______________
