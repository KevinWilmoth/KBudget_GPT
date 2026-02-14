# Azure Monitor Alerts ARM Template

This template deploys Azure Monitor metric alerts and action groups for critical resources.

## Overview

This template creates comprehensive monitoring alerts for:
- **App Service**: CPU, memory, and HTTP errors
- **Cosmos DB**: RU consumption and throttling
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

### Cosmos DB Alerts

| Alert | Metric | Threshold | Severity | Description |
|-------|--------|-----------|----------|-------------|
| High RU Consumption | NormalizedRUConsumption | >80% | 2 (Warning) | Database resources stressed |
| Request Throttling | TotalRequests (429 status) | >0 | 1 (Error) | Requests being throttled |

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
| `cosmosDbAccountId` | string | Resource ID of Cosmos DB Account |
| `cosmosDbAccountName` | string | Name of Cosmos DB Account |
| `storageAccountId` | string | Resource ID of Storage Account |
| `storageAccountName` | string | Name of Storage Account |
| `functionAppId` | string | Resource ID of Function App |
| `functionAppName` | string | Name of Function App |
| `location` | string | Azure region |
| `tags` | object | Resource tags |

## Deployment

**Important**: This template requires resource IDs from already deployed resources. Deploy this after all application resources are created.

### Recommended: Using the Deployment Script

The easiest way to deploy alerts is using the provided PowerShell script:

```powershell
# Deploy to development
.\Deploy-MonitoringAlerts.ps1 -Environment dev

# Deploy with test notification
.\Deploy-MonitoringAlerts.ps1 -Environment dev -SendTestNotification

# Deploy to production with custom email
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "oncall@company.com" `
  -SendTestNotification

# Deploy with webhook integration (e.g., Teams or Slack)
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "oncall@company.com" `
  -WebhookUri "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" `
  -SendTestNotification

# WhatIf mode (preview changes)
.\Deploy-MonitoringAlerts.ps1 -Environment staging -WhatIf
```

**Script Features:**
- Automatic resource ID resolution
- Email and webhook configuration
- Test notification capability
- Validation and summary of deployed alerts
- Automatic documentation generation
- Detailed logging

### Alternative: Using Azure CLI

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

### Alternative: Using PowerShell Directly

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

### Configuring Webhook Notifications

To add webhook notifications (e.g., Microsoft Teams, Slack, PagerDuty):

**1. Using the Deployment Script (Recommended):**

```powershell
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "ops@company.com" `
  -WebhookUri "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

**2. Using Parameter Files:**

Edit the parameter file (`parameters.{env}.json`):

```json
{
  "emailAddress": {
    "value": "ops@company.com"
  },
  "webhookUri": {
    "value": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  },
  "enableWebhook": {
    "value": true
  }
}
```

**Microsoft Teams Setup:**
1. In Teams, go to the channel where you want alerts
2. Click the "..." menu → Connectors
3. Add "Incoming Webhook" connector
4. Configure and copy the webhook URL
5. Use this URL in the `webhookUri` parameter

**Slack Setup:**
1. Create an Incoming Webhook app in your Slack workspace
2. Select the channel for notifications
3. Copy the webhook URL
4. Use this URL in the `webhookUri` parameter

**Custom Webhooks:**
- Any HTTPS endpoint can be used
- Receives alerts in Common Alert Schema format
- Must respond with 200 OK within 10 seconds

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

### Using the Deployment Script

The deployment script can send test notifications to verify your configuration:

```powershell
# Deploy and send test notification
.\Deploy-MonitoringAlerts.ps1 -Environment dev -SendTestNotification

# Send test to existing deployment
.\Deploy-MonitoringAlerts.ps1 -Environment prod -SendTestNotification
```

The test notification will:
- Send a test alert to configured email addresses
- Send a test alert to configured webhooks (if enabled)
- Verify action group is working correctly

### Manual Testing

To manually test that alerts are working:

1. **App Service CPU**: Generate load on the application using a load testing tool
2. **SQL Database DTU**: Run intensive queries against the database
3. **Storage Availability**: Temporarily restrict storage access (testing only!)
4. **Function Errors**: Deploy a function that intentionally throws exceptions

### Verifying Alerts

After deployment, check:
1. Azure Portal → Monitor → Alerts to see configured rules
2. Email inbox for test notification (check spam folder)
3. Webhook endpoint for test payload
4. Alert history in Azure Portal

**Note:** It may take 5-15 minutes for test notifications to arrive.

## Outputs

- **actionGroupId**: Resource ID of the Action Group
- **actionGroupName**: Name of the Action Group

## Best Practices

1. **Test in Non-Production First**: Verify alerts work in dev/staging before production
2. **Avoid Alert Fatigue**: Set appropriate thresholds to reduce false positives
3. **Regular Review**: Periodically review and adjust alert rules based on actual usage
4. **Multiple Channels**: Use both email and webhooks for critical production alerts
5. **Documentation**: Document your alert response procedures (see ALERT-CONFIGURATION-GUIDE.md)
6. **Test Regularly**: Send test notifications monthly to verify configuration
7. **Monitor the Monitors**: Ensure alerts themselves are working correctly

## Documentation

- **[ALERT-CONFIGURATION-GUIDE.md](./ALERT-CONFIGURATION-GUIDE.md)** - Comprehensive guide with:
  - Detailed alert configuration for each resource
  - Alert thresholds and severities explained
  - Response procedures for each alert type
  - Webhook integration examples
  - Testing procedures
  - Troubleshooting guide

## Related Resources

- [Log Analytics](../log-analytics/README.md) - Centralized logging workspace
- [Diagnostic Settings](../diagnostic-settings/README.md) - Configure diagnostic data collection
- [Deployment Script](./Deploy-MonitoringAlerts.ps1) - PowerShell deployment script

## References

- [Azure Monitor Alerts Documentation](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-overview)
- [Metric Alert Rules](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-metric)
- [Action Groups](https://docs.microsoft.com/azure/azure-monitor/alerts/action-groups)
- [Common Alert Schema](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-common-schema)
