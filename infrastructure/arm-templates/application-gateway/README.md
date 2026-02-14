# Application Gateway with WAF

This directory contains ARM templates and PowerShell scripts for deploying Azure Application Gateway with Web Application Firewall (WAF) for the KBudget GPT application.

## Table of Contents

- [Overview](#overview)
- [Resources Created](#resources-created)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Parameters](#parameters)
- [Deployment](#deployment)
- [SSL Certificate Configuration](#ssl-certificate-configuration)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## Overview

The Application Gateway provides:

- **Web Application Firewall (WAF)**: Protection against common web vulnerabilities (OWASP Top 10)
- **Load Balancing**: Distributes traffic to backend App Service instances
- **SSL/TLS Termination**: Handles HTTPS traffic with certificate management
- **Health Monitoring**: Automatic health probes for backend services
- **Layer 7 Routing**: Advanced HTTP/HTTPS request routing capabilities

### WAF Protection

The WAF is configured with:
- **OWASP Core Rule Set 3.2**: Industry-standard protection against web attacks
- **Detection/Prevention Mode**: Configurable based on environment
- **Custom Rules**: Support for additional custom WAF rules
- **Request/Response Inspection**: Deep packet inspection for threats

## Resources Created

The deployment creates the following Azure resources:

1. **Application Gateway** (WAF_v2 SKU)
   - Frontend IP configuration (public)
   - HTTP and HTTPS listeners
   - Backend pool pointing to App Service
   - Health probes for backend monitoring
   - Routing rules for traffic distribution

2. **Public IP Address** (Standard SKU)
   - Static allocation
   - DNS name label for easy access

3. **WAF Policy**
   - OWASP rule set configuration
   - Custom rule support
   - Policy settings (mode, thresholds)

## Prerequisites

Before deploying the Application Gateway, ensure you have:

### Azure Resources
- **Resource Group**: Must exist (e.g., `kbudget-dev-rg`)
- **Virtual Network**: Must exist with a dedicated subnet for Application Gateway
  - Subnet must be at least /24 (256 IP addresses)
  - Subnet should be named `frontend-subnet`
  - No other resources should be deployed in this subnet
- **App Service**: Backend application must be deployed and running

### Local Requirements
- **Azure PowerShell Module**: Version 5.0.0 or later
  ```powershell
  Install-Module -Name Az -AllowClobber -Scope CurrentUser
  ```
- **Azure Authentication**: Authenticated session
  ```powershell
  Connect-AzAccount
  ```
- **Permissions**: Contributor or Owner role on the resource group
- **SSL Certificate** (Optional): PFX file with password for HTTPS

### Network Requirements
- Subnet must not have any Network Security Group (NSG) rules blocking Application Gateway management traffic
- Service endpoints should be configured on the subnet:
  - Microsoft.Web
  - Microsoft.Storage
  - Microsoft.KeyVault

## Quick Start

### 1. Deploy with Default Settings

Deploy Application Gateway to development environment:

```powershell
cd infrastructure/arm-templates/application-gateway
.\Deploy-ApplicationGateway.ps1 -Environment dev
```

### 2. Deploy with SSL Certificate

Deploy with custom SSL certificate:

```powershell
$certPassword = ConvertTo-SecureString "YourPassword" -AsPlainText -Force

.\Deploy-ApplicationGateway.ps1 `
    -Environment dev `
    -SslCertificatePath ".\mycert.pfx" `
    -SslCertificatePassword $certPassword
```

### 3. Test WAF Protection

After deployment, test WAF functionality:

```powershell
.\Test-WAF.ps1 -ApplicationGatewayUrl "https://kbudget-dev-appgw.eastus.cloudapp.azure.com"
```

## Parameters

### Environment-Specific Parameters

The deployment script supports three environments, each with optimized settings:

#### Development (`dev`)
- **Capacity**: 1 instance
- **WAF Mode**: Detection (logs threats, doesn't block)
- **Purpose**: Testing and development

#### Staging (`staging`)
- **Capacity**: 2 instances
- **WAF Mode**: Detection
- **Purpose**: Pre-production testing

#### Production (`prod`)
- **Capacity**: 2 instances (can be scaled up to 10)
- **WAF Mode**: Prevention (actively blocks threats)
- **Purpose**: Production workloads

### ARM Template Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| applicationGatewayName | string | - | Name of the Application Gateway |
| location | string | Resource Group location | Azure region |
| virtualNetworkName | string | - | Name of existing Virtual Network |
| subnetName | string | frontend-subnet | Subnet for Application Gateway |
| publicIpName | string | - | Name for public IP address |
| skuName | string | WAF_v2 | SKU (WAF_v2 only) |
| capacity | int | 2 | Number of instances (1-10) |
| backendAppServiceFqdn | string | - | FQDN of backend App Service |
| backendAppServiceHostName | string | - | Host name for backend |
| sslCertificateData | securestring | "" | Base64-encoded PFX certificate |
| sslCertificatePassword | securestring | "" | Certificate password |
| wafMode | string | Detection | Detection or Prevention |
| wafRuleSetType | string | OWASP | Rule set type |
| wafRuleSetVersion | string | 3.2 | OWASP version (3.0, 3.1, 3.2) |
| enableHttp2 | bool | true | Enable HTTP/2 support |
| tags | object | {} | Resource tags |

## Deployment

### Using PowerShell Script (Recommended)

The PowerShell deployment script provides validation and error handling:

```powershell
# Development environment
.\Deploy-ApplicationGateway.ps1 -Environment dev

# Staging environment
.\Deploy-ApplicationGateway.ps1 -Environment staging

# Production environment
.\Deploy-ApplicationGateway.ps1 -Environment prod

# With custom location
.\Deploy-ApplicationGateway.ps1 -Environment dev -Location westus2

# WhatIf mode (preview changes)
.\Deploy-ApplicationGateway.ps1 -Environment dev -WhatIf
```

### Using Azure CLI

Deploy directly with Azure CLI:

```bash
az deployment group create \
  --name appgw-deployment \
  --resource-group kbudget-dev-rg \
  --template-file application-gateway.json \
  --parameters @parameters.dev.json
```

### Using Azure Portal

1. Navigate to Azure Portal > Resource Groups
2. Select your resource group (e.g., `kbudget-dev-rg`)
3. Click **Create** > **Template deployment**
4. Click **Build your own template in the editor**
5. Upload `application-gateway.json`
6. Fill in parameters or upload parameter file
7. Review and create

## SSL Certificate Configuration

### Generating Self-Signed Certificate (Development Only)

For development environments, you can create a self-signed certificate:

```powershell
# Create self-signed certificate
$cert = New-SelfSignedCertificate `
    -DnsName "kbudget-dev.example.com" `
    -CertStoreLocation "cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -NotAfter (Get-Date).AddYears(1)

# Export to PFX file
$password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
Export-PfxCertificate `
    -Cert $cert `
    -FilePath ".\kbudget-dev.pfx" `
    -Password $password
```

**Warning**: Self-signed certificates should NEVER be used in production.

### Using Production Certificate

For production, obtain a certificate from a trusted Certificate Authority (CA):

1. **Purchase/Obtain Certificate**: Get a certificate from a trusted CA (e.g., DigiCert, Let's Encrypt)
2. **Export as PFX**: Ensure the certificate is in PFX format with private key
3. **Store Securely**: Keep certificate and password in Azure Key Vault

### Deploying with Certificate

```powershell
# Read certificate password from Key Vault
$secretValue = Get-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AppGatewaySslCertPassword" `
    -AsPlainText

$password = ConvertTo-SecureString $secretValue -AsPlainText -Force

# Deploy with certificate
.\Deploy-ApplicationGateway.ps1 `
    -Environment dev `
    -SslCertificatePath ".\production-cert.pfx" `
    -SslCertificatePassword $password
```

### Updating Certificate Post-Deployment

To update the certificate after deployment:

```powershell
# Get Application Gateway
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

# Add/Update certificate
$password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
Set-AzApplicationGatewaySslCertificate `
    -ApplicationGateway $appGw `
    -Name "appGatewaySslCertificate" `
    -CertificateFile ".\new-cert.pfx" `
    -Password $password

# Update Application Gateway
Set-AzApplicationGateway -ApplicationGateway $appGw
```

## Testing

### WAF Detection Tests

Run the WAF test script to validate protection:

```powershell
# Basic test
.\Test-WAF.ps1 -ApplicationGatewayUrl "https://kbudget-dev-appgw.eastus.cloudapp.azure.com"

# Skip SSL validation (for self-signed certificates)
.\Test-WAF.ps1 `
    -ApplicationGatewayUrl "https://kbudget-dev-appgw.eastus.cloudapp.azure.com" `
    -SkipSslValidation
```

The test script validates:
- **Basic Connectivity**: Ensures Application Gateway is accessible
- **SQL Injection Detection**: Tests WAF blocking of SQL injection attempts
- **Cross-Site Scripting (XSS)**: Tests WAF blocking of XSS payloads
- **Path Traversal**: Tests WAF blocking of directory traversal attempts
- **SSL/TLS Configuration**: Validates secure protocols are in use

### Health Probe Validation

Check health probe status:

```powershell
$appGw = Get-AzApplicationGateway `
    -Name "kbudget-dev-appgw" `
    -ResourceGroupName "kbudget-dev-rg"

# Check backend health
Get-AzApplicationGatewayBackendHealth `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-appgw"
```

### Manual Testing

Test endpoints manually:

```powershell
# Test HTTP endpoint
Invoke-WebRequest -Uri "http://kbudget-dev-appgw.eastus.cloudapp.azure.com"

# Test HTTPS endpoint
Invoke-WebRequest -Uri "https://kbudget-dev-appgw.eastus.cloudapp.azure.com"

# Test with malicious payload (should be blocked)
Invoke-WebRequest -Uri "http://kbudget-dev-appgw.eastus.cloudapp.azure.com/?id=' OR '1'='1"
```

## Monitoring

### Azure Portal

1. Navigate to Application Gateway resource
2. **Metrics** tab shows:
   - Throughput
   - Response time
   - Failed requests
   - Healthy/Unhealthy host count

3. **Backend health** tab shows:
   - Backend pool health status
   - Individual backend server status

### WAF Logs

View WAF logs in Log Analytics:

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| project TimeGenerated, requestUri_s, Message, ruleId_s
| order by TimeGenerated desc
```

### Alerts

Configure alerts for:
- High number of blocked requests
- Backend health issues
- High response time
- Failed requests

## Troubleshooting

### Common Issues

#### Backend Pool Unhealthy

**Symptoms**: Backend health shows unhealthy status

**Solutions**:
1. Verify App Service is running and accessible
2. Check health probe configuration matches App Service endpoint
3. Verify App Service allows traffic from Application Gateway subnet
4. Check NSG rules on App Service subnet

```powershell
# Check backend health
Get-AzApplicationGatewayBackendHealth `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-appgw"

# Check App Service
Get-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"
```

#### SSL Certificate Issues

**Symptoms**: HTTPS listener not working, certificate errors

**Solutions**:
1. Verify certificate is valid and not expired
2. Ensure certificate includes private key (PFX format)
3. Verify password is correct
4. Check certificate CN/SAN matches domain name

```powershell
# View certificate details
$appGw = Get-AzApplicationGateway -Name "kbudget-dev-appgw" -ResourceGroupName "kbudget-dev-rg"
$appGw.SslCertificates
```

#### WAF Blocking Legitimate Traffic

**Symptoms**: Valid requests being blocked by WAF

**Solutions**:
1. Review WAF logs to identify triggering rule
2. Create WAF exclusion rule
3. Adjust WAF mode from Prevention to Detection (for testing)
4. Update application to avoid triggering rules

```powershell
# Switch to Detection mode
$appGw = Get-AzApplicationGateway -Name "kbudget-dev-appgw" -ResourceGroupName "kbudget-dev-rg"
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy -Name "kbudget-dev-appgw-waf-policy" -ResourceGroupName "kbudget-dev-rg"
$wafPolicy.PolicySettings.Mode = "Detection"
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

#### Deployment Failures

**Symptoms**: ARM template deployment fails

**Solutions**:
1. Verify all prerequisites are met (VNet, subnet, App Service)
2. Check subnet size (must be at least /24)
3. Ensure no other resources in Application Gateway subnet
4. Verify resource naming follows Azure conventions
5. Check deployment logs for specific errors

```powershell
# View deployment logs
Get-AzResourceGroupDeploymentOperation `
    -ResourceGroupName "kbudget-dev-rg" `
    -DeploymentName "appgw-deployment-TIMESTAMP" `
    | Select-Object -Property * -ExpandProperty Properties
```

### Support Resources

- [Azure Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/)
- [WAF Configuration Guide](./WAF-CONFIGURATION-GUIDE.md)
- [Integration Guide](./INTEGRATION-GUIDE.md)
- [Azure Support](https://azure.microsoft.com/support/)

## Additional Documentation

- **[WAF-CONFIGURATION-GUIDE.md](./WAF-CONFIGURATION-GUIDE.md)** - Detailed WAF configuration and rule management
- **[INTEGRATION-GUIDE.md](./INTEGRATION-GUIDE.md)** - Backend integration and health probe configuration
- **[QUICK-REFERENCE.md](./QUICK-REFERENCE.md)** - Quick reference for common tasks

## Security Best Practices

1. **Always use HTTPS**: Configure SSL certificates for production
2. **Use Prevention mode in production**: Enable WAF Prevention mode
3. **Regular certificate rotation**: Update certificates before expiration
4. **Monitor WAF logs**: Review blocked requests regularly
5. **Keep rule sets updated**: Use latest OWASP rule set version
6. **Restrict backend access**: Configure NSGs to only allow traffic from Application Gateway
7. **Enable diagnostic logging**: Send logs to Log Analytics for analysis
8. **Use managed identities**: Avoid storing credentials in templates
9. **Implement custom WAF rules**: Add application-specific protection
10. **Regular security reviews**: Conduct periodic reviews of WAF configuration

## Cost Optimization

- **Development**: Use 1 instance, Detection mode
- **Staging**: Use 2 instances for redundancy testing
- **Production**: Use 2+ instances, enable autoscaling
- **Stop/Deallocate**: Stop Application Gateway when not needed (dev/staging)
- **Right-sizing**: Monitor utilization and adjust capacity

## Next Steps

After deploying Application Gateway:

1. Configure custom domain DNS to point to Application Gateway public IP
2. Upload production SSL certificate
3. Test WAF protection using Test-WAF.ps1
4. Configure monitoring and alerts
5. Review and tune WAF rules based on traffic patterns
6. Integrate with Azure Front Door for global distribution (optional)
7. Configure custom error pages
8. Set up diagnostic settings for logging

## License

This infrastructure code is part of the KBudget GPT project.
