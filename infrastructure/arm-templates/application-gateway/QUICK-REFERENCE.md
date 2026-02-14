# Quick Reference Guide

Quick reference for common Application Gateway with WAF operations.

## Table of Contents

- [Deployment Commands](#deployment-commands)
- [WAF Operations](#waf-operations)
- [Certificate Management](#certificate-management)
- [Health Monitoring](#health-monitoring)
- [Troubleshooting Commands](#troubleshooting-commands)
- [Log Queries](#log-queries)

## Deployment Commands

### Deploy Application Gateway

```powershell
# Development
.\Deploy-ApplicationGateway.ps1 -Environment dev

# Staging
.\Deploy-ApplicationGateway.ps1 -Environment staging

# Production
.\Deploy-ApplicationGateway.ps1 -Environment prod

# With SSL certificate
$certPassword = ConvertTo-SecureString "Password" -AsPlainText -Force
.\Deploy-ApplicationGateway.ps1 `
    -Environment dev `
    -SslCertificatePath ".\cert.pfx" `
    -SslCertificatePassword $certPassword

# WhatIf mode
.\Deploy-ApplicationGateway.ps1 -Environment dev -WhatIf
```

### Test WAF

```powershell
# Basic test
.\Test-WAF.ps1 -ApplicationGatewayUrl "https://kbudget-dev-appgw.eastus.cloudapp.azure.com"

# Skip SSL validation (dev/staging)
.\Test-WAF.ps1 `
    -ApplicationGatewayUrl "https://kbudget-dev-appgw.eastus.cloudapp.azure.com" `
    -SkipSslValidation
```

## WAF Operations

### Get WAF Policy

```powershell
Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-dev-appgw-waf-policy" `
    -ResourceGroupName "kbudget-dev-rg"
```

### Switch WAF Mode

```powershell
# Get policy
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-dev-appgw-waf-policy" `
    -ResourceGroupName "kbudget-dev-rg"

# Set to Detection mode
$wafPolicy.PolicySettings.Mode = "Detection"
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy

# Set to Prevention mode
$wafPolicy.PolicySettings.Mode = "Prevention"
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

### View WAF Rules

```powershell
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-dev-appgw-waf-policy" `
    -ResourceGroupName "kbudget-dev-rg"

# View managed rule sets
$wafPolicy.ManagedRules.ManagedRuleSets

# View custom rules
$wafPolicy.CustomRules
```

### Create Custom WAF Rule

```powershell
# Rate limiting rule
$matchCondition = New-AzApplicationGatewayFirewallMatchVariable `
    -VariableName RemoteAddr

$condition = New-AzApplicationGatewayFirewallCondition `
    -MatchVariable $matchCondition `
    -Operator IPMatch `
    -MatchValue @("192.168.1.0/24") `
    -NegationCondition $false

$rateLimitRule = New-AzApplicationGatewayFirewallCustomRule `
    -Name "RateLimitRule" `
    -Priority 10 `
    -RuleType RateLimitRule `
    -RateLimitDuration OneMin `
    -RateLimitThreshold 100 `
    -Action Block `
    -MatchCondition $condition

# Add to policy
$wafPolicy.CustomRules.Add($rateLimitRule)
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

## Certificate Management

### View Current Certificates

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

# List SSL certificates
$appGw.SslCertificates | Select-Object Name, @{N='Thumbprint';E={$_.PublicCertData}}
```

### Update SSL Certificate

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$password = ConvertTo-SecureString "Password" -AsPlainText -Force

Set-AzApplicationGatewaySslCertificate `
    -ApplicationGateway $appGw `
    -Name "appGatewaySslCertificate" `
    -CertificateFile ".\new-cert.pfx" `
    -Password $password

Set-AzApplicationGateway -ApplicationGateway $appGw
```

### Add New Certificate

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$password = ConvertTo-SecureString "Password" -AsPlainText -Force

Add-AzApplicationGatewaySslCertificate `
    -ApplicationGateway $appGw `
    -Name "newCertificate" `
    -CertificateFile ".\cert.pfx" `
    -Password $password

Set-AzApplicationGateway -ApplicationGateway $appGw
```

## Health Monitoring

### Check Backend Health

```powershell
# Get health status
$health = Get-AzApplicationGatewayBackendHealth `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-appgw"

# Display summary
foreach ($pool in $health.BackendAddressPools) {
    foreach ($settings in $pool.BackendHttpSettingsCollection) {
        foreach ($server in $settings.Servers) {
            Write-Host "$($server.Address): $($server.Health)"
        }
    }
}
```

### View Health Probe Configuration

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$appGw.Probes | Format-List
```

### Update Health Probe

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$probe = Get-AzApplicationGatewayProbeConfig `
    -ApplicationGateway $appGw `
    -Name "appGatewayHealthProbe"

# Update probe settings
$probe.Path = "/health"
$probe.Interval = 60
$probe.Timeout = 30
$probe.UnhealthyThreshold = 5

Set-AzApplicationGateway -ApplicationGateway $appGw
```

## Troubleshooting Commands

### View Application Gateway Status

```powershell
Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg" | 
    Select-Object Name, ProvisioningState, OperationalState
```

### Check Public IP

```powershell
$pip = Get-AzPublicIpAddress `
    -Name "kbudget-dev-appgw-pip" `
    -ResourceGroupName "kbudget-dev-rg"

Write-Host "IP Address: $($pip.IpAddress)"
Write-Host "FQDN: $($pip.DnsSettings.Fqdn)"
```

### View Backend Settings

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$appGw.BackendHttpSettingsCollection | Format-List
```

### View Routing Rules

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$appGw.RequestRoutingRules | Format-List
```

### Test Backend Connectivity

```powershell
# Test from PowerShell
Invoke-WebRequest -Uri "https://kbudget-dev-app.azurewebsites.net" -UseBasicParsing

# Test specific path
Invoke-WebRequest -Uri "https://kbudget-dev-app.azurewebsites.net/health" -UseBasicParsing
```

### View Deployment History

```powershell
Get-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" |
    Where-Object { $_.DeploymentName -like "appgw-*" } |
    Select-Object DeploymentName, ProvisioningState, Timestamp |
    Sort-Object Timestamp -Descending
```

### Check Resource Locks

```powershell
Get-AzResourceLock -ResourceGroupName "kbudget-dev-rg" |
    Where-Object { $_.ResourceName -like "*appgw*" }
```

## Log Queries

### Recent Blocked Requests

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, Message
| order by TimeGenerated desc
| take 50
```

### Top Blocked IPs

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize Count = count() by clientIp_s
| order by Count desc
| take 10
```

### Top Triggered Rules

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize Count = count() by ruleId_s, Message
| order by Count desc
| take 20
```

### Failed Requests (4xx, 5xx)

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayAccessLog"
| where httpStatus_d >= 400
| project TimeGenerated, clientIP_s, requestUri_s, httpStatus_d, timeTaken_d
| order by TimeGenerated desc
| take 50
```

### Slow Requests

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayAccessLog"
| where timeTaken_d > 1000  // Over 1 second
| project TimeGenerated, requestUri_s, timeTaken_d, httpStatus_d
| order by timeTaken_d desc
| take 20
```

### Request Volume by Hour

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayAccessLog"
| summarize Requests = count() by bin(TimeGenerated, 1h)
| render timechart
```

### Backend Health Over Time

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayPerformanceLog"
| summarize HealthyHosts = avg(healthyHostCount_d), UnhealthyHosts = avg(unhealthyHostCount_d) by bin(TimeGenerated, 5m)
| render timechart
```

## Common Scenarios

### Scenario: Deploy to New Environment

```powershell
# 1. Ensure prerequisites
Get-AzResourceGroup -Name "kbudget-dev-rg"
Get-AzVirtualNetwork -Name "kbudget-dev-vnet" -ResourceGroupName "kbudget-dev-rg"
Get-AzWebApp -Name "kbudget-dev-app" -ResourceGroupName "kbudget-dev-rg"

# 2. Deploy Application Gateway
.\Deploy-ApplicationGateway.ps1 -Environment dev

# 3. Test connectivity
Invoke-WebRequest -Uri "http://kbudget-dev-appgw.eastus.cloudapp.azure.com"

# 4. Test WAF
.\Test-WAF.ps1 -ApplicationGatewayUrl "http://kbudget-dev-appgw.eastus.cloudapp.azure.com"

# 5. Check backend health
Get-AzApplicationGatewayBackendHealth -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-appgw"
```

### Scenario: Update to Prevention Mode

```powershell
# 1. Get WAF policy
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-prod-appgw-waf-policy" `
    -ResourceGroupName "kbudget-prod-rg"

# 2. Review recent logs (ensure no false positives)
# Run Log Analytics queries to check blocked requests

# 3. Switch to Prevention mode
$wafPolicy.PolicySettings.Mode = "Prevention"
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy

# 4. Monitor for issues
# Watch logs for legitimate blocked requests
```

### Scenario: Add SSL Certificate

```powershell
# 1. Get Application Gateway
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-prod-appgw" `
    -ResourceGroupName "kbudget-prod-rg"

# 2. Add certificate
$password = ConvertTo-SecureString "Password" -AsPlainText -Force
Add-AzApplicationGatewaySslCertificate `
    -ApplicationGateway $appGw `
    -Name "prodCertificate" `
    -CertificateFile ".\prod-cert.pfx" `
    -Password $password

# 3. Update HTTPS listener
$listener = Get-AzApplicationGatewayHttpListener `
    -ApplicationGateway $appGw `
    -Name "appGatewayHttpsListener"

$cert = Get-AzApplicationGatewaySslCertificate `
    -ApplicationGateway $appGw `
    -Name "prodCertificate"

Set-AzApplicationGatewayHttpListener `
    -ApplicationGateway $appGw `
    -Name "appGatewayHttpsListener" `
    -Protocol Https `
    -FrontendIPConfiguration $listener.FrontendIPConfiguration `
    -FrontendPort $listener.FrontendPort `
    -SslCertificate $cert

# 4. Apply changes
Set-AzApplicationGateway -ApplicationGateway $appGw
```

### Scenario: Troubleshoot 502 Errors

```powershell
# 1. Check backend health
Get-AzApplicationGatewayBackendHealth `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-appgw"

# 2. Test backend directly
Invoke-WebRequest -Uri "https://kbudget-dev-app.azurewebsites.net"

# 3. Check health probe logs
# Run Log Analytics query for ApplicationGatewayPerformanceLog

# 4. Verify backend settings
$appGw = Get-AzApplicationGateway -Name "kbudget-dev-appgw" -ResourceGroupName "kbudget-dev-rg"
$appGw.BackendHttpSettingsCollection | Format-List

# 5. Increase timeout if needed
$backendSettings = Get-AzApplicationGatewayBackendHttpSetting `
    -ApplicationGateway $appGw `
    -Name "appGatewayBackendHttpSettings"
$backendSettings.RequestTimeout = 60
Set-AzApplicationGateway -ApplicationGateway $appGw
```

## Resource Links

- **Main Documentation**: [README.md](./README.md)
- **WAF Guide**: [WAF-CONFIGURATION-GUIDE.md](./WAF-CONFIGURATION-GUIDE.md)
- **Integration Guide**: [INTEGRATION-GUIDE.md](./INTEGRATION-GUIDE.md)
- **Azure Docs**: https://docs.microsoft.com/azure/application-gateway/
- **PowerShell Reference**: https://docs.microsoft.com/powershell/module/az.network/

## Support

For issues or questions:
1. Check troubleshooting section in [README.md](./README.md)
2. Review Azure Application Gateway documentation
3. Check deployment logs in `logs/` directory
4. Review Azure Monitor logs
5. Contact Azure Support if needed
