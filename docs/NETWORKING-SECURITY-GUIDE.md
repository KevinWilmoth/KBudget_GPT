# Networking and Security Configuration Guide

This guide provides a comprehensive overview of the networking and security configuration for the KBudget GPT application, including Azure Virtual Networks, Application Gateway with WAF, Network Security Groups, Key Vault security, and DNS management.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Network Architecture](#network-architecture)
3. [Security Components](#security-components)
4. [Deployment Guide](#deployment-guide)
5. [Security Best Practices](#security-best-practices)
6. [Monitoring and Compliance](#monitoring-and-compliance)
7. [Troubleshooting](#troubleshooting)

## Architecture Overview

The KBudget GPT application uses a defense-in-depth security approach with multiple layers:

```
Internet
    │
    ▼
[Azure DNS Zone]
    │
    ▼
[Application Gateway + WAF] ◄── Public IP
    │
    │ (WAF filters malicious traffic)
    │
    ▼
[Virtual Network - 10.x.0.0/16]
    │
    ├─ Application Gateway Subnet (10.x.4.0/24) [NSG]
    │  └─ Application Gateway instances
    │
    ├─ App Service Subnet (10.x.1.0/24) [NSG + Service Endpoints]
    │  ├─ App Service (VNet integrated)
    │  └─ Managed Identity → Key Vault
    │
    ├─ Functions Subnet (10.x.3.0/24) [NSG + Service Endpoints]
    │  ├─ Azure Functions (VNet integrated)
    │  └─ Managed Identity → Key Vault
    │
    └─ Database Subnet (10.x.2.0/24) [NSG + Service Endpoints]
       └─ SQL Database (VNet rules)

[Key Vault] ◄── VNet Service Endpoints + Network ACLs
    └─ Secrets, Keys, Certificates

[Storage Account] ◄── VNet Service Endpoints + Firewall
    └─ Application data
```

## Network Architecture

### Virtual Network (VNet)

**Purpose**: Provides network isolation and segmentation for Azure resources.

**Configuration**:
- **Address Space**: 
  - Dev: 10.0.0.0/16
  - Staging: 10.1.0.0/16
  - Production: 10.2.0.0/16
- **DDoS Protection**: 
  - Dev/Staging: Disabled (cost optimization)
  - Production: Enabled (recommended for critical workloads)

### Subnets

#### 1. Application Subnet (app-subnet)
- **Address Range**: 10.x.1.0/24 (254 addresses)
- **Purpose**: App Service VNet integration
- **Delegation**: Microsoft.Web/serverFarms
- **Service Endpoints**: Web, Storage, SQL, Key Vault
- **NSG Rules**:
  - Allow HTTPS (443) from Internet
  - Allow HTTP (80) from Internet (redirected to HTTPS)

#### 2. Database Subnet (db-subnet)
- **Address Range**: 10.x.2.0/24 (254 addresses)
- **Purpose**: SQL Database private access
- **Service Endpoints**: Microsoft.Sql
- **NSG Rules**:
  - Allow SQL (1433) from app-subnet only
  - Deny all other inbound traffic

#### 3. Functions Subnet (func-subnet)
- **Address Range**: 10.x.3.0/24 (254 addresses)
- **Purpose**: Azure Functions VNet integration
- **Delegation**: Microsoft.Web/serverFarms
- **Service Endpoints**: Web, Storage, SQL, Key Vault
- **NSG Rules**: Similar to app-subnet

#### 4. Application Gateway Subnet (appgw-subnet)
- **Address Range**: 10.x.4.0/24 (254 addresses)
- **Purpose**: Application Gateway deployment
- **NSG Rules**:
  - Allow GatewayManager (65200-65535) - Required for App Gateway management
  - Allow AzureLoadBalancer - Required for health probes
  - Allow HTTPS (443) from Internet
  - Allow HTTP (80) from Internet

### Network Security Groups (NSGs)

NSGs provide stateful packet filtering at the subnet level:

| NSG | Subnet | Key Rules |
|-----|--------|-----------|
| app-nsg | app-subnet | Allow 443, 80 inbound |
| db-nsg | db-subnet | Allow 1433 from app-subnet only |
| appgw-nsg | appgw-subnet | Allow GatewayManager, LoadBalancer, 443, 80 |

**Security Features**:
- Default deny for all inbound traffic not explicitly allowed
- Stateful connections (return traffic automatically allowed)
- Service tags for simplified rule management
- Logging enabled for audit and troubleshooting

### Service Endpoints

Service endpoints provide secure, direct connectivity to Azure services over the Azure backbone network:

**Benefits**:
- Traffic stays on Azure network (never traverses Internet)
- Optimal routing and performance
- Free (no additional data charges)
- Simplified security rules using service tags

**Enabled Services**:
- **Microsoft.Web**: App Service, Functions
- **Microsoft.Storage**: Storage Account
- **Microsoft.Sql**: Azure SQL Database
- **Microsoft.KeyVault**: Key Vault

## Security Components

### Application Gateway with WAF

**Purpose**: Provides Layer 7 load balancing with web application firewall protection.

**Key Features**:
- **WAF Mode**: Detection (dev) / Prevention (staging, production)
- **Rule Set**: OWASP 3.2 Core Rule Set
- **SSL/TLS**: TLS 1.2 minimum with strong cipher suites
- **Auto-scaling**: 1-3 instances (dev), 2-10 instances (prod)
- **HTTP to HTTPS**: Automatic redirect
- **Health Probes**: Continuous backend monitoring

**WAF Protection Against**:
- SQL Injection
- Cross-Site Scripting (XSS)
- Remote File Inclusion
- Command Injection
- HTTP Protocol Violations
- Session Fixation
- OWASP Top 10 vulnerabilities

**Configuration**:
```json
{
  "wafMode": "Prevention",
  "ruleSetType": "OWASP",
  "ruleSetVersion": "3.2",
  "requestBodyCheck": true,
  "maxRequestBodySizeInKb": 128,
  "fileUploadLimitInMb": 100
}
```

### Key Vault Security

**Purpose**: Secure storage for secrets, keys, and certificates.

**Security Features**:
- **Soft Delete**: 90-day retention for deleted secrets
- **Purge Protection**: Prevents permanent deletion during retention
- **Network ACLs**: Restrict access to specific VNets/IPs
- **RBAC**: Fine-grained access control
- **Audit Logging**: All access logged to Log Analytics
- **Managed Identities**: Passwordless authentication

**Network Security**:
- Default action: Deny all network access
- Allowed access:
  - Azure Services (bypass for deployments)
  - Specific VNet subnets (app, func)
  - Specific IP addresses (admin access)

**Access Policy**:
```json
{
  "permissions": {
    "keys": ["get", "list"],
    "secrets": ["get", "list"],
    "certificates": ["get", "list"]
  }
}
```

### DNS Configuration

**Purpose**: Provides domain name resolution and routing.

**Components**:
- **Azure DNS Zone**: Hosts DNS records
- **A/CNAME Records**: Point to Application Gateway
- **Name Servers**: Azure-managed, globally distributed

**Security**:
- RBAC-controlled DNS modifications
- Activity logging for all changes
- CAA records for certificate authority control

## Deployment Guide

### Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **Azure PowerShell** or Azure CLI
3. **Domain name** (for DNS configuration)

### Deployment Order

**IMPORTANT**: Deploy resources in this order to satisfy dependencies:

1. **Virtual Network** (with all subnets including appgw-subnet)
2. **Key Vault** (with network restrictions)
3. **Application Gateway** (requires VNet and appgw-subnet)
4. **App Service** (with VNet integration)
5. **Azure Functions** (with VNet integration)
6. **SQL Database** (with VNet rules)
7. **DNS Zone** (after Application Gateway for IP/FQDN)

### Step-by-Step Deployment

#### 1. Deploy Virtual Network

```powershell
# Navigate to virtual-network directory
cd infrastructure/arm-templates/virtual-network

# Deploy VNet with all subnets (including Application Gateway subnet)
New-AzResourceGroupDeployment `
    -Name "vnet-deployment-$(Get-Date -Format 'yyyyMMddHHmm')" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "virtual-network.json" `
    -TemplateParameterFile "parameters.prod.json" `
    -Verbose
```

#### 2. Deploy Key Vault with Network Security

```powershell
cd ../key-vault

# Get subnet IDs for network ACLs
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-vnet"
$appSubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "app-subnet"
$funcSubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "func-subnet"

# Deploy Key Vault
New-AzResourceGroupDeployment `
    -Name "keyvault-deployment-$(Get-Date -Format 'yyyyMMddHHmm')" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "key-vault.json" `
    -TemplateParameterFile "parameters.prod.json" `
    -allowedSubnetIds @($appSubnet.Id, $funcSubnet.Id) `
    -networkAclsDefaultAction "Deny" `
    -Verbose
```

#### 3. Deploy Application Gateway with WAF

```powershell
cd ../application-gateway

# Deploy Application Gateway
New-AzResourceGroupDeployment `
    -Name "appgw-deployment-$(Get-Date -Format 'yyyyMMddHHmm')" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "application-gateway.json" `
    -TemplateParameterFile "parameters.prod.json" `
    -Verbose
```

#### 4. Deploy DNS Zone

```powershell
cd ../dns-zone

# Deploy DNS zone
New-AzResourceGroupDeployment `
    -Name "dns-deployment-$(Get-Date -Format 'yyyyMMddHHmm')" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "dns-zone.json" `
    -TemplateParameterFile "parameters.prod.json" `
    -Verbose

# Get name servers and update domain registrar
$dnsZone = Get-AzDnsZone -ResourceGroupName "kbudget-prod-rg" -Name "kbudget.example.com"
Write-Output "Update your domain registrar with these name servers:"
$dnsZone.NameServers
```

#### 5. Configure App Service VNet Integration

```powershell
# Get subnet ID
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-vnet"
$appSubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "app-subnet"

# Configure VNet integration
$webApp = Get-AzWebApp -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-app"
Set-AzWebApp -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-app" -VnetSubnetId $appSubnet.Id
```

## Security Best Practices

### Network Security

✅ **Use NSGs on all subnets** - Defense in depth  
✅ **Implement least privilege** - Only open required ports  
✅ **Use service endpoints** - Keep traffic on Azure backbone  
✅ **Enable DDoS protection** - For production workloads  
✅ **Regular NSG rule review** - Remove unused rules  
✅ **Use service tags** - Simplify rule management  
✅ **Enable NSG flow logs** - For troubleshooting and compliance

### Application Gateway / WAF

✅ **Use WAF in Prevention mode** - In production  
✅ **Monitor WAF logs** - Identify attack patterns  
✅ **Keep rule sets updated** - Use latest OWASP version  
✅ **Test WAF rules** - Use Detection mode first, then switch to Prevention  
✅ **Tune false positives** - Disable specific rules if needed  
✅ **Use strong SSL/TLS** - TLS 1.2+ with strong ciphers  
✅ **Enable HTTP/2** - Better performance  
✅ **Configure health probes** - Ensure backend availability

### Key Vault

✅ **Enable soft delete** - 90-day retention  
✅ **Enable purge protection** - Prevent accidental deletion  
✅ **Use network ACLs** - Restrict access to specific VNets  
✅ **Use managed identities** - Avoid storing credentials  
✅ **Implement RBAC** - Fine-grained access control  
✅ **Enable audit logging** - Track all access  
✅ **Rotate secrets regularly** - Automated rotation when possible  
✅ **Use separate Key Vaults** - Per environment

### DNS

✅ **Use RBAC** - Control who can modify DNS  
✅ **Enable activity logs** - Monitor changes  
✅ **Use CAA records** - Control certificate issuance  
✅ **Set appropriate TTLs** - Balance caching vs flexibility  
✅ **Test DNS changes** - Before updating production  
✅ **Document all records** - Purpose and ownership

## Monitoring and Compliance

### Logging

Enable diagnostic settings for all resources:

```powershell
# Application Gateway
$appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "kbudget-prod-rg"

Set-AzDiagnosticSetting `
    -ResourceId $appgw.Id `
    -Name "appgw-diagnostics" `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category @("ApplicationGatewayAccessLog", "ApplicationGatewayPerformanceLog", "ApplicationGatewayFirewallLog")
```

### Alerts

Set up alerts for critical events:

- **Application Gateway**:
  - Unhealthy backend instances
  - High failed request rate
  - WAF blocked requests spike

- **Key Vault**:
  - Unauthorized access attempts
  - Secret modification
  - Access policy changes

- **Network**:
  - NSG rule violations
  - Unusual traffic patterns
  - VNet peering failures

### Compliance

**Supported Standards**:
- SOC 2
- ISO 27001
- PCI DSS
- GDPR
- HIPAA

**Compliance Features**:
- Audit logs for all access
- Encryption at rest and in transit
- Network isolation
- Access control with RBAC
- Data residency controls

## Troubleshooting

### Application Gateway Issues

**Backend Unhealthy**:
```powershell
# Check backend health
$appgw = Get-AzApplicationGateway -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw"
Get-AzApplicationGatewayBackendHealth -ApplicationGateway $appgw
```

**WAF Blocking Legitimate Traffic**:
- Review WAF logs to identify triggered rule
- Disable specific rule or create exclusion
- Test in Detection mode first

### Connectivity Issues

**App Service Can't Access SQL**:
```powershell
# Verify VNet integration
$webApp = Get-AzWebApp -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-app"
$webApp.VirtualNetworkSubnetId

# Check SQL firewall rules
Get-AzSqlServerFirewallRule -ResourceGroupName "kbudget-prod-rg" -ServerName "kbudget-prod-sql"

# Check NSG rules
Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-prod-rg" | Get-AzNetworkSecurityRuleConfig
```

### DNS Resolution Issues

**Domain Not Resolving**:
```powershell
# Test DNS resolution
nslookup kbudget.example.com ns1-01.azure-dns.com

# Verify name servers at registrar match Azure DNS
$dnsZone = Get-AzDnsZone -ResourceGroupName "kbudget-prod-rg" -Name "kbudget.example.com"
$dnsZone.NameServers
```

## Additional Resources

- [Virtual Network Documentation](../virtual-network/README.md)
- [Application Gateway Documentation](../application-gateway/README.md)
- [Key Vault Documentation](../key-vault/README.md)
- [DNS Zone Documentation](../dns-zone/README.md)
- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
- [Network Security Documentation](https://docs.microsoft.com/azure/security/fundamentals/network-best-practices)
