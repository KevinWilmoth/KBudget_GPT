# Virtual Network ARM Template

This directory contains ARM templates and PowerShell scripts for deploying Azure Virtual Network with subnets and network security for the KBudget GPT application.

## Table of Contents

- [Overview](#overview)
- [Resources Created](#resources-created)
- [Network Architecture](#network-architecture)
- [Subnet Segmentation](#subnet-segmentation)
- [Deployment](#deployment)
- [Parameters](#parameters)
- [Scaling Considerations](#scaling-considerations)
- [Security Features](#security-features)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)

## Overview

The Virtual Network (VNet) infrastructure provides network isolation and segmentation for the KBudget GPT application. The design follows Azure best practices for multi-tier applications with separate subnets for different workload types.

**Key Features:**
- Multi-tier network segmentation (Frontend, Application, Database, Functions)
- Network Security Groups (NSGs) with least-privilege access control
- Service endpoints for secure, private access to Azure PaaS services
- Support for horizontal scaling across all tiers
- Environment-specific configurations (dev, staging, production)
- Comprehensive tagging and documentation

## Resources Created

- **Virtual Network (VNet)**: Network isolation boundary for Azure resources
- **Subnets**: Four dedicated subnets for workload segmentation
  - **Frontend Subnet**: Public-facing web tier
  - **Application Subnet**: Backend application tier
  - **Database Subnet**: Data tier
  - **Functions Subnet**: Serverless compute tier
- **Network Security Groups (NSGs)**: Traffic filtering and access control rules
- **Service Endpoints**: Secure, private connectivity to Azure services
- **Subnet Delegations**: Enable VNet integration for App Service and Azure Functions

## Network Architecture

### Topology Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Azure Virtual Network (VNet)                        │
│                  Address Space: 10.x.0.0/16 (65,536 IPs)               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ Frontend Subnet (10.x.4.0/24) - 256 IPs                          │ │
│  │ ┌───────────────────────────────────────────────────────────────┐ │ │
│  │ │ NSG: frontend-nsg                                             │ │ │
│  │ │ - Allow HTTPS (443) from Internet                             │ │ │
│  │ │ - Allow HTTP (80) from Internet (redirect to HTTPS)           │ │ │
│  │ └───────────────────────────────────────────────────────────────┘ │ │
│  │ Purpose: Public-facing web applications, load balancers          │ │
│  │ Service Endpoints: Microsoft.Web, Storage, KeyVault              │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ Application Subnet (10.x.1.0/24) - 256 IPs                       │ │
│  │ ┌───────────────────────────────────────────────────────────────┐ │ │
│  │ │ NSG: app-nsg                                                  │ │ │
│  │ │ - Allow HTTPS (443) from all                                  │ │ │
│  │ │ - Allow HTTP (80) from all                                    │ │ │
│  │ └───────────────────────────────────────────────────────────────┘ │ │
│  │ Purpose: App Service, backend APIs, business logic               │ │
│  │ Delegation: Microsoft.Web/serverFarms (VNet Integration)         │ │
│  │ Service Endpoints: Microsoft.Web, Storage, Sql, KeyVault         │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ Database Subnet (10.x.2.0/24) - 256 IPs                          │ │
│  │ ┌───────────────────────────────────────────────────────────────┐ │ │
│  │ │ NSG: db-nsg                                                   │ │ │
│  │ │ - Allow SQL (1433) from Application Subnet ONLY               │ │ │
│  │ │ - Deny all other inbound traffic                              │ │ │
│  │ └───────────────────────────────────────────────────────────────┘ │ │
│  │ Purpose: SQL Database private endpoints, managed instances       │ │
│  │ Service Endpoints: Microsoft.Sql                                  │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ Functions Subnet (10.x.3.0/24) - 256 IPs                         │ │
│  │ Purpose: Azure Functions, background jobs, scheduled tasks        │ │
│  │ Delegation: Microsoft.Web/serverFarms (VNet Integration)          │ │
│  │ Service Endpoints: Microsoft.Web, Storage, Sql, KeyVault          │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

        │                     │                    │
        ▼                     ▼                    �▼
  ┌──────────┐         ┌──────────┐        ┌──────────┐
  │ Internet │         │ Azure    │        │ Storage  │
  │  Users   │         │ SQL DB   │        │ Account  │
  └──────────┘         └──────────┘        └──────────┘
```

### Data Flow

1. **User Request** → Frontend Subnet (HTTPS)
2. **Frontend** → Application Subnet (internal routing)
3. **Application Subnet** → Database Subnet (via service endpoint, port 1433)
4. **Application Subnet** → Storage Account (via service endpoint)
5. **Application Subnet** → Key Vault (for secrets)
6. **Functions Subnet** → Database Subnet (scheduled tasks)
7. **Functions Subnet** → Storage Account (runtime + data)

## Subnet Segmentation

The network is divided into four application tiers to ensure proper isolation and security:

| Subnet | Purpose | Address Range | IPs | Delegated To | NSG Rules |
|--------|---------|---------------|-----|--------------|-----------|
| **frontend-subnet** | Public-facing workloads | 10.x.4.0/24 | 256 | - | Allow HTTP/HTTPS from Internet |
| **app-subnet** | App Service, APIs | 10.x.1.0/24 | 256 | Microsoft.Web/serverFarms | Allow HTTP/HTTPS |
| **db-subnet** | SQL Database | 10.x.2.0/24 | 256 | - | Allow SQL only from app-subnet |
| **func-subnet** | Functions | 10.x.3.0/24 | 256 | Microsoft.Web/serverFarms | Default allow outbound |

### Subnet Design Rationale

- **Frontend Subnet**: Isolated public-facing tier for load balancers, application gateways, or public-facing web servers
- **Application Subnet**: Contains business logic and APIs with VNet integration for App Service
- **Database Subnet**: Restricted access tier for data persistence with SQL firewall rules
- **Functions Subnet**: Isolated serverless compute for background processing and scheduled tasks

## Deployment

### Prerequisites

1. **Azure PowerShell Module**
   ```powershell
   Install-Module -Name Az.Network -Force
   Install-Module -Name Az.Resources -Force
   ```

2. **Azure Authentication**
   ```powershell
   Connect-AzAccount
   Set-AzContext -Subscription "Your-Subscription-Name"
   ```

3. **Resource Group** (created automatically if it doesn't exist)

### Quick Start

Deploy to development environment:

```powershell
.\Deploy-VirtualNetwork.ps1 -Environment dev
```

Deploy to staging environment:

```powershell
.\Deploy-VirtualNetwork.ps1 -Environment staging -Location westus2
```

Deploy to production with diagnostics:

```powershell
.\Deploy-VirtualNetwork.ps1 -Environment prod -ShowDiagnostics
```

### Deployment Options

```powershell
# Validate template without deploying
.\Deploy-VirtualNetwork.ps1 -Environment dev -ValidateOnly

# Preview deployment (WhatIf mode)
.\Deploy-VirtualNetwork.ps1 -Environment dev -WhatIf

# Deploy with full diagnostics
.\Deploy-VirtualNetwork.ps1 -Environment prod -ShowDiagnostics

# Skip template validation (faster, use if template already validated)
.\Deploy-VirtualNetwork.ps1 -Environment dev -SkipValidation
```

### Manual Deployment via ARM Template

If you prefer to deploy without the PowerShell script:

```powershell
New-AzResourceGroupDeployment `
    -Name "vnet-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "virtual-network.json" `
    -TemplateParameterFile "parameters.dev.json"
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| vnetName | string | - | Virtual Network name |
| location | string | Resource Group location | Azure region |
| vnetAddressPrefix | string | 10.0.0.0/16 | VNet address space (65,536 IPs) |
| appSubnetName | string | app-subnet | Application subnet name |
| appSubnetPrefix | string | 10.0.1.0/24 | App subnet address range (256 IPs) |
| dbSubnetName | string | db-subnet | Database subnet name |
| dbSubnetPrefix | string | 10.0.2.0/24 | DB subnet address range (256 IPs) |
| funcSubnetName | string | func-subnet | Functions subnet name |
| funcSubnetPrefix | string | 10.0.3.0/24 | Functions subnet address range (256 IPs) |
| frontendSubnetName | string | frontend-subnet | Frontend subnet name |
| frontendSubnetPrefix | string | 10.0.4.0/24 | Frontend subnet address range (256 IPs) |
| enableDdosProtection | bool | false | Enable DDoS Protection Standard |
| tags | object | {} | Resource tags for governance |

### Environment-Specific Configurations

#### Development
- **Address Space**: 10.0.0.0/16
- **Frontend Subnet**: 10.0.4.0/24
- **Application Subnet**: 10.0.1.0/24
- **Database Subnet**: 10.0.2.0/24
- **Functions Subnet**: 10.0.3.0/24
- **DDoS Protection**: Disabled (cost optimization)
- **Tags**: Environment=Development

#### Staging
- **Address Space**: 10.1.0.0/16
- **Frontend Subnet**: 10.1.4.0/24
- **Application Subnet**: 10.1.1.0/24
- **Database Subnet**: 10.1.2.0/24
- **Functions Subnet**: 10.1.3.0/24
- **DDoS Protection**: Disabled
- **Tags**: Environment=Staging

#### Production
- **Address Space**: 10.2.0.0/16
- **Frontend Subnet**: 10.2.4.0/24
- **Application Subnet**: 10.2.1.0/24
- **Database Subnet**: 10.2.2.0/24
- **Functions Subnet**: 10.2.3.0/24
- **DDoS Protection**: Enabled (recommended for production)
- **Tags**: Environment=Production

## Scaling Considerations

### Horizontal Scaling

The VNet architecture supports horizontal scaling across all tiers:

1. **Frontend Tier**
   - 256 IP addresses available
   - Supports up to ~250 instances (some IPs reserved by Azure)
   - Can host multiple load balancers or application gateways

2. **Application Tier**
   - 256 IP addresses available
   - App Service VNet Integration: Supports Premium and higher tiers
   - Can scale to multiple App Service plans

3. **Database Tier**
   - 256 IP addresses available
   - Supports private endpoints for SQL Database
   - Sufficient for multiple SQL Managed Instances

4. **Functions Tier**
   - 256 IP addresses available
   - Premium plan VNet Integration supported
   - Elastic scaling with private connectivity

### Vertical Scaling

The /16 address space (65,536 IPs) provides room for:
- Additional subnets for new services (Azure Kubernetes Service, Application Gateway, etc.)
- Subnet expansion if needed
- Multiple environments in the same region

### Future Growth

If you need more IP addresses:

1. **Expand existing subnets**: Change /24 to /23 (512 IPs) or /22 (1,024 IPs)
   - Requires subnet recreation (involves downtime)
   
2. **Add new subnets**: Use remaining address space
   - 10.x.5.0/24, 10.x.6.0/24, etc.
   - No downtime

3. **VNet Peering**: Connect multiple VNets
   - Peer dev/staging/prod VNets for hybrid scenarios
   - No downtime, no IP conflicts

### Performance

- **VNet**: Free, no performance limits
- **Service Endpoints**: Free, better performance than public endpoints
- **VNet Integration**: Slight latency overhead (~5ms)
- **NSG Rules**: Minimal performance impact

## Security Features

### Network Isolation

- **Subnet Segregation**: Each tier is isolated in its own subnet
- **NSG Rules**: Explicit allow/deny rules per subnet
- **Service Endpoints**: Private connectivity to Azure services (no internet exposure)

### Access Control

1. **Frontend Subnet NSG**
   - Allow HTTPS (443) from Internet
   - Allow HTTP (80) from Internet (for redirects)
   - Default deny all other inbound

2. **Application Subnet NSG**
   - Allow HTTP/HTTPS for App Service integration
   - Subnet delegation restricts resource types

3. **Database Subnet NSG**
   - Allow SQL (1433) ONLY from Application Subnet (10.x.1.0/24)
   - Deny all other inbound traffic
   - Additional SQL firewall rules at database level

4. **Functions Subnet**
   - No explicit NSG (uses default Azure rules)
   - Subnet delegation for serverless integration

### DDoS Protection

- **Development/Staging**: Basic DDoS (included, no extra cost)
- **Production**: DDoS Protection Standard (optional, ~$2,944/month)
  - 20 Tbps mitigation capacity
  - Always-on traffic monitoring
  - Application layer protection

### Service Endpoints

Service endpoints provide:
- **Private connectivity** to Azure services (no internet routing)
- **Source IP preservation** (Azure sees traffic from VNet IP)
- **No NAT required** (direct connectivity)
- **Free** (no additional charges)

Configured endpoints:
- Microsoft.Web (App Service)
- Microsoft.Storage (Storage Account)
- Microsoft.Sql (SQL Database)
- Microsoft.KeyVault (Key Vault)

## Post-Deployment

### Integrate App Service with VNet

```powershell
# Get subnet ID
$vnetName = "kbudget-dev-vnet"
$subnetName = "app-subnet"
$rgName = "kbudget-dev-rg"

$subnet = Get-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -VirtualNetwork (Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName)

# Integrate App Service
$webApp = Get-AzWebApp -ResourceGroupName $rgName -Name "kbudget-dev-app"

Set-AzWebApp `
    -ResourceGroupName $rgName `
    -Name "kbudget-dev-app" `
    -VnetSubnetId $subnet.Id
```

### Configure SQL Firewall for VNet

```powershell
# Get subnet ID
$subnetId = (Get-AzVirtualNetworkSubnetConfig `
    -Name "app-subnet" `
    -VirtualNetwork (Get-AzVirtualNetwork -Name "kbudget-dev-vnet" -ResourceGroupName $rgName)).Id

# Add virtual network rule to SQL Server
New-AzSqlServerVirtualNetworkRule `
    -ResourceGroupName $rgName `
    -ServerName "kbudget-dev-sql" `
    -VirtualNetworkRuleName "AllowAppSubnet" `
    -VirtualNetworkSubnetId $subnetId
```

### Configure Storage Account Service Endpoint

```powershell
# Get subnet ID
$subnetId = (Get-AzVirtualNetworkSubnetConfig `
    -Name "app-subnet" `
    -VirtualNetwork (Get-AzVirtualNetwork -Name "kbudget-dev-vnet" -ResourceGroupName $rgName)).Id

# Add VNet rule to storage account
Add-AzStorageAccountNetworkRule `
    -ResourceGroupName $rgName `
    -Name "kbudgetdevstorage" `
    -VirtualNetworkResourceId $subnetId

# Update default action to deny (restrict to VNet only)
Update-AzStorageAccountNetworkRuleSet `
    -ResourceGroupName $rgName `
    -Name "kbudgetdevstorage" `
    -DefaultAction Deny
```

### View Network Topology

```powershell
# Get VNet details
Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName | Format-List

# View all subnets
Get-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork (Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName)

# View NSG rules
Get-AzNetworkSecurityGroup -ResourceGroupName $rgName | Get-AzNetworkSecurityRuleConfig

# View effective NSG rules (requires NIC)
$nic = Get-AzNetworkInterface -ResourceGroupName $rgName
Get-AzEffectiveNetworkSecurityGroup `
    -NetworkInterfaceName $nic.Name `
    -ResourceGroupName $rgName
```

## Outputs

The deployment produces the following outputs:

| Output | Type | Description |
|--------|------|-------------|
| vnetId | string | Virtual Network resource ID |
| vnetName | string | Virtual Network name |
| appSubnetId | string | Application subnet resource ID |
| dbSubnetId | string | Database subnet resource ID |
| funcSubnetId | string | Functions subnet resource ID |
| frontendSubnetId | string | Frontend subnet resource ID |

Use outputs in other deployments:

```powershell
$deployment = Get-AzResourceGroupDeployment `
    -ResourceGroupName $rgName `
    -Name "vnet-deployment"

$appSubnetId = $deployment.Outputs.appSubnetId.Value
```

## Network Flow

### Typical Request Flow

1. **Internet → Frontend Subnet**:
   - User connects via HTTPS (port 443)
   - Traffic allowed by frontend-nsg
   - Hits load balancer or application gateway

2. **Frontend → Application Subnet**:
   - Internal routing within VNet
   - No internet exposure
   - App Service processes request

3. **Application → Database Subnet**:
   - App Service connects to SQL Database
   - Traffic flows through app-subnet → db-subnet
   - NSG allows only from app-subnet (10.x.1.0/24)
   - Uses service endpoint (no internet)
   - SQL firewall provides additional security layer

4. **Application → Storage/Key Vault**:
   - Uses service endpoints
   - Secure, private connection
   - No internet routing
   - Source IP preserved

5. **Functions → Database**:
   - Background jobs from func-subnet
   - Access to database via service endpoint
   - Scheduled tasks, batch processing

## Troubleshooting

### Test Connectivity

```powershell
# From App Service, test SQL connectivity
# Use Kudu console (https://kbudget-dev-app.scm.azurewebsites.net)
# Debug Console > CMD or PowerShell
# Run: tcpping kbudget-dev-sql.database.windows.net 1433

# Alternative: nameresolver tool (built into Kudu)
nameresolver kbudget-dev-sql.database.windows.net
```

### View Effective NSG Rules

```powershell
$nic = Get-AzNetworkInterface -ResourceGroupName $rgName
Get-AzEffectiveNetworkSecurityGroup `
    -NetworkInterfaceName $nic.Name `
    -ResourceGroupName $rgName
```

### Check Service Endpoint Status

```powershell
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "app-subnet" -VirtualNetwork $vnet

# Check service endpoints
$subnet.ServiceEndpoints | Select-Object Service, ProvisioningState
```

### Test VNet Integration

```powershell
# From App Service Kudu console, check outbound IP
# The IP should be from the VNet subnet range
curl https://api.ipify.org

# Or use Azure CLI
az webapp show --resource-group $rgName --name "kbudget-dev-app" --query outboundIpAddresses
```

### Common Issues

1. **App Service can't connect to SQL Database**
   - Check NSG rules on db-subnet
   - Verify SQL firewall has VNet rule
   - Ensure service endpoint is enabled on app-subnet
   - Check subnet delegation

2. **VNet Integration fails**
   - Verify App Service is Premium tier or higher
   - Check subnet has proper delegation (Microsoft.Web/serverFarms)
   - Ensure subnet has available IP addresses

3. **Service endpoint not working**
   - Verify service endpoint is configured on subnet
   - Check target service (SQL, Storage) has VNet rule
   - Ensure default action on target service is configured

## Cost Optimization

- **VNet**: Free
- **Subnets**: Free
- **Service Endpoints**: Free
- **NSGs**: Free
- **DDoS Protection Basic**: Free (included)
- **DDoS Protection Standard**: ~$2,944/month (optional, production only)

**Recommendation**: Use Basic DDoS for dev/staging, consider Standard for production only if required by security policy.

## Tagging Strategy

All resources are tagged for governance and cost tracking:

```json
{
  "Environment": "Development|Staging|Production",
  "Project": "KBudget-GPT",
  "Owner": "DevOps-Team",
  "CostCenter": "CC-12345",
  "Application": "KBudget"
}
```

Customize tags in parameter files as needed for your organization.

## Additional Resources

- [Azure Virtual Network Documentation](https://docs.microsoft.com/azure/virtual-network/)
- [Virtual Network Service Endpoints](https://docs.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview)
- [App Service VNet Integration](https://docs.microsoft.com/azure/app-service/web-sites-integrate-with-vnet)
- [Network Security Groups](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Azure DDoS Protection](https://docs.microsoft.com/azure/ddos-protection/ddos-protection-overview)
