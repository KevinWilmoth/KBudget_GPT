# Diagnostic Settings ARM Template

This template configures diagnostic settings to send logs and metrics from Azure resources to Log Analytics Workspace.

## Overview

Diagnostic settings enable the collection of:
- **Resource Logs**: Platform logs from Azure services
- **Metrics**: Performance and usage metrics
- **Activity Logs**: Subscription-level events

This template configures diagnostic settings for:
- App Service (web apps)
- SQL Database
- Storage Account (including blob service)
- Function App
- Key Vault

## Features

✅ **Centralized Logging**: All logs sent to Log Analytics  
✅ **Compliance**: Extended retention for audit logs  
✅ **Security**: Key Vault audit events tracked  
✅ **Performance**: Metrics for troubleshooting and optimization

## Configured Log Categories

### App Service
- **AppServiceHTTPLogs**: HTTP request logs (90 days)
- **AppServiceConsoleLogs**: Console output (90 days)
- **AppServiceAppLogs**: Application logs (90 days)
- **AppServiceAuditLogs**: Audit events (180 days)
- **AppServiceIPSecAuditLogs**: IP security audit (180 days)
- **AppServicePlatformLogs**: Platform logs (90 days)

### SQL Database
- **SQLInsights**: Query insights (90 days)
- **AutomaticTuning**: Tuning recommendations (90 days)
- **QueryStoreRuntimeStatistics**: Query performance (90 days)
- **QueryStoreWaitStatistics**: Wait statistics (90 days)
- **Errors**: Database errors (90 days)
- **DatabaseWaitStatistics**: Wait events (90 days)
- **Timeouts**: Query timeouts (90 days)
- **Blocks**: Blocking events (90 days)
- **Deadlocks**: Deadlock information (90 days)

### Storage Account
- **StorageRead**: Read operations (90 days)
- **StorageWrite**: Write operations (90 days)
- **StorageDelete**: Delete operations (180 days)
- **Transaction**: All transaction metrics (90 days)

### Function App
- **FunctionAppLogs**: Function execution logs (90 days)
- **AllMetrics**: Performance metrics (90 days)

### Key Vault
- **AuditEvent**: Access and management events (365 days)
- **AzurePolicyEvaluationDetails**: Policy compliance (180 days)

## Retention Policies

| Category | Retention | Purpose |
|----------|-----------|---------|
| Audit Logs | 180-365 days | Compliance and security |
| Application Logs | 90 days | Troubleshooting and analysis |
| Performance Metrics | 90 days | Performance optimization |
| Security Logs | 180 days | Security investigation |

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `workspaceId` | string | Resource ID of Log Analytics Workspace |
| `appServiceId` | string | Resource ID of App Service |
| `appServiceName` | string | Name of App Service |
| `sqlServerId` | string | Resource ID of SQL Server |
| `sqlServerName` | string | Name of SQL Server |
| `sqlDatabaseName` | string | Name of SQL Database |
| `storageAccountId` | string | Resource ID of Storage Account |
| `storageAccountName` | string | Name of Storage Account |
| `functionAppId` | string | Resource ID of Function App |
| `functionAppName` | string | Name of Function App |
| `keyVaultId` | string | Resource ID of Key Vault |
| `keyVaultName` | string | Name of Key Vault |

## Deployment

**Prerequisites**: 
1. Log Analytics Workspace must be deployed first
2. All application resources must exist
3. Update parameter files with correct resource IDs

### Using Azure CLI

```bash
# Deploy to development
az deployment group create \
  --resource-group kbudget-dev-rg \
  --template-file diagnostic-settings.json \
  --parameters parameters.dev.json

# Deploy to staging
az deployment group create \
  --resource-group kbudget-staging-rg \
  --template-file diagnostic-settings.json \
  --parameters parameters.staging.json

# Deploy to production
az deployment group create \
  --resource-group kbudget-prod-rg \
  --template-file diagnostic-settings.json \
  --parameters parameters.prod.json
```

### Using PowerShell

```powershell
# Deploy to development
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-dev-rg `
  -TemplateFile diagnostic-settings.json `
  -TemplateParameterFile parameters.dev.json

# Deploy to staging
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-staging-rg `
  -TemplateFile diagnostic-settings.json `
  -TemplateParameterFile parameters.staging.json

# Deploy to production
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-prod-rg `
  -TemplateFile diagnostic-settings.json `
  -TemplateParameterFile parameters.prod.json
```

## Querying Logs

Once diagnostic settings are configured, query logs in Log Analytics:

### Query App Service HTTP Logs
```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where ScStatus >= 500
| summarize count() by ScStatus, bin(TimeGenerated, 5m)
```

### Query SQL Database Errors
```kusto
AzureDiagnostics
| where ResourceType == "SERVERS/DATABASES"
| where Category == "Errors"
| where TimeGenerated > ago(24h)
| project TimeGenerated, error_message_s, severity_s
```

### Query Storage Operations
```kusto
StorageBlobLogs
| where TimeGenerated > ago(1h)
| where OperationName == "DeleteBlob"
| project TimeGenerated, Uri, CallerIpAddress
```

### Query Key Vault Access
```kusto
AzureDiagnostics
| where ResourceType == "VAULTS"
| where Category == "AuditEvent"
| where TimeGenerated > ago(7d)
| project TimeGenerated, OperationName, CallerIPAddress, identity_claim_appid_g
```

## Compliance and Auditing

This template helps meet compliance requirements:

- **SOC 2**: Comprehensive logging with appropriate retention
- **ISO 27001**: Security event logging and monitoring
- **GDPR**: Data access and modification tracking
- **HIPAA**: Audit trail for sensitive data access
- **PCI DSS**: Security event monitoring and retention

## Cost Considerations

Diagnostic settings incur costs for:
1. **Log Ingestion**: Based on data volume sent to Log Analytics
2. **Log Retention**: Storage costs for retained data
3. **Log Queries**: Cost per GB scanned

To optimize costs:
- Review which log categories are necessary
- Adjust retention periods appropriately
- Archive old logs to cheaper storage if needed
- Monitor ingestion rates and set quotas

## Outputs

- **diagnosticSettingsConfigured**: Boolean indicating successful configuration

## Troubleshooting

### Logs Not Appearing

1. Verify the workspace ID is correct
2. Check that resources are generating activity
3. Allow 5-15 minutes for initial log ingestion
4. Verify RBAC permissions on Log Analytics Workspace

### High Ingestion Costs

1. Review which log categories are enabled
2. Consider sampling for high-volume logs
3. Adjust retention periods for less critical logs
4. Implement log filtering at the source

## Compliance and Audit Log Retention

### Organizational Policy

The audit log retention policy is defined in [audit-retention-policy.json](./audit-retention-policy.json) and ensures compliance with:
- SOC 2 Type II
- ISO 27001
- GDPR
- HIPAA
- PCI DSS

### Compliance Validation

Use the [Set-AuditLogRetention.ps1](./Set-AuditLogRetention.ps1) script to:
- Validate all resources have diagnostic settings configured
- Ensure log retention meets organizational policy requirements
- Generate compliance reports for security team review

**Quick Start:**
```powershell
# Validate compliance (read-only)
.\Set-AuditLogRetention.ps1 -Environment dev -ValidateOnly

# Apply retention policies
.\Set-AuditLogRetention.ps1 -Environment dev

# Generate compliance report
.\Set-AuditLogRetention.ps1 -Environment prod -ValidateOnly -GenerateReport
```

For detailed procedures, see:
- [Compliance Validation Guide](./COMPLIANCE-VALIDATION-GUIDE.md) - Step-by-step validation procedures
- [Compliance Documentation](../../docs/COMPLIANCE-DOCUMENTATION.md) - Complete log categories and retention policies

## Related Resources

- [Log Analytics](../log-analytics/README.md) - Centralized workspace for logs
- [Monitoring Alerts](../monitoring-alerts/README.md) - Alerts based on log data
- [Compliance Documentation](../../docs/COMPLIANCE-DOCUMENTATION.md) - Comprehensive compliance guide
- [Compliance Validation Guide](./COMPLIANCE-VALIDATION-GUIDE.md) - Validation procedures

## References

- [Azure Diagnostic Settings Documentation](https://docs.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
- [Resource Log Categories](https://docs.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories)
- [Log Analytics Pricing](https://azure.microsoft.com/pricing/details/monitor/)
