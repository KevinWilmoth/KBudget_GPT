# Audit Log Retention & Security Compliance Documentation

## Overview

This document provides comprehensive documentation of all audit log categories, retention timelines, and security policies for the KBudget GPT Azure infrastructure. This ensures compliance with SOC 2, ISO 27001, GDPR, HIPAA, and PCI DSS regulatory requirements.

## Table of Contents

1. [Compliance Frameworks](#compliance-frameworks)
2. [Retention Policy Summary](#retention-policy-summary)
3. [Resource-Specific Log Categories](#resource-specific-log-categories)
4. [Security Policies](#security-policies)
5. [Compliance Mapping](#compliance-mapping)
6. [Audit Trail](#audit-trail)
7. [Review and Approval](#review-and-approval)

## Compliance Frameworks

The KBudget GPT audit logging strategy addresses the following compliance frameworks:

### SOC 2 Type II
- **Requirement:** Comprehensive audit logging with 1+ year retention
- **Implementation:** Critical audit logs retained for 365 days
- **Validation:** Quarterly reviews and annual audit

### ISO 27001
- **Requirement:** Security event logging and monitoring
- **Implementation:** Security audit logs retained for 180+ days
- **Validation:** Information Security Management System (ISMS) review

### GDPR (General Data Protection Regulation)
- **Requirement:** Data access and modification tracking
- **Implementation:** All data operations logged with 90+ day retention
- **Validation:** Data Protection Impact Assessment (DPIA)

### HIPAA (Health Insurance Portability and Accountability Act)
- **Requirement:** 2-year audit trail for PHI access
- **Implementation:** Critical audit events retained for 730 days (configurable)
- **Validation:** Annual HIPAA compliance audit

### PCI DSS (Payment Card Industry Data Security Standard)
- **Requirement:** 1-year retention for security events
- **Implementation:** Security audit logs retained for 365+ days
- **Validation:** Quarterly security scans and annual assessment

## Retention Policy Summary

### Standard Retention Tiers

| Tier | Retention Period | Use Case | Examples |
|------|------------------|----------|----------|
| **Standard Logs** | 90 days | Operational and diagnostic logs | HTTP logs, console logs, application logs |
| **Audit Logs** | 180 days | Security and compliance audit logs | IP security logs, platform audit logs |
| **Critical Audit Logs** | 365 days | High-security audit events | Key Vault access, critical operations |
| **Compliance Logs** | 730 days | Maximum regulatory retention | HIPAA-related audit trails (optional) |

### Retention Configuration

```json
{
  "standardLogs": {
    "retentionDays": 90,
    "description": "Default retention for operational and diagnostic logs"
  },
  "auditLogs": {
    "retentionDays": 180,
    "description": "Default retention for security and audit logs"
  },
  "criticalAuditLogs": {
    "retentionDays": 365,
    "description": "Extended retention for critical security audit events"
  }
}
```

## Resource-Specific Log Categories

### App Service (Web Applications)

#### Log Categories

| Category | Enabled | Retention | Classification | Purpose |
|----------|---------|-----------|----------------|---------|
| **AppServiceHTTPLogs** | ✅ Yes | 90 days | Operational | HTTP request logging and troubleshooting |
| **AppServiceConsoleLogs** | ✅ Yes | 90 days | Operational | Application console output for debugging |
| **AppServiceAppLogs** | ✅ Yes | 90 days | Operational | Application-level logging and diagnostics |
| **AppServiceAuditLogs** | ✅ Yes | 180 days | Security Audit | Security audit events and access tracking |
| **AppServiceIPSecAuditLogs** | ✅ Yes | 180 days | Security Audit | IP security and firewall audit events |
| **AppServicePlatformLogs** | ✅ Yes | 90 days | Operational | Azure platform-level logs for the service |

#### Metrics

| Category | Enabled | Retention | Purpose |
|----------|---------|-----------|---------|
| **AllMetrics** | ✅ Yes | 90 days | Performance monitoring and capacity planning |

#### Sample Queries

**Query HTTP Errors:**
```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(24h)
| where ScStatus >= 400
| summarize count() by ScStatus, bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

**Query Audit Events:**
```kusto
AppServiceAuditLogs
| where TimeGenerated > ago(7d)
| where OperationName contains "Authentication"
| project TimeGenerated, OperationName, Identity, CorrelationId
```

### Cosmos DB Database

#### Log Categories

| Category | Enabled | Retention | Classification | Purpose |
|----------|---------|-----------|----------------|---------|
| **DataPlaneRequests** | ✅ Yes | 90 days | Operational | All data plane requests and latency tracking |
| **MongoRequests** | ✅ Yes | 90 days | Operational | MongoDB API requests (if used) |
| **QueryRuntimeStatistics** | ✅ Yes | 90 days | Performance | Query execution statistics and performance |
| **PartitionKeyStatistics** | ✅ Yes | 90 days | Performance | Partition distribution and hot partition detection |
| **ControlPlaneRequests** | ✅ Yes | 180 days | Security Audit | Account-level operations audit trail |

#### Metrics

| Category | Enabled | Retention | Purpose |
|----------|---------|-----------|---------|
| **Requests** | ✅ Yes | 90 days | Request metrics including RU consumption |
| **PartitionKeyRUConsumption** | ✅ Yes | 90 days | RU consumption per partition key |
| **QueryRUConsumption** | ✅ Yes | 90 days | RU consumption per query |

#### Sample Queries

**Query Request Metrics:**
```kusto
AzureDiagnostics
| where ResourceType == "DATABASEACCOUNTS"
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(24h)
| project TimeGenerated, activityId_g, statusCode_s, requestCharge_s
| order by TimeGenerated desc
```

**Query Throttling Events:**
```kusto
AzureDiagnostics
| where ResourceType == "DATABASEACCOUNTS"
| where Category == "DataPlaneRequests"
| where statusCode_s == "429"
| where TimeGenerated > ago(7d)
| project TimeGenerated, activityId_g, requestCharge_s
```

### Storage Account

#### Log Categories

| Category | Enabled | Retention | Classification | Purpose |
|----------|---------|-----------|----------------|---------|
| **StorageRead** | ✅ Yes | 90 days | Operational | Storage read operation tracking |
| **StorageWrite** | ✅ Yes | 90 days | Operational | Storage write operation tracking |
| **StorageDelete** | ✅ Yes | 180 days | Security Audit | Data deletion audit trail for compliance |

#### Metrics

| Category | Enabled | Retention | Purpose |
|----------|---------|-----------|---------|
| **Transaction** | ✅ Yes | 90 days | Storage transaction metrics and billing |

#### Sample Queries

**Query Delete Operations:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d)
| where OperationName == "DeleteBlob"
| project TimeGenerated, Uri, CallerIpAddress, UserAgentHeader
| order by TimeGenerated desc
```

**Query Write Operations by IP:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where OperationName == "PutBlob"
| summarize count() by CallerIpAddress
| order by count_ desc
```

### Azure Functions (Serverless)

#### Log Categories

| Category | Enabled | Retention | Classification | Purpose |
|----------|---------|-----------|----------------|---------|
| **FunctionAppLogs** | ✅ Yes | 90 days | Operational | Serverless function execution logs |

#### Metrics

| Category | Enabled | Retention | Purpose |
|----------|---------|-----------|---------|
| **AllMetrics** | ✅ Yes | 90 days | Function app performance and execution metrics |

#### Sample Queries

**Query Function Failures:**
```kusto
FunctionAppLogs
| where TimeGenerated > ago(24h)
| where Level == "Error"
| project TimeGenerated, FunctionName, Message, ExceptionMessage
| order by TimeGenerated desc
```

**Query Function Execution Duration:**
```kusto
FunctionAppLogs
| where TimeGenerated > ago(1h)
| where Message contains "Executed"
| summarize avg(DurationMs) by FunctionName, bin(TimeGenerated, 5m)
```

### Key Vault (Secrets Management)

#### Log Categories

| Category | Enabled | Retention | Classification | Purpose |
|----------|---------|-----------|----------------|---------|
| **AuditEvent** | ✅ Yes | 365 days | **Critical Security Audit** | Critical security audit for secret/key access |
| **AzurePolicyEvaluationDetails** | ✅ Yes | 180 days | Compliance Audit | Azure Policy compliance evaluation tracking |

#### Metrics

| Category | Enabled | Retention | Purpose |
|----------|---------|-----------|---------|
| **AllMetrics** | ✅ Yes | 90 days | Key Vault service health and performance |

#### Sample Queries

**Query Secret Access:**
```kusto
AzureDiagnostics
| where ResourceType == "VAULTS"
| where Category == "AuditEvent"
| where OperationName == "SecretGet"
| where TimeGenerated > ago(7d)
| project TimeGenerated, CallerIPAddress, identity_claim_appid_g, ResultSignature
| order by TimeGenerated desc
```

**Query Failed Authentication:**
```kusto
AzureDiagnostics
| where ResourceType == "VAULTS"
| where Category == "AuditEvent"
| where ResultSignature == "Unauthorized"
| where TimeGenerated > ago(7d)
| project TimeGenerated, OperationName, CallerIPAddress, identity_claim_upn_s
```

### Log Analytics Workspace

#### Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| **Retention In Days** | 90 | Default workspace retention for all ingested logs |
| **Daily Quota** | Unlimited (-1) | No daily ingestion limit (monitor costs) |
| **SKU** | PerGB2018 | Pay-as-you-go pricing model |
| **Network Access (Ingestion)** | Enabled | Allow resources to send logs |
| **Network Access (Query)** | Enabled | Allow users to query logs |

## Security Policies

### 1. Encryption

**Policy:** All audit logs must be encrypted at rest and in transit

**Implementation:**
- Azure Monitor uses encryption at rest by default
- All log transmission uses HTTPS/TLS 1.2+
- Log Analytics workspace data encrypted with Microsoft-managed keys
- Option to use customer-managed keys (CMK) available

**Validation:**
```powershell
# Verify workspace encryption
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "kbudget-prod-rg"
$workspace.Features
```

### 2. Access Control

**Policy:** Access to audit logs requires explicit approval and proper RBAC

**Minimum Required Roles:**
- **Read Access:** Log Analytics Reader
- **Query Access:** Log Analytics Reader
- **Modify Settings:** Log Analytics Contributor
- **Full Management:** Owner or Contributor (on resource group)

**Implementation:**
```powershell
# Grant read access to security team
New-AzRoleAssignment `
    -SignInName "security-team@organization.com" `
    -RoleDefinitionName "Log Analytics Reader" `
    -ResourceGroupName "kbudget-prod-rg"
```

**Audit Access:**
```kusto
// Query who accessed logs
LAQueryLogs
| where TimeGenerated > ago(30d)
| summarize count() by AADEmail, AADTenantId
| order by count_ desc
```

### 3. Monitoring and Alerting

**Policy:** Alert security team on retention policy changes and unauthorized access

**Alerts Configured:**
1. **Diagnostic Setting Modified**
   - Trigger: Any change to diagnostic settings
   - Action: Email security team
   - Severity: High

2. **Failed Key Vault Access**
   - Trigger: 5+ failed access attempts in 5 minutes
   - Action: Email security team, create incident
   - Severity: Critical

3. **Unusual Log Volume**
   - Trigger: Log ingestion exceeds baseline by 200%
   - Action: Email operations team
   - Severity: Medium

**Implementation:**
```kusto
// Alert query for diagnostic setting changes
AzureActivity
| where OperationNameValue contains "Microsoft.Insights/diagnosticSettings"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, ResourceId, OperationNameValue
```

### 4. Backup and Archival

**Policy:** Archive logs older than 90 days to cold storage for extended retention

**Implementation Strategy:**
1. **Active Logs (0-90 days):** Log Analytics Workspace
2. **Warm Archive (91-365 days):** Azure Storage (Cool tier)
3. **Cold Archive (366+ days):** Azure Storage (Archive tier)

**Archival Process:**
```powershell
# Export logs to storage account (automated via Azure Function)
# Logs older than 90 days are automatically moved to blob storage
# Retention policies on blob storage manage lifecycle
```

**Cost Optimization:**
- Log Analytics: $2.30/GB ingested + $0.10/GB retention
- Cool Storage: $0.01/GB/month + $0.01/GB retrieval
- Archive Storage: $0.002/GB/month + $0.02/GB retrieval

### 5. Retention Policy Governance

**Policy:** Retention policies must be reviewed quarterly and approved annually

**Governance Process:**
1. **Quarterly Review (DevOps Team)**
   - Run compliance validation
   - Identify and remediate non-compliant resources
   - Generate compliance reports

2. **Annual Review (Security Team)**
   - Review organizational policy
   - Update retention requirements based on regulatory changes
   - Validate compliance with all frameworks
   - Update policy version

3. **Sign-Off (CISO)**
   - Review annual compliance report
   - Approve policy changes
   - Sign-off on compliance status

**Review Schedule:**
| Review Type | Frequency | Owner | Next Review |
|-------------|-----------|-------|-------------|
| Operational Validation | Monthly | DevOps Team | 1st Monday of each month |
| Compliance Review | Quarterly | Security Team | Q1, Q2, Q3, Q4 |
| Policy Update | Annually | CISO | Q1 2027 |

## Compliance Mapping

### SOC 2 Type II Requirements

| Control | Requirement | Implementation | Evidence |
|---------|-------------|----------------|----------|
| **CC6.1** | Logical access controls | RBAC on Log Analytics | Role assignments audit |
| **CC6.2** | Access modification | Audit logs for access changes | AzureActivity logs |
| **CC6.3** | Access removal | Automated deprovisioning | Azure AD logs |
| **CC7.2** | Security monitoring | Real-time alerting | Alert configurations |
| **CC7.3** | Security incidents | Incident response logs | Key Vault audit logs |
| **CC7.4** | Security event logging | Comprehensive logging | All diagnostic settings |

**Evidence Collection:**
```powershell
# Generate SOC 2 compliance report
.\Set-AuditLogRetention.ps1 -Environment prod -ValidateOnly -GenerateReport
```

### ISO 27001 Requirements

| Control | Requirement | Implementation | Evidence |
|---------|-------------|----------------|----------|
| **A.12.4.1** | Event logging | All critical events logged | Diagnostic settings |
| **A.12.4.2** | Logging protection | Encrypted, access-controlled | RBAC + encryption |
| **A.12.4.3** | Administrator logs | Admin activity tracked | AzureActivity logs |
| **A.12.4.4** | Clock synchronization | Azure-managed NTP | Azure platform |

### GDPR Requirements

| Requirement | Implementation | Evidence |
|-------------|----------------|----------|
| **Art. 30** | Records of processing | Data access logs | Storage logs |
| **Art. 32** | Security measures | Encryption, access control | Security policies |
| **Art. 33** | Breach notification | Alerting and monitoring | Alert rules |
| **Art. 35** | Impact assessment | DPIA conducted | DPIA document |

### HIPAA Requirements

| Requirement | Implementation | Evidence |
|-------------|----------------|----------|
| **§164.308(a)(1)(ii)(D)** | Information system activity review | Log analysis | Audit queries |
| **§164.312(b)** | Audit controls | Comprehensive logging | Diagnostic settings |
| **§164.312(a)(2)(i)** | Unique user identification | Azure AD integration | Identity logs |
| **§164.308(a)(5)(ii)(C)** | Log-in monitoring | Authentication logs | Sign-in logs |

### PCI DSS Requirements

| Requirement | Implementation | Evidence |
|-------------|----------------|----------|
| **10.2** | Audit trail for system components | All resources logged | Diagnostic settings |
| **10.3** | Audit trail entries | Timestamp, user, event type | Log format |
| **10.5** | Secure audit trails | Access control, integrity | RBAC, encryption |
| **10.6** | Review logs daily | Automated monitoring | Alert rules |
| **10.7** | Retain audit trail 1 year | 365-day retention | Retention policies |

## Audit Trail

### Change History

| Version | Date | Changes | Author | Approver |
|---------|------|---------|--------|----------|
| 1.0.0 | 2026-02-13 | Initial policy creation | DevOps Team | CISO |

### Compliance Reviews

| Review Date | Reviewer | Compliance Rate | Status | Next Review |
|-------------|----------|-----------------|--------|-------------|
| 2026-02-13 | Security Team | N/A | Initial Setup | 2026-05-13 |

### Policy Violations

| Date | Resource | Violation | Remediation | Resolved |
|------|----------|-----------|-------------|----------|
| N/A | N/A | N/A | N/A | N/A |

## Review and Approval

### Review Process

1. **DevOps Team** - Implements and maintains audit logging
2. **Security Team** - Reviews compliance quarterly
3. **CISO** - Approves policy annually

### Sign-Off Template

```
AUDIT LOG RETENTION POLICY - APPROVAL FORM

Policy Version: 1.0.0
Review Date: 2026-02-13
Environment: All (Dev, Staging, Production)

Compliance Summary:
☑ SOC 2 Type II - Compliant
☑ ISO 27001 - Compliant
☑ GDPR - Compliant
☑ HIPAA - Compliant
☑ PCI DSS - Compliant

Resources Reviewed:
☑ App Service - Compliant
☑ Cosmos DB Database - Compliant
☑ Storage Account - Compliant
☑ Azure Functions - Compliant
☑ Key Vault - Compliant
☑ Log Analytics Workspace - Compliant

Outstanding Issues: None

Recommendation: APPROVED for production deployment

________________________                    __________
DevOps Team Lead                            Date

________________________                    __________
Security Team Lead                          Date

________________________                    __________
CISO                                        Date
```

### Next Review Schedule

- **Quarterly Review:** 2026-05-13 (Security Team)
- **Annual Policy Review:** 2027-02-13 (CISO)
- **Emergency Review:** As needed for security incidents or regulatory changes

## Appendix

### A. Regulatory Reference Links

- **SOC 2:** [AICPA SOC 2 Documentation](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/socforserviceorganizations.html)
- **ISO 27001:** [ISO 27001 Standard](https://www.iso.org/isoiec-27001-information-security.html)
- **GDPR:** [EU GDPR Portal](https://gdpr.eu/)
- **HIPAA:** [HHS HIPAA](https://www.hhs.gov/hipaa/)
- **PCI DSS:** [PCI Security Standards](https://www.pcisecuritystandards.org/)

### B. Azure Documentation

- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [Diagnostic Settings](https://docs.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
- [Log Analytics Workspace](https://docs.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview)
- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)

### C. Internal Documentation

- [Audit Retention Policy (JSON)](../infrastructure/arm-templates/diagnostic-settings/audit-retention-policy.json)
- [Compliance Validation Guide](../infrastructure/arm-templates/diagnostic-settings/COMPLIANCE-VALIDATION-GUIDE.md)
- [Set-AuditLogRetention Script](../infrastructure/arm-templates/diagnostic-settings/Set-AuditLogRetention.ps1)
- [Diagnostic Settings Template](../infrastructure/arm-templates/diagnostic-settings/diagnostic-settings.json)

---

**Document Control:**
- **Version:** 1.0.0
- **Last Updated:** 2026-02-13
- **Next Review:** 2026-05-13
- **Owner:** Security and Governance Team
- **Classification:** Internal - Compliance Documentation
