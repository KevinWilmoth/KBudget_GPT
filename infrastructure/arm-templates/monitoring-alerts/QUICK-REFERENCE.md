# Azure Monitor Alerts - Quick Reference Guide

## Quick Start

### Deploy Alerts to an Environment

```powershell
# Development
cd infrastructure/arm-templates/monitoring-alerts
.\Deploy-MonitoringAlerts.ps1 -Environment dev -SendTestNotification

# Staging
.\Deploy-MonitoringAlerts.ps1 -Environment staging -SendTestNotification

# Production
.\Deploy-MonitoringAlerts.ps1 -Environment prod -SendTestNotification
```

### Deploy with Custom Configuration

```powershell
# With custom email
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "oncall@mycompany.com" `
  -SendTestNotification

# With webhook (Teams, Slack, etc.)
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "oncall@mycompany.com" `
  -WebhookUri "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" `
  -SendTestNotification
```

## Alert Summary

| Alert | Resource | Threshold | Severity | Action Time |
|-------|----------|-----------|----------|-------------|
| High CPU | App Service | > 80% | Warning | 30 min |
| High Memory | App Service | > 80% | Warning | 30 min |
| HTTP 5xx Errors | App Service | > 10 errors/5min | Error | 15 min |
| High DTU | SQL Database | > 80% | Warning | 30 min |
| Deadlocks | SQL Database | > 0 | Error | 15 min |
| Low Availability | Storage | < 99% | Error | 15 min |
| Function Errors | Functions | > 5 failures/5min | Warning | 30 min |

## Alert Response Checklist

### Severity 1 (Error) - 15 Minute Response

**HTTP 5xx Errors:**
- [ ] Check app health in Azure Portal
- [ ] Review Application Insights errors
- [ ] Check database connectivity
- [ ] Review recent deployments
- [ ] Consider rollback if deployment-related

**Database Deadlocks:**
- [ ] Check SQL diagnostic logs
- [ ] Analyze deadlock graph
- [ ] Review recent code changes
- [ ] Optimize transaction scope

**Storage Availability:**
- [ ] Check Azure Service Health
- [ ] Verify network connectivity
- [ ] Check for throttling
- [ ] Contact Azure Support if needed

### Severity 2 (Warning) - 30 Minute Response

**High CPU/Memory:**
- [ ] Check current metrics
- [ ] Review recent deployments
- [ ] Analyze Application Insights
- [ ] Consider scaling if sustained
- [ ] Investigate code optimization

**High DTU:**
- [ ] Review Query Performance Insights
- [ ] Identify expensive queries
- [ ] Check for missing indexes
- [ ] Consider database scaling

**Function Errors:**
- [ ] Check function logs
- [ ] Review recent deployments
- [ ] Verify dependencies
- [ ] Deploy fix if needed

## Common Tasks

### Get Alert Status

```powershell
# Azure Portal
Navigate to: Monitor → Alerts → Alert Rules

# PowerShell
Get-AzMetricAlertRuleV2 -ResourceGroupName kbudget-{env}-rg

# Azure CLI
az monitor metrics alert list --resource-group kbudget-{env}-rg
```

### View Alert History

```powershell
# Azure Portal
Monitor → Alerts → Alert History

# PowerShell
Get-AzAlertHistory -ResourceGroupName kbudget-{env}-rg
```

### Test Notifications

```powershell
# Using deployment script
.\Deploy-MonitoringAlerts.ps1 -Environment dev -SendTestNotification

# Using Azure Portal
Monitor → Alerts → Action Groups → [Your Action Group] → Test
```

### Update Email Address

**Option 1: Via Script**
```powershell
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "new-email@company.com"
```

**Option 2: Via Parameter File**
1. Edit `parameters.{env}.json`
2. Update `emailAddress` value
3. Redeploy: `.\Deploy-MonitoringAlerts.ps1 -Environment {env}`

### Add Webhook Integration

**Teams Webhook:**
1. In Teams channel: Settings → Connectors → Incoming Webhook
2. Copy webhook URL
3. Deploy:
```powershell
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "ops@company.com" `
  -WebhookUri "https://outlook.office.com/webhook/YOUR-WEBHOOK-URL"
```

**Slack Webhook:**
1. Create Incoming Webhook in Slack
2. Copy webhook URL
3. Deploy:
```powershell
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
  -EmailAddress "ops@company.com" `
  -WebhookUri "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Disable an Alert

```powershell
# PowerShell
$alert = Get-AzMetricAlertRuleV2 -ResourceGroupName kbudget-{env}-rg -Name {alert-name}
$alert.Enabled = $false
Set-AzMetricAlertRuleV2 -InputObject $alert

# Azure Portal
Monitor → Alerts → Alert Rules → [Select Alert] → Disable
```

### Enable an Alert

```powershell
# PowerShell
$alert = Get-AzMetricAlertRuleV2 -ResourceGroupName kbudget-{env}-rg -Name {alert-name}
$alert.Enabled = $true
Set-AzMetricAlertRuleV2 -InputObject $alert

# Azure Portal
Monitor → Alerts → Alert Rules → [Select Alert] → Enable
```

## Troubleshooting

### Alert Not Firing

1. Check if alert is enabled
2. Verify threshold is set correctly
3. Check if resource is generating metrics
4. Review evaluation frequency

### Notification Not Received

1. Check email spam/junk folder
2. Verify email address in action group
3. For webhooks, verify endpoint is accessible
4. Send test notification to verify

### Too Many Alerts

1. Review and adjust thresholds
2. Increase evaluation window
3. Consider dynamic thresholds

## Important Files

| File | Purpose |
|------|---------|
| `Deploy-MonitoringAlerts.ps1` | Main deployment script |
| `monitoring-alerts.json` | ARM template with alert definitions |
| `parameters.{env}.json` | Environment-specific parameters |
| `ALERT-CONFIGURATION-GUIDE.md` | Comprehensive documentation |
| `README.md` | Detailed setup guide |

## Getting Help

1. **Documentation:**
   - Read `ALERT-CONFIGURATION-GUIDE.md` for detailed information
   - Check `README.md` for setup instructions

2. **Logs:**
   - Deployment logs: `logs/alert-deployment_{env}_{timestamp}.log`
   - Alert documentation: `outputs/alert-configuration_{env}_latest.md`

3. **Azure Portal:**
   - Monitor → Alerts for alert status
   - Log Analytics for query and analysis

4. **Support:**
   - Contact DevOps team
   - Review Azure Monitor documentation
   - Open Azure Support ticket if needed

## Related Documentation

- **[ALERT-CONFIGURATION-GUIDE.md](./ALERT-CONFIGURATION-GUIDE.md)** - Comprehensive alert documentation
- **[README.md](./README.md)** - Detailed setup and configuration guide
- **[MONITORING-OBSERVABILITY.md](../../../docs/MONITORING-OBSERVABILITY.md)** - Overall monitoring strategy

---

**Quick Reference Version:** 1.0  
**Last Updated:** February 2026
