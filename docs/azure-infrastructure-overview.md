# Azure Infrastructure Overview

This document provides a comprehensive overview of the Azure infrastructure for the KBudget GPT application.

## Table of Contents

- [Architecture](#architecture)
- [Resources](#resources)
- [Environments](#environments)
- [Deployment](#deployment)
- [Security](#security)
- [Networking](#networking)
- [Cost Estimation](#cost-estimation)
- [Monitoring](#monitoring)

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Resource Group (kbudget-{env}-rg)             │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │                                                            │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         Virtual Network (kbudget-{env}-vnet)         │ │ │
│  │  ├──────────────────────────────────────────────────────┤ │ │
│  │  │                                                      │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │ │ │
│  │  │  │ app-subnet  │  │ cosmos-snet │  │ func-subnet │ │ │ │
│  │  │  │ 10.x.1.0/24 │  │ 10.x.2.0/24 │  │ 10.x.3.0/24 │ │ │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘ │ │ │
│  │  │                                                      │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                                                            │ │
│  │  ┌─────────────────┐        ┌──────────────────┐         │ │
│  │  │   App Service   │───────▶│   Cosmos DB      │         │ │
│  │  │ (Web Frontend)  │        │  (Database)      │         │ │
│  │  └────────┬────────┘        └──────────────────┘         │ │
│  │           │                                               │ │
│  │           │        ┌──────────────────┐                  │ │
│  │           └───────▶│   Key Vault      │                  │ │
│  │           ┌────────│ (Secrets/Keys)   │                  │ │
│  │           │        └──────────────────┘                  │ │
│  │           │                                               │ │
│  │  ┌────────▼────────┐        ┌──────────────────┐         │ │
│  │  │ Azure Functions │───────▶│ Storage Account  │         │ │
│  │  │  (Background)   │        │   (Blob/Files)   │         │ │
│  │  └─────────────────┘        └──────────────────┘         │ │
│  │                                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Request** → App Service (HTTPS)
2. **App Service** → Cosmos DB (via HTTPS/443)
3. **App Service** → Storage Account (via Service Endpoint)
4. **App Service** → Key Vault (for secrets)
5. **Azure Functions** → Cosmos DB (scheduled tasks)
6. **Azure Functions** → Storage Account (runtime + data)

## Resources

### Resource Inventory

| Resource | SKU/Tier | Purpose | Cost Impact |
|----------|----------|---------|-------------|
| **Resource Group** | - | Container | Free |
| **Virtual Network** | - | Network isolation | Free |
| **Network Security Groups** | - | Traffic filtering | Free |
| **Key Vault** | Standard/Premium | Secrets management | Low |
| **Storage Account** | Standard LRS/GRS | Blob/file storage | Low-Medium |
| **Cosmos DB Account** | - | Database account | Free |
| **Cosmos DB Database** | 400-1000 RU/s | Application database | Medium-High |
| **App Service Plan** | B1/S1/P1v2 | Compute for web app | Medium-High |
| **App Service** | - | Web application | Included in plan |
| **Azure Functions** | Consumption Y1 | Serverless compute | Low (pay-per-use) |
| **Application Insights** | - | Monitoring/telemetry | Low |

## Environments

### Environment Configuration

| Setting | Development | Staging | Production |
|---------|------------|---------|------------|
| **Resource Group** | kbudget-dev-rg | kbudget-staging-rg | kbudget-prod-rg |
| **VNet CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Cosmos DB Throughput** | 400 RU/s | 600 RU/s | 1000 RU/s |
| **Cosmos DB Consistency** | Session | Session | Strong |
| **App Service SKU** | B1 (Basic) | S1 (Standard) | P1v2 (Premium) |
| **App Service Instances** | 1 | 1 | 2 |
| **Storage Replication** | LRS | GRS | GRS |
| **Key Vault SKU** | Standard | Standard | Premium |
| **DDoS Protection** | Disabled | Disabled | Enabled |
| **Advanced Threat Protection** | Disabled | Enabled | Enabled |
| **Always On** | Disabled | Enabled | Enabled |

## Deployment

### Deployment Order

Resources are deployed in dependency order:

1. **Resource Group** (subscription-level)
2. **Virtual Network** (foundation)
3. **Key Vault** (required for secrets)
4. **Storage Account** (required for Functions)
5. **Cosmos DB**
6. **App Service**
7. **Azure Functions**

### Deployment Methods

#### PowerShell (Recommended)

```powershell
cd infrastructure/arm-templates/main-deployment
.\Deploy-AzureResources.ps1 -Environment dev
```

#### Azure CLI

```bash
az deployment group create \
  --resource-group kbudget-dev-rg \
  --template-file app-service/app-service.json \
  --parameters @app-service/parameters.dev.json
```

#### Azure Portal

1. Navigate to "Deploy a custom template"
2. Upload ARM template JSON
3. Fill in parameters
4. Deploy

## Security

### Security Layers

#### Network Security

- **Virtual Network**: Isolated network with subnets
- **NSGs**: Firewall rules per subnet
- **Service Endpoints**: Private connections to Azure services
- **Subnet Delegation**: App Service VNet integration

#### Access Control

- **Managed Identities**: System-assigned for App Service and Functions
- **Key Vault Access Policies**: Granular permissions
- **Cosmos DB Firewall**: VNet rules + Azure service access
- **Storage Firewall**: Allow Azure services

#### Encryption

- **In Transit**: TLS 1.2 minimum everywhere
- **At Rest**: 
  - Storage Account: Blob and file encryption
  - Cosmos DB: Encryption at rest (automatic)
  - Key Vault: HSM-backed keys (Premium SKU)

#### Secrets Management

- **No Hardcoded Secrets**: Never in code or config
- **Key Vault Storage**: All sensitive data in Key Vault
- **Key Vault References**: App settings reference KV secrets
- **Auto-Generated**: Connection strings generated by script

### Security Best Practices

✅ HTTPS only enforcement  
✅ Disable public blob access  
✅ Enable soft delete on Key Vault  
✅ Enable purge protection (staging/prod)  
✅ Advanced Threat Protection (Cosmos DB)  
✅ Application Insights for monitoring  
✅ Regular security audits via Azure Security Center  

## Networking

### Network Architecture

> **Detailed Network Documentation**: For comprehensive network architecture diagrams, subnet layout, traffic flows, and security boundaries, see the [Network Architecture Guide](NETWORK-ARCHITECTURE.md).

The KBudget GPT application uses a multi-tier network architecture with four dedicated subnets for workload segregation:

#### Virtual Network Layout

| Subnet | CIDR | Purpose | Delegation |
|--------|------|---------|------------|
| frontend-subnet | 10.x.4.0/24 | Public-facing tier | None |
| app-subnet | 10.x.1.0/24 | App Service, APIs | Microsoft.Web/serverFarms |
| cosmos-subnet | 10.x.2.0/24 | Cosmos DB | None |
| func-subnet | 10.x.3.0/24 | Azure Functions | Microsoft.Web/serverFarms |

Each subnet provides 256 IP addresses (251 usable, 5 reserved by Azure), allowing for significant horizontal scaling.

#### NSG Rules

**Frontend Subnet NSG**:
- Allow HTTPS (443) from Internet
- Allow HTTP (80) from Internet
- Deny all other inbound

**App Subnet NSG**:
- Allow HTTPS (443) from all
- Allow HTTP (80) from all

**Cosmos Subnet NSG**:
- Allow HTTPS (443) from app-subnet only (10.x.1.0/24)
- Deny all other inbound

#### Service Endpoints

Configured on all subnets:
- Microsoft.Web
- Microsoft.Storage
- Microsoft.AzureCosmosDB
- Microsoft.KeyVault

### DNS and Hostnames

| Resource | Default Hostname |
|----------|-----------------|
| App Service | `kbudget-{env}-app.azurewebsites.net` |
| Azure Functions | `kbudget-{env}-func.azurewebsites.net` |
| Cosmos DB Account | `kbudget-{env}-cosmos.documents.azure.com` |
| Storage Account | `kbudget{env}st.blob.core.windows.net` |
| Key Vault | `kbudget-{env}-kv.vault.azure.net` |

## Cost Estimation

### Monthly Cost Estimates (USD)

#### Development Environment

| Resource | SKU | Est. Monthly Cost |
|----------|-----|------------------|
| Cosmos DB | 400 RU/s | $24 |
| App Service Plan | B1 | $13 |
| Storage Account | Standard LRS | $2 |
| Key Vault | Standard | $1 |
| Functions | Consumption | $1 |
| Application Insights | Free tier | $0 |
| **Total** | | **~$41/month** |

#### Staging Environment

| Resource | SKU | Est. Monthly Cost |
|----------|-----|------------------|
| Cosmos DB | 600 RU/s | $35 |
| App Service Plan | S1 | $70 |
| Storage Account | Standard GRS | $5 |
| Key Vault | Standard | $1 |
| Functions | Consumption | $2 |
| Application Insights | Basic | $2 |
| **Total** | | **~$115/month** |

#### Production Environment

| Resource | SKU | Est. Monthly Cost |
|----------|-----|------------------|
| Cosmos DB | 1000 RU/s | $58 |
| App Service Plan | P1v2 (x2) | $292 |
| Storage Account | Standard GRS | $10 |
| Key Vault | Premium | $5 |
| Functions | Consumption | $5 |
| Application Insights | Enterprise | $10 |
| DDoS Protection | Standard | $2,944 |
| **Total** | | **~$3,324/month** |

**Note**: DDoS Protection Standard is expensive. Consider using DDoS Basic (free) unless required.

### Cost Optimization Tips

1. **Shut down dev resources** when not in use
2. **Use Azure Reserved Instances** for production (1-3 year commitment)
3. **Enable autoscaling** to scale down during low usage
4. **Review and delete old resources** regularly
5. **Use tags** for cost allocation and tracking
6. **Monitor spending** with Azure Cost Management

## Monitoring

### Application Insights

Configured for:
- App Service
- Azure Functions

Features:
- Request tracking
- Performance monitoring
- Failure analysis
- Custom metrics
- Live metrics stream
- Application map

### Azure Monitor

- Resource health
- Activity logs
- Metrics
- Alerts
- Diagnostics

### Recommended Alerts

1. **App Service**: CPU > 80% for 10 minutes
2. **Cosmos DB**: RU consumption > 90%
3. **Storage**: High egress costs
4. **Functions**: Execution errors
5. **Key Vault**: Failed access attempts

### Logging

PowerShell deployment script logs:
- Location: `infrastructure/arm-templates/main-deployment/logs/`
- Format: `deployment_{env}_{timestamp}.log`
- Retention: Keep for audit/troubleshooting

Azure Resource logs:
- Enable diagnostic settings
- Send to Log Analytics workspace
- Configure retention policies

## Backup and Disaster Recovery

### Cosmos DB

- **Automated backups**: Built-in (continuous backup mode)
- **Point-in-time restore**: Last 30 days
- **Multi-region replication**: Consider for production
- **Backup redundancy**: Zone/Geo-redundant options

### Storage Account

- **Geo-redundant storage**: Staging and production
- **Soft delete**: Enable for blob recovery
- **Versioning**: Enable for critical data

### Key Vault

- **Soft delete**: 90-day retention
- **Purge protection**: Enabled in staging/prod
- **Backup keys/secrets**: Export critical items

## Troubleshooting

### Common Issues

1. **Deployment fails**: Check logs in `logs/` directory
2. **Can't access Cosmos DB**: Verify firewall rules and VNet integration
3. **App can't read secrets**: Check Key Vault access policy for managed identity
4. **High costs**: Review resource SKUs and scale down RU/s if possible

### Useful Commands

```powershell
# View all resources
Get-AzResource -ResourceGroupName "kbudget-dev-rg"

# Check deployment history
Get-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg"

# View App Service logs
Get-AzWebAppSlotPublishingLog -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"

# Test network connectivity
Test-AzNetworkWatcherConnectivity -SourceResourceGroupName "kbudget-dev-rg" ...
```

## Related Documentation

- [Main Deployment README](../infrastructure/arm-templates/main-deployment/README.md)
- [Azure Resource Group Naming Conventions](azure-resource-group-naming-conventions.md)
- [Azure Resource Group Best Practices](azure-resource-group-best-practices.md)

## Support

For infrastructure questions or issues:
1. Check deployment logs
2. Review this documentation
3. Consult resource-specific READMEs
4. Contact DevOps Team

---

*Last Updated: 2024*
