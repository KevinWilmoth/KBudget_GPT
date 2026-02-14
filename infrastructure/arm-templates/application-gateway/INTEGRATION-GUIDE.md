# Integration Guide

This guide explains how to integrate Azure Application Gateway with backend App Services, configure health probes, and manage routing rules.

## Table of Contents

- [Backend Integration](#backend-integration)
- [Health Probes](#health-probes)
- [Routing Rules](#routing-rules)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Custom Domains](#custom-domains)
- [Network Integration](#network-integration)
- [Troubleshooting](#troubleshooting)

## Backend Integration

### App Service Backend Pool

The Application Gateway is configured to use App Service as the backend. This provides:

- **Automatic scaling**: App Service can scale independently
- **Zero-downtime deployments**: Deploy to App Service without affecting Application Gateway
- **Multiple backends**: Support for multiple App Service instances
- **Health monitoring**: Automatic health checks

### Backend Pool Configuration

The backend pool is configured with:

```json
{
  "backendAddresses": [
    {
      "fqdn": "kbudget-dev-app.azurewebsites.net"
    }
  ]
}
```

### Adding Additional Backend Instances

To add more backend instances (e.g., for load balancing):

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$backendPool = Get-AzApplicationGatewayBackendAddressPool `
    -ApplicationGateway $appGw `
    -Name "appGatewayBackendPool"

# Add another App Service instance
Add-AzApplicationGatewayBackendAddressPool `
    -ApplicationGateway $appGw `
    -BackendAddresses @(
        @{Fqdn = "kbudget-dev-app.azurewebsites.net"},
        @{Fqdn = "kbudget-dev-app-secondary.azurewebsites.net"}
    )

Set-AzApplicationGateway -ApplicationGateway $appGw
```

### Backend HTTP Settings

Backend HTTP settings define how Application Gateway communicates with backends:

- **Protocol**: HTTPS (recommended for App Service)
- **Port**: 443
- **Cookie-based affinity**: Disabled (stateless applications)
- **Request timeout**: 30 seconds
- **Host name**: Picked from backend address or custom

```json
{
  "port": 443,
  "protocol": "Https",
  "cookieBasedAffinity": "Disabled",
  "pickHostNameFromBackendAddress": false,
  "hostName": "kbudget-dev-app.azurewebsites.net",
  "requestTimeout": 30
}
```

### Updating Backend Settings

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$backendSettings = Get-AzApplicationGatewayBackendHttpSetting `
    -ApplicationGateway $appGw `
    -Name "appGatewayBackendHttpSettings"

# Update timeout
$backendSettings.RequestTimeout = 60

Set-AzApplicationGateway -ApplicationGateway $appGw
```

## Health Probes

Health probes monitor backend health and automatically remove unhealthy instances from rotation.

### Default Health Probe Configuration

```json
{
  "protocol": "Https",
  "path": "/",
  "interval": 30,
  "timeout": 30,
  "unhealthyThreshold": 3,
  "pickHostNameFromBackendHttpSettings": false,
  "host": "kbudget-dev-app.azurewebsites.net",
  "match": {
    "statusCodes": ["200-399"]
  }
}
```

### Health Probe Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Protocol | HTTPS | Protocol for health checks |
| Path | / | URL path to check |
| Interval | 30 seconds | Time between checks |
| Timeout | 30 seconds | Max time to wait for response |
| Unhealthy Threshold | 3 | Failed checks before marking unhealthy |
| Status Codes | 200-399 | Acceptable HTTP status codes |

### Creating Custom Health Endpoint

Best practice: Create dedicated health check endpoint in your application.

**Example ASP.NET Core health endpoint**:

```csharp
// Program.cs or Startup.cs
app.MapHealthChecks("/health");
```

**Update health probe to use custom endpoint**:

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

$probe = Get-AzApplicationGatewayProbeConfig `
    -ApplicationGateway $appGw `
    -Name "appGatewayHealthProbe"

# Update probe path
$probe.Path = "/health"

Set-AzApplicationGateway -ApplicationGateway $appGw
```

### Advanced Health Checks

For more sophisticated health checks, implement custom logic:

```csharp
// ASP.NET Core example
public class DatabaseHealthCheck : IHealthCheck
{
    private readonly DbContext _context;
    
    public DatabaseHealthCheck(DbContext context)
    {
        _context = context;
    }
    
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await _context.Database.CanConnectAsync(cancellationToken);
            return HealthCheckResult.Healthy("Database is reachable");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy(
                "Database is unreachable", ex);
        }
    }
}

// Register in Startup
services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("database");
```

### Monitoring Health Status

Check backend health status:

```powershell
# Get health status
$health = Get-AzApplicationGatewayBackendHealth `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-appgw"

# Display health for each backend
foreach ($pool in $health.BackendAddressPools) {
    Write-Host "Backend Pool: $($pool.BackendAddressPool.Id)"
    
    foreach ($server in $pool.BackendHttpSettingsCollection.Servers) {
        Write-Host "  Server: $($server.Address)"
        Write-Host "  Health: $($server.Health)"
        Write-Host "  Status: $($server.HealthProbeLog)"
    }
}
```

### Health Probe Troubleshooting

Common issues and solutions:

#### Issue: Backend Always Unhealthy

**Possible causes**:
1. Health probe path doesn't exist (404 response)
2. App Service is not running
3. SSL/TLS certificate issues
4. Network connectivity problems
5. Host header mismatch

**Solutions**:
```powershell
# Verify probe configuration
$probe = Get-AzApplicationGatewayProbeConfig -ApplicationGateway $appGw -Name "appGatewayHealthProbe"
$probe | Format-List

# Test endpoint manually
Invoke-WebRequest -Uri "https://kbudget-dev-app.azurewebsites.net/health"

# Check App Service status
Get-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app" | Select-Object State
```

## Routing Rules

Routing rules determine how traffic is distributed based on listeners and backend pools.

### Basic Routing Rule

The template configures two basic routing rules:

1. **HTTP Rule**: Routes HTTP traffic (port 80)
2. **HTTPS Rule**: Routes HTTPS traffic (port 443)

```json
{
  "name": "httpsRoutingRule",
  "properties": {
    "ruleType": "Basic",
    "priority": 200,
    "httpListener": { "id": "..." },
    "backendAddressPool": { "id": "..." },
    "backendHttpSettings": { "id": "..." }
  }
}
```

### Path-Based Routing

Route different URL paths to different backends:

```powershell
# Create path map
$pathMap = New-AzApplicationGatewayPathRuleConfig `
    -Name "apiPathRule" `
    -Paths "/api/*" `
    -BackendAddressPool $apiBackendPool `
    -BackendHttpSettings $apiHttpSettings

$urlPathMap = New-AzApplicationGatewayUrlPathMapConfig `
    -Name "urlPathMap" `
    -PathRules $pathMap `
    -DefaultBackendAddressPool $defaultBackendPool `
    -DefaultBackendHttpSettings $defaultHttpSettings

# Create rule with path-based routing
$rule = New-AzApplicationGatewayRequestRoutingRule `
    -Name "pathBasedRoutingRule" `
    -RuleType PathBasedRouting `
    -Priority 100 `
    -HttpListener $listener `
    -UrlPathMap $urlPathMap

# Add to Application Gateway
$appGw.RequestRoutingRules.Add($rule)
Set-AzApplicationGateway -ApplicationGateway $appGw
```

### Redirect Rules

Redirect HTTP to HTTPS:

```powershell
# Create redirect configuration
$redirectConfig = New-AzApplicationGatewayRedirectConfiguration `
    -Name "httpToHttpsRedirect" `
    -RedirectType Permanent `
    -TargetListener $httpsListener `
    -IncludePath $true `
    -IncludeQueryString $true

# Update HTTP routing rule
$httpRule.RedirectConfiguration = $redirectConfig
$httpRule.BackendAddressPool = $null
$httpRule.BackendHttpSettings = $null

Set-AzApplicationGateway -ApplicationGateway $appGw
```

### Multi-Site Routing

Host multiple websites on one Application Gateway:

```powershell
# Create listeners for different hosts
$listener1 = New-AzApplicationGatewayHttpListener `
    -Name "site1Listener" `
    -Protocol Https `
    -FrontendIPConfiguration $frontendIP `
    -FrontendPort $httpsPort `
    -SslCertificate $cert1 `
    -HostName "site1.example.com"

$listener2 = New-AzApplicationGatewayHttpListener `
    -Name "site2Listener" `
    -Protocol Https `
    -FrontendIPConfiguration $frontendIP `
    -FrontendPort $httpsPort `
    -SslCertificate $cert2 `
    -HostName "site2.example.com"

# Create rules for each site
$rule1 = New-AzApplicationGatewayRequestRoutingRule `
    -Name "site1Rule" `
    -RuleType Basic `
    -Priority 100 `
    -HttpListener $listener1 `
    -BackendAddressPool $backend1 `
    -BackendHttpSettings $settings1

$rule2 = New-AzApplicationGatewayRequestRoutingRule `
    -Name "site2Rule" `
    -RuleType Basic `
    -Priority 200 `
    -HttpListener $listener2 `
    -BackendAddressPool $backend2 `
    -BackendHttpSettings $settings2
```

## SSL/TLS Configuration

### End-to-End SSL

Application Gateway supports end-to-end SSL encryption:

1. **Client → Application Gateway**: SSL termination at gateway
2. **Application Gateway → Backend**: Re-encrypted SSL connection

This is the default configuration in the template.

### Backend SSL Certificate Validation

For production, you should validate backend SSL certificates:

```powershell
# Get backend settings
$backendSettings = Get-AzApplicationGatewayBackendHttpSetting `
    -ApplicationGateway $appGw `
    -Name "appGatewayBackendHttpSettings"

# Add trusted root certificate
$cert = New-AzApplicationGatewayTrustedRootCertificate `
    -Name "backendCert" `
    -CertificateFile ".\backend-cert.cer"

Add-AzApplicationGatewayTrustedRootCertificate `
    -ApplicationGateway $appGw `
    -TrustedRootCertificate $cert

# Update backend settings to use certificate
$backendSettings.TrustedRootCertificates = @($cert)

Set-AzApplicationGateway -ApplicationGateway $appGw
```

### SSL Policy Configuration

Configure minimum TLS version and cipher suites:

```powershell
# Set custom SSL policy
$policy = New-AzApplicationGatewaySslPolicy `
    -PolicyType Custom `
    -MinProtocolVersion TLSv1_2 `
    -CipherSuite @(
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
    )

Set-AzApplicationGatewaySslPolicy `
    -ApplicationGateway $appGw `
    -Policy $policy

Set-AzApplicationGateway -ApplicationGateway $appGw
```

## Custom Domains

### Configuring Custom Domain

1. **Add custom domain to App Service**:

```powershell
# Add custom domain to App Service
Set-AzWebApp `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-app" `
    -HostNames @("kbudget.example.com", "kbudget-dev-app.azurewebsites.net")
```

2. **Update DNS**:

Create DNS record pointing to Application Gateway public IP:

```
kbudget.example.com  A  <Application-Gateway-Public-IP>
```

3. **Configure SSL certificate** for custom domain (see README.md)

4. **Update listener** to use custom hostname:

```powershell
$listener = Get-AzApplicationGatewayHttpListener `
    -ApplicationGateway $appGw `
    -Name "appGatewayHttpsListener"

$listener.HostName = "kbudget.example.com"

Set-AzApplicationGateway -ApplicationGateway $appGw
```

## Network Integration

### Virtual Network Configuration

Application Gateway requires a dedicated subnet:

- **Minimum size**: /24 (256 addresses recommended)
- **Dedicated**: No other resources in subnet
- **Service endpoints**: Microsoft.Web, Microsoft.Storage, Microsoft.KeyVault

### Network Security Groups

If using NSG on Application Gateway subnet:

**Inbound rules required**:
```
Priority: 100
Source: Internet
Source Port: *
Destination: *
Destination Port: 80, 443
Protocol: TCP
Action: Allow

Priority: 110
Source: GatewayManager
Source Port: *
Destination: *
Destination Port: 65200-65535
Protocol: TCP
Action: Allow
```

**Outbound rules required**:
```
Priority: 100
Source: *
Destination: Internet
Destination Port: *
Protocol: *
Action: Allow
```

### App Service Access Restriction

Restrict App Service to only accept traffic from Application Gateway:

```powershell
# Get Application Gateway subnet
$vnet = Get-AzVirtualNetwork -Name "kbudget-dev-vnet" -ResourceGroupName "kbudget-dev-rg"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "frontend-subnet" -VirtualNetwork $vnet

# Add access restriction to App Service
Add-AzWebAppAccessRestrictionRule `
    -ResourceGroupName "kbudget-dev-rg" `
    -WebAppName "kbudget-dev-app" `
    -Name "AllowFromAppGateway" `
    -Priority 100 `
    -Action Allow `
    -VirtualNetworkResourceId $subnet.Id
```

## Troubleshooting

### Common Integration Issues

#### Issue: 502 Bad Gateway

**Symptoms**: Application Gateway returns 502 error

**Possible causes**:
1. Backend is unhealthy or not responding
2. Backend SSL certificate issues
3. Timeout waiting for backend response
4. Backend returns invalid response

**Solutions**:
```powershell
# Check backend health
Get-AzApplicationGatewayBackendHealth `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-appgw"

# Increase timeout
$backendSettings.RequestTimeout = 60

# Check backend directly
Invoke-WebRequest -Uri "https://kbudget-dev-app.azurewebsites.net"
```

#### Issue: SSL Handshake Failures

**Symptoms**: HTTPS requests fail, SSL errors in logs

**Solutions**:
1. Verify backend certificate is valid
2. Check SSL policy configuration
3. Ensure backend supports required TLS version
4. Add backend certificate to trusted root certificates

#### Issue: Inconsistent Routing

**Symptoms**: Requests sometimes work, sometimes fail

**Solutions**:
1. Check cookie-based affinity settings
2. Verify all backend instances are healthy
3. Review routing rules for conflicts
4. Check for intermittent network issues

### Diagnostic Logging

Enable diagnostic logging for troubleshooting:

```powershell
# Create Log Analytics workspace
$workspace = New-AzOperationalInsightsWorkspace `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-logs" `
    -Location "eastus"

# Enable diagnostics
Set-AzDiagnosticSetting `
    -ResourceId "/subscriptions/.../applicationGateways/kbudget-dev-appgw" `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category @(
        "ApplicationGatewayAccessLog",
        "ApplicationGatewayPerformanceLog",
        "ApplicationGatewayFirewallLog"
    )
```

### Log Analysis Queries

```kusto
// Access log - failed requests
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayAccessLog"
| where httpStatus_d >= 400
| project TimeGenerated, clientIP_s, requestUri_s, httpStatus_d, backendSettingName_s
| order by TimeGenerated desc

// Performance log - slow requests
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayPerformanceLog"
| where timeTaken_d > 1000  // Over 1 second
| project TimeGenerated, instanceId_s, timeTaken_d
| order by timeTaken_d desc
```

## Best Practices

1. **Use HTTPS end-to-end**: Encrypt traffic from client to backend
2. **Implement custom health endpoints**: Don't rely on homepage for health checks
3. **Set appropriate timeouts**: Match backend processing time
4. **Restrict backend access**: Only allow traffic from Application Gateway
5. **Monitor health probes**: Set up alerts for unhealthy backends
6. **Use path-based routing**: Separate API and web traffic
7. **Enable diagnostic logging**: Send logs to Log Analytics
8. **Regular certificate rotation**: Update SSL certificates before expiration
9. **Test failover**: Verify behavior when backends are unhealthy
10. **Document configurations**: Keep record of custom settings

## Additional Resources

- [Main README](./README.md)
- [WAF Configuration Guide](./WAF-CONFIGURATION-GUIDE.md)
- [Quick Reference](./QUICK-REFERENCE.md)
- [Azure Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/)
