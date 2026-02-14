# Application Gateway with Web Application Firewall (WAF)

This directory contains ARM templates for deploying Azure Application Gateway v2 with integrated Web Application Firewall (WAF) to provide secure, scalable, and highly available application delivery.

## ⚠️ Important: SSL/TLS Configuration

**Note**: The initial template deploys Application Gateway with HTTP listeners only (no SSL certificates). For production use:
1. Deploy the template as-is first
2. Add SSL certificates (see [Adding SSL Certificate](#adding-ssl-certificate) section)
3. Update the HTTPS listener to use protocol "Https" instead of "Http"

This approach allows initial deployment without requiring SSL certificates upfront.

## Overview

The Application Gateway provides:
- **Layer 7 load balancing** - HTTP/HTTPS traffic distribution
- **Web Application Firewall (WAF)** - Protection against web vulnerabilities and attacks
- **SSL/TLS termination** - Centralized SSL certificate management (requires post-deployment configuration)
- **Auto-scaling** - Automatic scaling based on traffic patterns
- **HTTP to HTTPS redirect** - Automatic redirect for secure connections (after SSL certificate is added)
- **Health probes** - Continuous monitoring of backend health

## Resources Created

- **Application Gateway v2** - With WAF_v2 SKU
- **Public IP Address** - Standard SKU with static allocation
- **WAF Configuration** - OWASP 3.2 rule set
- **Backend Pool** - Configured to point to App Service
- **Health Probe** - Monitors backend application health
- **SSL Policy** - Custom policy with TLS 1.2 minimum

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| applicationGatewayName | string | - | Name of the Application Gateway |
| location | string | Resource Group location | Azure region |
| tier | string | WAF_v2 | Gateway tier (Standard_v2 or WAF_v2) |
| skuSize | string | WAF_v2 | SKU size |
| autoScaleMinCapacity | int | 2 | Minimum autoscale instances |
| autoScaleMaxCapacity | int | 10 | Maximum autoscale instances |
| vnetName | string | - | Virtual Network name |
| subnetName | string | appgw-subnet | Application Gateway subnet |
| publicIpName | string | - | Public IP address name |
| backendAppServiceFqdn | string | - | Backend App Service FQDN |
| wafMode | string | Prevention | WAF mode (Detection or Prevention) |
| wafRuleSetVersion | string | 3.2 | OWASP rule set version |
| enableHttp2 | bool | true | Enable HTTP/2 |
| minTlsVersion | string | TLS1_2 | Minimum TLS version |
| tags | object | {} | Resource tags |

## Environment-Specific Configurations

### Development
- **Autoscale**: 1-3 instances
- **WAF Mode**: Detection (logs attacks but doesn't block)
- **Purpose**: Testing and development

### Staging
- **Autoscale**: 2-5 instances
- **WAF Mode**: Prevention (blocks detected attacks)
- **Purpose**: Pre-production testing

### Production
- **Autoscale**: 2-10 instances
- **WAF Mode**: Prevention (blocks detected attacks)
- **Purpose**: Production workloads

## Prerequisites

Before deploying the Application Gateway:

1. **Virtual Network with Application Gateway Subnet**:
   ```powershell
   # The VNet must already exist with a dedicated subnet for Application Gateway
   # Subnet must have at least /26 CIDR or larger
   # Update virtual-network template to include appgw-subnet
   ```

2. **Backend App Service**:
   ```powershell
   # App Service must be deployed and accessible
   # Note the App Service FQDN (e.g., kbudget-dev-app.azurewebsites.net)
   ```

## Deployment

### Deploy Application Gateway

```powershell
# Deploy to development
New-AzResourceGroupDeployment `
    -Name "appgw-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "application-gateway.json" `
    -TemplateParameterFile "parameters.dev.json"

# Deploy to staging
New-AzResourceGroupDeployment `
    -Name "appgw-deployment" `
    -ResourceGroupName "kbudget-staging-rg" `
    -TemplateFile "application-gateway.json" `
    -TemplateParameterFile "parameters.staging.json"

# Deploy to production
New-AzResourceGroupDeployment `
    -Name "appgw-deployment" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "application-gateway.json" `
    -TemplateParameterFile "parameters.prod.json"
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| applicationGatewayId | string | Resource ID of the Application Gateway |
| applicationGatewayName | string | Name of the Application Gateway |
| publicIpAddress | string | Public IP address |
| publicIpFqdn | string | Fully qualified domain name |

## WAF Configuration

### OWASP Rule Set 3.2

The WAF is configured with OWASP Core Rule Set 3.2, which provides protection against:

- **SQL Injection** - Malicious SQL commands
- **Cross-Site Scripting (XSS)** - Script injection attacks
- **Remote File Inclusion** - Unauthorized file access
- **Command Injection** - OS command execution
- **Session Fixation** - Session hijacking
- **HTTP Protocol Violations** - Malformed requests
- **And many more OWASP Top 10 vulnerabilities**

### WAF Modes

**Detection Mode** (Development):
- Logs threats but doesn't block
- Useful for tuning and testing
- Review logs to identify false positives

**Prevention Mode** (Staging/Production):
- Actively blocks detected threats
- Provides real protection
- May require tuning to prevent false positives

### Custom WAF Rules

To add custom WAF rules:

```powershell
$appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"

# Add custom rule to block specific patterns
$customRule = New-AzApplicationGatewayFirewallCustomRule `
    -Name "BlockBadBot" `
    -Priority 10 `
    -RuleType MatchRule `
    -MatchCondition $matchCondition `
    -Action Block

# Update Application Gateway
Set-AzApplicationGateway -ApplicationGateway $appgw
```

## SSL/TLS Configuration

### Current Configuration
- **Minimum TLS Version**: 1.2
- **Cipher Suites**:
  - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
  - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

### Adding SSL Certificate

To enable HTTPS with a custom certificate:

```powershell
# Upload certificate to Application Gateway
$appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"

# Add SSL certificate
Add-AzApplicationGatewaySslCertificate `
    -ApplicationGateway $appgw `
    -Name "kbudget-ssl-cert" `
    -CertificateFile "path/to/certificate.pfx" `
    -Password (ConvertTo-SecureString "password" -AsPlainText -Force)

# Update listener to use HTTPS
$listener = Get-AzApplicationGatewayHttpListener -ApplicationGateway $appgw -Name "httpsListener"
$listener.Protocol = "Https"
$listener.SslCertificate = Get-AzApplicationGatewaySslCertificate -ApplicationGateway $appgw -Name "kbudget-ssl-cert"

# Apply changes
Set-AzApplicationGateway -ApplicationGateway $appgw
```

### Certificate from Key Vault

For production, use certificates stored in Key Vault:

```powershell
# Reference Key Vault certificate
$appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"

# Enable managed identity
$identity = New-AzUserAssignedIdentity -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-appgw-identity"
Set-AzApplicationGatewayIdentity -ApplicationGateway $appgw -UserAssignedIdentityId $identity.Id

# Add SSL certificate from Key Vault
Add-AzApplicationGatewaySslCertificate `
    -ApplicationGateway $appgw `
    -Name "kbudget-ssl-cert" `
    -KeyVaultSecretId "https://kbudget-prod-kv.vault.azure.net/secrets/ssl-cert"
```

## Health Probes

The template includes a health probe configured to:
- **Protocol**: HTTPS
- **Path**: /
- **Interval**: 30 seconds
- **Timeout**: 30 seconds
- **Unhealthy threshold**: 3 consecutive failures
- **Success codes**: 200-399

## Monitoring

### View WAF Logs

```powershell
# Enable diagnostic settings to send logs to Log Analytics
$appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "kbudget-prod-rg"

Set-AzDiagnosticSetting `
    -ResourceId $appgw.Id `
    -Name "appgw-diagnostics" `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category "ApplicationGatewayFirewallLog"
```

### Query WAF Blocked Requests

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS" 
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize count() by clientIP_s, Message, bin(TimeGenerated, 1h)
| order by count_ desc
```

### Application Gateway Metrics

Monitor these key metrics:
- **Healthy Host Count** - Number of healthy backend instances
- **Unhealthy Host Count** - Number of unhealthy instances
- **Request Count** - Total HTTP requests
- **Failed Requests** - Failed backend requests
- **Throughput** - Data transfer rate
- **Backend Response Time** - Application response latency

## Cost Optimization

### Application Gateway v2 Pricing

**Fixed Cost** (per deployment hour):
- ~$0.246/hour (~$177/month) for the gateway

**Capacity Units** (auto-scaled):
- ~$0.0144/hour per capacity unit
- Each capacity unit handles:
  - 50 persistent connections
  - 2,500 requests/sec throughput
  - 1 compute unit

**Data Processing**:
- ~$0.008/GB processed

**Example Monthly Costs**:
- **Development** (1-3 instances): $250-400/month
- **Staging** (2-5 instances): $400-600/month
- **Production** (2-10 instances): $400-1,200/month

### Cost Saving Tips

1. **Use appropriate autoscale settings** - Don't over-provision
2. **Disable during off-hours** (non-production only)
3. **Monitor capacity unit usage** - Optimize based on actual traffic
4. **Use HTTP/2** - More efficient connection handling

## Troubleshooting

### Backend Health Issues

```powershell
# Check backend health
$appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"
Get-AzApplicationGatewayBackendHealth -ApplicationGateway $appgw
```

### WAF False Positives

If legitimate traffic is being blocked:

1. **Review WAF logs** to identify the rule causing the block
2. **Disable specific rules** if needed:
   ```powershell
   $appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"
   $appgw.WebApplicationFirewallConfiguration.DisabledRuleGroups = @(
       @{RuleGroupName="REQUEST-942-APPLICATION-ATTACK-SQLI"; Rules=@(942100,942200)}
   )
   Set-AzApplicationGateway -ApplicationGateway $appgw
   ```
3. **Create exclusions** for specific parameters

### Connection Issues

```powershell
# Test connectivity to backend
Test-NetConnection -ComputerName "kbudget-prod-app.azurewebsites.net" -Port 443

# Check NSG rules on Application Gateway subnet
Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-prod-rg" | Get-AzNetworkSecurityRuleConfig
```

## Security Best Practices

✅ **Always use WAF in Prevention mode** in production  
✅ **Enable HTTP to HTTPS redirect** - Never serve over HTTP  
✅ **Use TLS 1.2 or higher** - Disable older protocols  
✅ **Monitor WAF logs regularly** - Detect attack patterns  
✅ **Keep rule sets updated** - Use latest OWASP version  
✅ **Use strong cipher suites** - Avoid weak encryption  
✅ **Enable diagnostic logging** - Send to Log Analytics  
✅ **Set up alerts** - For backend health and WAF blocks  
✅ **Regularly review disabled rules** - Minimize attack surface  
✅ **Use managed identities** - For Key Vault certificate access

## Integration with Other Services

### App Service Integration

The Application Gateway is configured to route traffic to App Service. Ensure:
- App Service allows traffic from Application Gateway subnet
- App Service is configured with the correct hostname
- App Service has proper health check endpoint

### DNS Configuration

After deployment, update DNS to point to the Application Gateway:
- **A Record**: Point to the Public IP address
- **CNAME**: Point to the Public IP FQDN

### Custom Domain

```powershell
# Get the public IP FQDN
$pip = Get-AzPublicIpAddress -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw-pip"
Write-Output $pip.DnsSettings.Fqdn

# Create DNS CNAME record pointing to this FQDN
# Example: kbudget.example.com -> kbudget-prod-appgw.eastus.cloudapp.azure.com
```

## Additional Resources

- [Azure Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/)
- [WAF Configuration](https://docs.microsoft.com/azure/web-application-firewall/)
- [OWASP Core Rule Set](https://owasp.org/www-project-modsecurity-core-rule-set/)
- [Application Gateway Best Practices](https://docs.microsoft.com/azure/application-gateway/best-practices)
