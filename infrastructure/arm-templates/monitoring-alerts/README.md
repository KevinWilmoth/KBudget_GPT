# Azure Monitor Alerts ARM Template

This template deploys Azure Monitor metric alerts and action groups for critical resources.

## Overview

This template creates comprehensive monitoring alerts for:
- **App Service**: CPU, memory, and HTTP errors
- **SQL Database**: DTU usage and deadlocks
- **Storage Account**: Availability monitoring
- **Function App**: Execution errors

## Features

✅ **Proactive Monitoring**: Alerts before issues impact users  
✅ **Email Notifications**: Instant alerts to operations team  
✅ **Multi-Resource**: Monitors all critical infrastructure  
✅ **Customizable Thresholds**: Adjust alert sensitivity per environment

## Alert Rules

### App Service Alerts

| Alert | Metric | Threshold | Severity | Description |
|-------|--------|-----------|----------|-------------|
| High CPU | CpuPercentage | >80% | 2 (Warning) | CPU usage is high |
| High Memory | MemoryPercentage | >80% | 2 (Warning) | Memory usage is high |
| HTTP Errors | Http5xx | >10 errors | 1 (Error) | Server errors detected |

### SQL Database Alerts

| Alert | Metric | Threshold | Severity | Description |
|-------|--------|-----------|----------|-------------|
| High DTU | dtu_consumption_percent | >80% | 2 (Warning) | Database resources stressed |
| Deadlock | deadlock | >0 | 1 (Error) | Database deadlocks occurring |

### Storage Account Alerts

| Alert | Metric | Threshold | Severity | Description |
|-------|--------|-----------|----------|-------------|
| Low Availability | Availability | <99% | 1 (Error) | Storage availability degraded |

### Function App Alerts

| Alert | Metric | Threshold | Severity | Description |
|-------|--------|-----------|----------|-------------|
| Function Errors | FunctionExecutionCount (Failed) | >5 failures | 2 (Warning) | High function error rate |

## Alert Severities

- **Severity 0 (Critical)**: Service completely down
- **Severity 1 (Error)**: Major functionality impaired
- **Severity 2 (Warning)**: Potential issues requiring attention
- **Severity 3 (Informational)**: Informational messages
- **Severity 4 (Verbose)**: Detailed tracking information

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `actionGroupName` | string | Name of the Action Group |
| `actionGroupShortName` | string | Short name (max 12 chars) |
| `emailAddress` | string | Email for notifications |
| `appServiceId` | string | Resource ID of App Service |
| `appServiceName` | string | Name of App Service |
| `sqlServerId` | string | Resource ID of SQL Server |
| `sqlServerName` | string | Name of SQL Server |
| `sqlDatabaseName` | string | Name of SQL Database |
| `storageAccountId` | string | Resource ID of Storage Account |
| `storageAccountName` | string | Name of Storage Account |
| `functionAppId` | string | Resource ID of Function App |
| `functionAppName` | string | Name of Function App |
| `location` | string | Azure region |
| `tags` | object | Resource tags |

## Deployment

**Important**: This template requires resource IDs from already deployed resources. Deploy this after all application resources are created.

### Using Azure CLI

```bash
# Deploy to development
az deployment group create \
  --resource-group kbudget-dev-rg \
  --template-file monitoring-alerts.json \
  --parameters parameters.dev.json

# Deploy to staging
az deployment group create \
  --resource-group kbudget-staging-rg \
  --template-file monitoring-alerts.json \
  --parameters parameters.staging.json

# Deploy to production
az deployment group create \
  --resource-group kbudget-prod-rg \
  --template-file monitoring-alerts.json \
  --parameters parameters.prod.json
```

### Using PowerShell

```powershell
# Deploy to development
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-dev-rg `
  -TemplateFile monitoring-alerts.json `
  -TemplateParameterFile parameters.dev.json

# Deploy to staging
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-staging-rg `
  -TemplateFile monitoring-alerts.json `
  -TemplateParameterFile parameters.staging.json

# Deploy to production
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-prod-rg `
  -TemplateFile monitoring-alerts.json `
  -TemplateParameterFile parameters.prod.json
```

## Configuration

### Updating Email Addresses

Edit the parameter files to change notification recipients:

```json
{
  "emailAddress": {
    "value": "your-ops-team@example.com"
  }
}
```

### Adjusting Alert Thresholds

Modify the template to change thresholds:

```json
{
  "threshold": 80,  // Change from 80 to desired value
  "timeAggregation": "Average"
}
```

### Evaluation Frequency

All alerts are evaluated every 5 minutes by default:

```json
{
  "evaluationFrequency": "PT5M",  // PT5M = 5 minutes
  "windowSize": "PT5M"
}
```

## Action Groups

The template creates an Action Group that:
- Sends email notifications using the common alert schema
- Can be extended to include SMS, webhooks, Azure Functions, etc.
- Is reusable across multiple alert rules

## Testing Alerts

To test that alerts are working:

1. **App Service CPU**: Generate load on the application
2. **SQL Database DTU**: Run intensive queries
3. **Storage Availability**: Temporarily restrict storage access
4. **Function Errors**: Deploy a function that throws exceptions

## Outputs

- **actionGroupId**: Resource ID of the Action Group
- **actionGroupName**: Name of the Action Group

## Best Practices

1. **Test in Non-Production First**: Verify alerts work in dev/staging before production
2. **Avoid Alert Fatigue**: Set appropriate thresholds to reduce false positives
3. **Regular Review**: Periodically review and adjust alert rules
4. **Multiple Channels**: Consider adding SMS or webhook actions for critical alerts
5. **Documentation**: Document your alert response procedures

## Related Resources

- [Log Analytics](../log-analytics/README.md) - Centralized logging workspace
- [Diagnostic Settings](../diagnostic-settings/README.md) - Configure diagnostic data collection

## References

- [Azure Monitor Alerts Documentation](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-overview)
- [Metric Alert Rules](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-metric)
- [Action Groups](https://docs.microsoft.com/azure/azure-monitor/alerts/action-groups)
