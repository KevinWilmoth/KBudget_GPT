# Log Analytics Workspace ARM Template

This template deploys an Azure Log Analytics Workspace for centralized logging and monitoring.

## Overview

The Log Analytics Workspace provides a centralized repository for collecting, analyzing, and acting on log data from Azure resources and on-premises systems.

## Features

✅ **Centralized Logging**: Single location for all logs and metrics  
✅ **Compliance**: Configurable retention periods (30-730 days)  
✅ **Cost Control**: Daily ingestion quota limits  
✅ **Security**: Network access controls for ingestion and query

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `workspaceName` | string | - | Name of the Log Analytics Workspace |
| `location` | string | Resource Group location | Azure region for deployment |
| `sku` | string | PerGB2018 | Pricing tier (Free, Standalone, PerNode, PerGB2018) |
| `retentionInDays` | int | 90 | Data retention period (30-730 days) |
| `dailyQuotaGb` | int | -1 | Daily ingestion limit in GB (-1 for unlimited) |
| `publicNetworkAccessForIngestion` | string | Enabled | Network access for log ingestion |
| `publicNetworkAccessForQuery` | string | Enabled | Network access for querying data |
| `tags` | object | {} | Resource tags |

## Environment-Specific Configurations

### Development
- **Retention**: 30 days (minimum for compliance)
- **Daily Quota**: 1 GB (cost control)
- **Purpose**: Testing and development logging

### Staging
- **Retention**: 90 days (extended testing period)
- **Daily Quota**: 5 GB (moderate usage)
- **Purpose**: Pre-production validation

### Production
- **Retention**: 180 days (regulatory compliance)
- **Daily Quota**: Unlimited (no restrictions on critical logs)
- **Purpose**: Production monitoring and compliance

## Deployment

### Using Azure CLI

```bash
# Deploy to development
az deployment group create \
  --resource-group kbudget-dev-rg \
  --template-file log-analytics.json \
  --parameters parameters.dev.json

# Deploy to staging
az deployment group create \
  --resource-group kbudget-staging-rg \
  --template-file log-analytics.json \
  --parameters parameters.staging.json

# Deploy to production
az deployment group create \
  --resource-group kbudget-prod-rg \
  --template-file log-analytics.json \
  --parameters parameters.prod.json
```

### Using PowerShell

```powershell
# Deploy to development
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-dev-rg `
  -TemplateFile log-analytics.json `
  -TemplateParameterFile parameters.dev.json

# Deploy to staging
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-staging-rg `
  -TemplateFile log-analytics.json `
  -TemplateParameterFile parameters.staging.json

# Deploy to production
New-AzResourceGroupDeployment `
  -ResourceGroupName kbudget-prod-rg `
  -TemplateFile log-analytics.json `
  -TemplateParameterFile parameters.prod.json
```

## Outputs

- **workspaceId**: Resource ID of the Log Analytics Workspace
- **workspaceName**: Name of the workspace
- **customerId**: Workspace ID (Customer ID) for connecting resources

## Compliance and Retention

The template ensures compliance with typical regulatory requirements:

- **Audit logs**: Key Vault audit events retained for 365 days
- **Security logs**: IP Security audit logs retained for 180 days
- **Application logs**: Standard application logs retained for 90 days
- **Diagnostic data**: Metrics and performance data retained for 90 days

## Cost Optimization

To optimize costs:
1. Set appropriate retention periods for each environment
2. Use daily quota limits in non-production environments
3. Monitor ingestion rates and adjust quotas accordingly
4. Review and archive old data periodically

## Related Resources

- [Monitoring Alerts](../monitoring-alerts/README.md) - Configure alerts based on Log Analytics data
- [Diagnostic Settings](../diagnostic-settings/README.md) - Send resource logs to this workspace

## References

- [Azure Log Analytics Documentation](https://docs.microsoft.com/azure/azure-monitor/logs/log-analytics-overview)
- [Log Analytics Pricing](https://azure.microsoft.com/pricing/details/monitor/)
- [Data Retention and Archive](https://docs.microsoft.com/azure/azure-monitor/logs/data-retention-archive)
