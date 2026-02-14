# Azure Monitor Alert Configuration Guide

## Overview

This document provides detailed information about Azure Monitor alert rules, thresholds, severities, and response procedures for the KBudget GPT application.

## Alert Configuration by Resource Type

### App Service Alerts

#### 1. High CPU Usage Alert

**Alert Name:** `{appServiceName}-high-cpu`

**Purpose:** Detect when the App Service is experiencing high CPU utilization that could impact performance.

**Configuration:**
- **Metric:** `CpuPercentage`
- **Metric Namespace:** `Microsoft.Web/sites`
- **Threshold:** > 80%
- **Time Aggregation:** Average
- **Evaluation Frequency:** Every 5 minutes (PT5M)
- **Window Size:** 5 minutes (PT5M)
- **Severity:** 2 (Warning)
- **Operator:** GreaterThan

**When it fires:**
- The alert fires when the average CPU percentage exceeds 80% over a 5-minute window
- Evaluated every 5 minutes

**Response Actions:**
1. Check Azure Portal metrics to confirm sustained high CPU
2. Review recent code deployments or configuration changes
3. Analyze Application Insights for slow requests or inefficient code
4. Check for unexpected traffic spikes or DDoS attacks
5. Review application logs for errors or exceptions
6. Consider vertical scaling (scale up to higher SKU) if sustained
7. Consider horizontal scaling (scale out) if traffic-related
8. Investigate and optimize code for CPU-intensive operations

**Expected Resolution Time:** 15-30 minutes

---

#### 2. High Memory Usage Alert

**Alert Name:** `{appServiceName}-high-memory`

**Purpose:** Detect when the App Service is experiencing high memory utilization that could cause application instability.

**Configuration:**
- **Metric:** `MemoryPercentage`
- **Metric Namespace:** `Microsoft.Web/sites`
- **Threshold:** > 80%
- **Time Aggregation:** Average
- **Evaluation Frequency:** Every 5 minutes (PT5M)
- **Window Size:** 5 minutes (PT5M)
- **Severity:** 2 (Warning)
- **Operator:** GreaterThan

**When it fires:**
- The alert fires when the average memory percentage exceeds 80% over a 5-minute window
- Evaluated every 5 minutes

**Response Actions:**
1. Check Azure Portal metrics to confirm memory usage pattern
2. Review recent deployments that might have introduced memory leaks
3. Analyze Application Insights for memory-intensive operations
4. Check for caching issues or large object allocations
5. Review application logs for OutOfMemory exceptions
6. Restart the App Service if memory leak suspected (temporary fix)
7. Consider vertical scaling if legitimate high memory usage
8. Profile the application to identify memory leaks
9. Optimize code to reduce memory footprint

**Expected Resolution Time:** 15-30 minutes

---

#### 3. HTTP 5xx Errors Alert

**Alert Name:** `{appServiceName}-http-errors`

**Purpose:** Detect when the App Service is returning server errors that indicate application failures.

**Configuration:**
- **Metric:** `Http5xx`
- **Metric Namespace:** `Microsoft.Web/sites`
- **Threshold:** > 10 errors
- **Time Aggregation:** Total
- **Evaluation Frequency:** Every 5 minutes (PT5M)
- **Window Size:** 5 minutes (PT5M)
- **Severity:** 1 (Error)
- **Operator:** GreaterThan

**When it fires:**
- The alert fires when more than 10 HTTP 5xx errors occur within a 5-minute window
- Evaluated every 5 minutes
- Higher severity (1) as this indicates actual service failures

**Response Actions:**
1. **IMMEDIATE:** Check application health in Azure Portal
2. Review Application Insights for specific error details
3. Check application logs for stack traces and error messages
4. Verify database connectivity and health
5. Verify external service dependencies (APIs, storage, etc.)
6. Review recent code deployments - consider rollback if related
7. Check for configuration issues (connection strings, app settings)
8. Monitor error rate to determine if issue is ongoing
9. Implement fix and deploy (or rollback if deployment-related)
10. Verify resolution with monitoring

**Expected Resolution Time:** 5-15 minutes (critical issue)

---

### Cosmos DB Alerts

#### 4. High RU Consumption Alert

**Alert Name:** `{cosmosDbAccountName}-high-ru`

**Purpose:** Detect when the Cosmos DB is consuming high Request Units (RUs), indicating resource constraints.

**Configuration:**
- **Metric:** `NormalizedRUConsumption`
- **Metric Namespace:** `Microsoft.DocumentDB/databaseAccounts`
- **Threshold:** > 80%
- **Time Aggregation:** Maximum
- **Evaluation Frequency:** Every 5 minutes (PT5M)
- **Window Size:** 5 minutes (PT5M)
- **Severity:** 2 (Warning)
- **Operator:** GreaterThan

**When it fires:**
- The alert fires when the maximum normalized RU consumption exceeds 80% over a 5-minute window
- Evaluated every 5 minutes

**Response Actions:**
1. Check Cosmos DB metrics in Azure Portal
2. Review query performance and identify expensive queries
3. Check for hot partitions using partition key statistics
4. Review recent application changes that might increase DB load
5. Look for inefficient queries or missing indexes
6. Consider query optimization (use partition keys, add composite indexes)
7. Consider increasing provisioned RU/s if sustained high usage
8. Implement query caching where appropriate
9. Review partition key design for better distribution
10. Consider using autoscale throughput

**Expected Resolution Time:** 15-45 minutes

---

#### 5. Request Throttling Alert

**Alert Name:** `{cosmosDbAccountName}-throttling`

**Purpose:** Detect when Cosmos DB requests are being throttled (429 status codes), indicating insufficient throughput.

**Configuration:**
- **Metric:** `TotalRequests` (filtered by status code 429)
- **Metric Namespace:** `Microsoft.DocumentDB/databaseAccounts`
- **Threshold:** > 0
- **Time Aggregation:** Total
- **Evaluation Frequency:** Every 5 minutes (PT5M)
- **Window Size:** 5 minutes (PT5M)
- **Severity:** 1 (Error)
- **Operator:** GreaterThan

**When it fires:**
- The alert fires when any request throttling occurs within a 5-minute window
- Evaluated every 5 minutes
- Higher severity (1) as throttling indicates request failures

**Response Actions:**
1. **IMMEDIATE:** Check if throttling is causing user-facing errors
2. Review Cosmos DB diagnostic logs for throttled requests
3. Check which operations are being throttled
4. Review partition key distribution for hot partitions
5. Identify queries or operations consuming excessive RUs
6. Optimize queries to reduce RU consumption
7. Implement retry logic with exponential backoff in application
8. Consider increasing provisioned RU/s temporarily
9. Enable autoscale if not already enabled
10. Review and optimize partition key strategy

**Expected Resolution Time:** 15-30 minutes

---

### Storage Account Alerts

#### 6. Low Availability Alert

**Alert Name:** `{storageAccountName}-availability`

**Purpose:** Detect when the Storage Account availability drops below acceptable levels.

**Configuration:**
- **Metric:** `Availability`
- **Metric Namespace:** `Microsoft.Storage/storageAccounts`
- **Threshold:** < 99%
- **Time Aggregation:** Average
- **Evaluation Frequency:** Every 5 minutes (PT5M)
- **Window Size:** 5 minutes (PT5M)
- **Severity:** 1 (Error)
- **Operator:** LessThan

**When it fires:**
- The alert fires when the average availability drops below 99% over a 5-minute window
- Evaluated every 5 minutes
- Higher severity (1) as storage issues can cause widespread application failures

**Response Actions:**
1. **IMMEDIATE:** Check Azure Service Health for outages
2. Review storage account metrics in Azure Portal
3. Verify network connectivity to storage account
4. Check for throttling or rate limiting issues
5. Review storage account firewall and virtual network rules
6. Check for quota or capacity issues
7. Verify storage account keys haven't been rotated without updating apps
8. Check for concurrent request limits being exceeded
9. Review recent changes to storage access policies
10. Contact Azure Support if Azure-side issue confirmed

**Expected Resolution Time:** 5-15 minutes (if not Azure outage)

---

### Function App Alerts

#### 7. High Function Error Rate Alert

**Alert Name:** `{functionAppName}-errors`

**Purpose:** Detect when Azure Functions are failing at a high rate.

**Configuration:**
- **Metric:** `FunctionExecutionCount`
- **Metric Namespace:** `Microsoft.Web/sites`
- **Threshold:** > 5 failures
- **Time Aggregation:** Total
- **Evaluation Frequency:** Every 5 minutes (PT5M)
- **Window Size:** 5 minutes (PT5M)
- **Severity:** 2 (Warning)
- **Operator:** GreaterThan
- **Dimension Filter:** status = "Failed"

**When it fires:**
- The alert fires when more than 5 function executions fail within a 5-minute window
- Evaluated every 5 minutes
- Only counts executions with "Failed" status

**Response Actions:**
1. Check Function App logs in Azure Portal
2. Review Application Insights for function execution details
3. Identify which specific function(s) are failing
4. Review recent code deployments to functions
5. Check function bindings and triggers configuration
6. Verify connected services (storage, databases, APIs) are healthy
7. Check for timeout issues (increase timeout if needed)
8. Review function app settings and connection strings
9. Check for dependency issues or missing packages
10. Implement fix and redeploy function code

**Expected Resolution Time:** 15-30 minutes

---

## Alert Severity Levels Explained

### Severity 0 - Critical
**Description:** Service is completely down or major business impact  
**Response Time:** Immediate (within 5 minutes)  
**Examples:**
- All instances of App Service down
- Complete database unavailability
- Data loss or corruption

**Current Usage:** Not currently used, but can be configured for critical scenarios

---

### Severity 1 - Error
**Description:** Major functionality is impaired, immediate attention required  
**Response Time:** Within 15 minutes  
**Examples:**
- HTTP 5xx errors (users experiencing failures)
- Request throttling (insufficient throughput)
- Storage availability issues

**Current Usage:**
- App Service HTTP 5xx errors
- Cosmos DB request throttling
- Storage account availability

---

### Severity 2 - Warning
**Description:** Potential issues that require attention but service is still functional  
**Response Time:** Within 30 minutes to 1 hour  
**Examples:**
- High CPU or memory usage (performance degradation)
- High RU consumption (database stressed)
- Elevated function error rates

**Current Usage:**
- App Service high CPU
- App Service high memory
- Cosmos DB high RU consumption
- Function App errors

---

### Severity 3 - Informational
**Description:** Informational messages for awareness  
**Response Time:** During business hours  
**Examples:**
- Configuration changes
- Scaling events
- Maintenance notifications

**Current Usage:** Not currently configured

---

### Severity 4 - Verbose
**Description:** Detailed tracking information for troubleshooting  
**Response Time:** As needed for analysis  
**Examples:**
- Detailed performance metrics
- Debugging information

**Current Usage:** Not currently configured

---

## Action Group Configuration

### Email Notifications

**Configuration:**
- **Receiver Name:** EmailOpsTeam
- **Email Address:** Configured per environment (devops@example.com by default)
- **Common Alert Schema:** Enabled

**Email Contents Include:**
- Alert name and severity
- Resource affected
- Metric details and threshold
- Time of alert
- Link to Azure Portal for investigation

**Setup Instructions:**
1. Edit the parameter file for your environment (`parameters.{env}.json`)
2. Update the `emailAddress` value
3. Redeploy the alerts

**Example:**
```json
{
  "emailAddress": {
    "value": "ops-team@mycompany.com"
  }
}
```

---

### Webhook Notifications

**Configuration:**
- **Receiver Name:** WebhookReceiver
- **Service URI:** Configurable webhook endpoint
- **Common Alert Schema:** Enabled

**Supported Integrations:**
- Microsoft Teams
- Slack
- PagerDuty
- Custom webhook endpoints
- Logic Apps
- Azure Functions

**Setup Instructions:**
1. Obtain webhook URL from your notification service
2. Edit the parameter file for your environment
3. Set `enableWebhook` to `true`
4. Set `webhookUri` to your webhook URL
5. Redeploy the alerts

**Example:**
```json
{
  "webhookUri": {
    "value": "https://myteam.webhook.office.com/webhookb2/..."
  },
  "enableWebhook": {
    "value": true
  }
}
```

**Microsoft Teams Example:**
1. In Teams, go to your channel settings
2. Click "Connectors"
3. Add "Incoming Webhook"
4. Copy the webhook URL
5. Use this URL in the `webhookUri` parameter

**Slack Example:**
1. In Slack, create an Incoming Webhook app
2. Select the channel for notifications
3. Copy the webhook URL
4. Use this URL in the `webhookUri` parameter

---

## Environment-Specific Configurations

### Development Environment

**Purpose:** Development and testing

**Alert Configuration:**
- Standard thresholds (may be less sensitive)
- Email notifications only (by default)
- Used for testing alert logic

**Recommendations:**
- Test alert rules here first
- Use for validating changes to thresholds
- Can use more relaxed thresholds to avoid noise

---

### Staging Environment

**Purpose:** Pre-production validation

**Alert Configuration:**
- Production-equivalent thresholds
- Email notifications
- Optional webhook for pre-production team

**Recommendations:**
- Mirror production alert configuration
- Use for testing alert response procedures
- Validate alerts during load testing

---

### Production Environment

**Purpose:** Production workloads

**Alert Configuration:**
- Strict thresholds for early detection
- Email notifications to operations team
- Webhook integrations (Teams, Slack, PagerDuty)
- 24/7 monitoring

**Recommendations:**
- Set up multiple notification channels
- Document on-call procedures
- Regularly review and tune thresholds
- Implement automated remediation where possible

---

## Testing Alert Configuration

### Manual Testing

Use the PowerShell script to send test notifications:

```powershell
# Deploy and test alerts
.\Deploy-MonitoringAlerts.ps1 -Environment dev -SendTestNotification

# Deploy with custom email
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
    -EmailAddress "oncall@company.com" `
    -SendTestNotification

# Deploy with webhook
.\Deploy-MonitoringAlerts.ps1 -Environment prod `
    -EmailAddress "oncall@company.com" `
    -WebhookUri "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" `
    -SendTestNotification
```

### Simulating Alert Conditions

#### Test App Service CPU Alert
```powershell
# Generate CPU load (testing/staging only!)
# Use a load testing tool or stress test endpoint
```

#### Test App Service HTTP Errors
```powershell
# Deploy code that intentionally throws exceptions
# Or use Application Insights to simulate errors
```

#### Test Cosmos DB Alerts
```powershell
# Run queries with high RU consumption
# Use Data Explorer in Azure Portal to execute expensive queries
```

---

## Monitoring Best Practices

### 1. Threshold Tuning
- Review alert history monthly
- Adjust thresholds to reduce false positives
- Balance sensitivity vs. alert fatigue

### 2. Alert Fatigue Prevention
- Don't set too many alerts
- Use appropriate severities
- Group related alerts
- Implement alert suppression during maintenance

### 3. Response Documentation
- Document response procedures for each alert
- Create runbooks for common issues
- Train team on alert response

### 4. Regular Review
- Review alerts quarterly
- Remove unused alerts
- Update thresholds based on usage patterns
- Add new alerts as system evolves

### 5. Integration
- Integrate with incident management systems
- Automate ticket creation for alerts
- Link alerts to dashboards and documentation

---

## Troubleshooting

### Alerts Not Firing

**Symptoms:** Expected alerts are not triggering

**Solutions:**
1. Verify alert rules are enabled in Azure Portal
2. Check that resources are generating metrics
3. Verify thresholds are set appropriately
4. Check evaluation frequency and window size
5. Review alert rule queries in Azure Portal
6. Verify action group is attached to alert rules

### Alerts Not Received

**Symptoms:** Alerts firing but notifications not received

**Solutions:**
1. Verify action group configuration
2. Check email spam/junk folders
3. Verify email address in action group is correct
4. For webhooks, verify endpoint is accessible
5. Check action group test notification feature
6. Review Azure Monitor alert history

### Too Many Alerts

**Symptoms:** Excessive alerts causing fatigue

**Solutions:**
1. Review and adjust thresholds
2. Increase window size for more sustained conditions
3. Reduce evaluation frequency if appropriate
4. Implement alert suppression rules
5. Use dynamic thresholds (machine learning-based)

---

## Cost Considerations

### Alert Pricing

- **Metric Alert Rules:** $0.10 per alert rule per month
- **Log Alert Rules:** $1.50 per alert rule per month (first 5 free)
- **Action Group Notifications:**
  - Email: Free
  - Webhook: Free
  - SMS: $0.50 per SMS
  - Voice: $1.00 per call

### Current Configuration Cost Estimate

**Per Environment:**
- 7 metric alert rules: $0.70/month
- 1 action group: Free
- Email notifications: Free
- Webhook notifications: Free

**Total:** ~$0.70/month per environment
**All Environments (dev, staging, prod):** ~$2.10/month

---

## Additional Resources

- [Azure Monitor Alerts Documentation](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-overview)
- [Metric Alert Best Practices](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-metric-best-practices)
- [Action Groups Reference](https://docs.microsoft.com/azure/azure-monitor/alerts/action-groups)
- [Common Alert Schema](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-common-schema)
- [Alert Rule Troubleshooting](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-troubleshoot)

---

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Maintainer:** DevOps Team
