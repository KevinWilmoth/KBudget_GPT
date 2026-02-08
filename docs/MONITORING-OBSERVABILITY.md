# Monitoring and Observability Documentation

This document provides comprehensive guidance for implementing monitoring and observability in the KBudget GPT Azure infrastructure.

## Overview

The monitoring and observability solution consists of three main components:

1. **Log Analytics Workspace** - Centralized logging and analytics platform
2. **Azure Monitor Alerts** - Proactive alerting for critical resources
3. **Diagnostic Settings** - Log and metric collection configuration

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Resources                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │App Service│  │SQL Database│  │Storage  │  │Functions │  │
│  └────┬─────┘  └─────┬────┘  └────┬─────┘  └────┬─────┘  │
│       │              │             │             │         │
│       └──────────────┴─────────────┴─────────────┘         │
│                      │ Diagnostic Settings                 │
│                      ▼                                      │
│       ┌─────────────────────────────────┐                  │
│       │   Log Analytics Workspace       │                  │
│       │  - Logs & Metrics Storage       │                  │
│       │  - Query & Analysis             │                  │
│       │  - 30-365 day retention         │                  │
│       └────────────┬────────────────────┘                  │
│                    │                                        │
│                    ▼                                        │
│       ┌─────────────────────────────────┐                  │
│       │    Azure Monitor Alerts         │                  │
│       │  - Metric-based alerts          │                  │
│       │  - Action Groups                │                  │
│       └────────────┬────────────────────┘                  │
│                    │                                        │
│                    ▼                                        │
│       ┌─────────────────────────────────┐                  │
│       │    Email Notifications          │                  │
│       │  - DevOps Team Alerts           │                  │
│       └─────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Order

To ensure proper dependencies, deploy in this order:

1. **Log Analytics Workspace**
   ```bash
   cd infrastructure/arm-templates/log-analytics
   az deployment group create \
     --resource-group kbudget-{env}-rg \
     --template-file log-analytics.json \
     --parameters parameters.{env}.json
   ```

2. **Application Resources** (if not already deployed)
   - Resource Groups
   - Virtual Network
   - Key Vault
   - Storage Account
   - SQL Database
   - App Service
   - Azure Functions

3. **Diagnostic Settings**
   ```bash
   cd infrastructure/arm-templates/diagnostic-settings
   az deployment group create \
     --resource-group kbudget-{env}-rg \
     --template-file diagnostic-settings.json \
     --parameters parameters.{env}.json
   ```

4. **Monitoring Alerts**
   ```bash
   cd infrastructure/arm-templates/monitoring-alerts
   az deployment group create \
     --resource-group kbudget-{env}-rg \
     --template-file monitoring-alerts.json \
     --parameters parameters.{env}.json
   ```

## Configuration by Environment

### Development Environment

**Purpose**: Development and testing

**Configuration**:
- Log retention: 30 days (minimum)
- Daily quota: 1 GB
- Alert thresholds: Standard
- Cost: ~$5-20/month

**Use Cases**:
- Developer debugging
- Integration testing logs
- Feature validation

### Staging Environment

**Purpose**: Pre-production validation

**Configuration**:
- Log retention: 90 days
- Daily quota: 5 GB
- Alert thresholds: Standard
- Cost: ~$20-50/month

**Use Cases**:
- UAT validation
- Performance testing
- Release candidate validation

### Production Environment

**Purpose**: Production workloads

**Configuration**:
- Log retention: 180 days (compliance)
- Daily quota: Unlimited
- Alert thresholds: Standard
- Cost: ~$100-300/month (varies with usage)

**Use Cases**:
- Production monitoring
- Incident response
- Compliance auditing
- Performance optimization

## Key Features

### Log Analytics Workspace

- **Centralized Logging**: All resource logs in one place
- **Advanced Querying**: KQL (Kusto Query Language) for analysis
- **Data Retention**: Configurable 30-730 day retention
- **Cost Controls**: Daily ingestion quotas
- **Security**: Network access controls

### Monitoring Alerts

#### App Service Alerts
- High CPU usage (>80%)
- High memory usage (>80%)
- HTTP 5xx errors (>10 in 5 min)

#### SQL Database Alerts
- High DTU consumption (>80%)
- Database deadlocks (>0)

#### Storage Account Alerts
- Low availability (<99%)

#### Function App Alerts
- High error rate (>5 failures in 5 min)

### Diagnostic Settings

#### Enabled Log Categories

**App Service**:
- HTTP request logs
- Application logs
- Console output
- Audit events (180-day retention)

**SQL Database**:
- Query performance insights
- Errors and timeouts
- Deadlocks and blocks
- Wait statistics

**Storage Account**:
- Read/write/delete operations
- Transaction metrics

**Key Vault** (Critical):
- Audit events (365-day retention)
- Policy evaluations

## Compliance and Regulatory Requirements

### Data Retention

| Log Type | Retention | Regulation |
|----------|-----------|------------|
| Audit Logs | 365 days | SOC 2, ISO 27001 |
| Security Logs | 180 days | HIPAA, PCI DSS |
| Application Logs | 90 days | General best practice |
| Performance Metrics | 90 days | Operational monitoring |

### Audit Trail

The solution provides comprehensive audit trails for:
- **Access Control**: Who accessed what and when
- **Data Changes**: All modifications to critical data
- **Configuration Changes**: Infrastructure modifications
- **Security Events**: Failed logins, unauthorized access attempts

## Querying and Analysis

### Common Queries

#### Find Application Errors
```kusto
AppServiceAppLogs
| where TimeGenerated > ago(1h)
| where ResultDescription contains "error" or ResultDescription contains "exception"
| project TimeGenerated, ResultDescription, _ResourceId
| order by TimeGenerated desc
```

#### Monitor Database Performance
```kusto
AzureDiagnostics
| where ResourceType == "SERVERS/DATABASES"
| where Category == "QueryStoreRuntimeStatistics"
| summarize avg(avg_duration_s) by bin(TimeGenerated, 5m)
| render timechart
```

#### Track Key Vault Access
```kusto
AzureDiagnostics
| where ResourceType == "VAULTS"
| where Category == "AuditEvent"
| where TimeGenerated > ago(24h)
| project TimeGenerated, OperationName, CallerIPAddress, identity_claim_upn_s
| order by TimeGenerated desc
```

#### Storage Account Operations
```kusto
StorageBlobLogs
| where TimeGenerated > ago(1h)
| summarize count() by OperationName, bin(TimeGenerated, 5m)
| render columnchart
```

## Alert Response Procedures

### High CPU/Memory Alerts

1. Check current resource metrics in Azure Portal
2. Review recent deployments or configuration changes
3. Analyze application logs for errors or unusual activity
4. Consider scaling up/out if sustained high usage
5. Investigate and optimize code if inefficient

### HTTP 5xx Errors

1. Check application logs for error details
2. Review recent code deployments
3. Verify database and external service connectivity
4. Check for configuration issues
5. Implement fix and deploy
6. Monitor for resolution

### Database Issues

1. Review SQL Database metrics in portal
2. Check for slow queries using Query Performance Insights
3. Investigate deadlocks using diagnostic logs
4. Optimize queries or add indexes as needed
5. Consider scaling database if needed

### Storage Availability Issues

1. Check Azure Service Health for outages
2. Review storage account metrics
3. Verify network connectivity
4. Check for throttling or quota issues
5. Contact Azure Support if needed

## Cost Management

### Cost Breakdown

**Log Analytics**:
- Data ingestion: ~$2.30/GB
- Data retention (beyond 31 days): ~$0.10/GB/month
- Basic logs: ~$0.50/GB (limited query capabilities)

**Alerts**:
- Metric alerts: $0.10 per rule per month
- Log alerts: $1.50 per alert per month (first 5 free)

### Cost Optimization Tips

1. **Tune Log Categories**: Disable unnecessary log categories
2. **Set Quotas**: Use daily quotas in non-production environments
3. **Adjust Retention**: Use shorter retention for non-critical logs
4. **Archive Data**: Move old data to cheaper storage
5. **Use Basic Logs**: For logs that don't need full query capabilities

## Monitoring the Monitoring

Set up alerts on the monitoring infrastructure itself:

```kusto
// Alert if log ingestion stops
Usage
| where TimeGenerated > ago(1h)
| summarize IngestionVolumeMB = sum(Quantity) / 1024
| where IngestionVolumeMB == 0
```

## Troubleshooting

### Logs Not Appearing

**Symptoms**: Expected logs are not showing up in Log Analytics

**Solutions**:
1. Wait 5-15 minutes for initial ingestion
2. Verify diagnostic settings are configured correctly
3. Check that resources are generating activity
4. Verify workspace ID in diagnostic settings
5. Check RBAC permissions on workspace

### Alerts Not Firing

**Symptoms**: Expected alerts are not triggering

**Solutions**:
1. Verify alert rules are enabled
2. Check that thresholds are appropriate
3. Verify action group is configured correctly
4. Test email delivery (check spam folder)
5. Review alert history in Azure Monitor

### High Costs

**Symptoms**: Unexpectedly high monitoring costs

**Solutions**:
1. Review ingestion rates by resource
2. Identify high-volume log categories
3. Disable unnecessary logs
4. Set daily quotas
5. Adjust retention periods

## Security Considerations

### Access Control

- Use RBAC to limit who can view logs
- Separate permissions for different environments
- Audit access to sensitive logs
- Enable MFA for production access

### Data Protection

- Logs may contain sensitive information
- Configure data retention according to compliance
- Enable workspace firewall if needed
- Encrypt data at rest (default)

### Compliance

The solution helps meet:
- **SOC 2**: Comprehensive logging and monitoring
- **ISO 27001**: Security event tracking
- **GDPR**: Data access logging
- **HIPAA**: Audit trail requirements
- **PCI DSS**: Security monitoring

## Integration with CI/CD

Include monitoring deployment in your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Deploy Monitoring
  run: |
    az deployment group create \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --template-file infrastructure/arm-templates/log-analytics/log-analytics.json \
      --parameters infrastructure/arm-templates/log-analytics/parameters.${{ env.ENVIRONMENT }}.json
```

## Next Steps

1. **Deploy Templates**: Follow deployment order above
2. **Verify Logs**: Check that logs are flowing to workspace
3. **Test Alerts**: Trigger test alerts to verify notifications
4. **Create Dashboards**: Build custom dashboards in Azure Portal
5. **Document Runbooks**: Create response procedures for each alert
6. **Train Team**: Ensure ops team knows how to use the system

## Resources

- [Log Analytics README](../arm-templates/log-analytics/README.md)
- [Monitoring Alerts README](../arm-templates/monitoring-alerts/README.md)
- [Diagnostic Settings README](../arm-templates/diagnostic-settings/README.md)
- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [KQL Reference](https://docs.microsoft.com/azure/data-explorer/kusto/query/)

## Support

For issues with monitoring and observability:
1. Check troubleshooting section above
2. Review Azure Monitor documentation
3. Contact DevOps team
4. Open Azure Support ticket if needed
