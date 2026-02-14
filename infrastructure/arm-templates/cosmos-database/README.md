# Cosmos DB ARM Template

This directory contains ARM templates for deploying Azure Cosmos DB.

## Resources Created

- **Cosmos DB Account**: Azure Cosmos DB account with SQL API
- **Cosmos DB Database**: Application database
- **Cosmos DB Container**: Collection for budget data
- **Indexing Policy**: Automatic indexing for all paths

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cosmosAccountName | string | - | Cosmos DB account name (globally unique) |
| cosmosDatabaseName | string | - | Database name |
| cosmosContainerName | string | budgets | Container name |
| location | string | Resource Group location | Azure region |
| consistencyLevel | string | Session | Consistency level (Eventual, Session, Strong, etc.) |
| maxStalenessPrefix | int | 100000 | Max stale requests for BoundedStaleness |
| maxIntervalInSeconds | int | 300 | Max lag time for BoundedStaleness |
| enableAutomaticFailover | bool | false | Enable automatic failover |
| enableMultipleWriteLocations | bool | false | Enable multi-region writes |
| throughput | int | 400 | Database throughput in RU/s |
| partitionKeyPath | string | /id | Partition key path |
| enableServerless | bool | false | Enable serverless mode |
| enableFreeTier | bool | false | Enable free tier |
| tags | object | {} | Resource tags |

## Environment-Specific Configurations

### Development
- Mode: Serverless
- Free Tier: Enabled
- Automatic Failover: Disabled (cost savings)
- Consistency: Session

### Staging
- Throughput: 400 RU/s
- Automatic Failover: Enabled
- Consistency: Session

### Production
- Throughput: 1000 RU/s
- Automatic Failover: Enabled
- Consistency: Session

## Key Management

Cosmos DB primary keys are automatically stored in Key Vault during deployment:

The deployment script stores the primary master key as `CosmosDbPrimaryKey` in Key Vault for secure access.

## Deployment

### Using PowerShell

```powershell
New-AzResourceGroupDeployment `
    -Name "cosmos-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "cosmos-database.json" `
    -TemplateParameterFile "parameters.dev.json"
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| cosmosAccountEndpoint | string | Cosmos DB account endpoint URL |
| cosmosAccountId | string | Cosmos DB account resource ID |
| cosmosDatabaseId | string | Database resource ID |
| cosmosContainerId | string | Container resource ID |
| primaryMasterKey | string | Primary master key for authentication |
| connectionString | string | Connection string with key |

## Security Features

- TLS 1.2 encryption in transit
- Session consistency level for strong data consistency
- Automatic indexing
- Keys stored in Key Vault
- Azure Services network bypass enabled
- Public network access enabled (can be restricted via firewall rules)

## Connection String

After deployment, retrieve the connection string:

```powershell
$outputs = (Get-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg" -Name "cosmos-deployment").Outputs
$connectionString = $outputs.connectionString.Value

# Or get key from Key Vault
$primaryKey = Get-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "CosmosDbPrimaryKey" -AsPlainText
$endpoint = $outputs.cosmosAccountEndpoint.Value

# Full connection string
$fullConnectionString = "AccountEndpoint=$endpoint;AccountKey=$primaryKey;"
```

## Post-Deployment

1. **Configure firewall rules** for specific IPs (optional):
   ```powershell
   # Add IP address to Cosmos DB firewall
   $cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-cosmos"
   Update-AzCosmosDBAccount -ResourceGroupName "kbudget-dev-rg" `
       -Name "kbudget-dev-cosmos" `
       -IpRangeFilter "x.x.x.x"
   ```

2. **Configure VNet integration** (optional):
   ```powershell
   # Add virtual network rule
   $vnetRule = New-AzCosmosDBVirtualNetworkRule `
       -Id "/subscriptions/{sub-id}/resourceGroups/kbudget-dev-rg/providers/Microsoft.Network/virtualNetworks/kbudget-dev-vnet/subnets/app-subnet"
   
   Update-AzCosmosDBAccount -ResourceGroupName "kbudget-dev-rg" `
       -Name "kbudget-dev-cosmos" `
       -VirtualNetworkRule @($vnetRule)
   ```

3. **Seed initial data**:
   - Connect using Azure Cosmos DB SDK
   - Use Azure Portal Data Explorer
   - Import data via Azure CLI

## Consistency Levels

- **Eventual**: Highest availability, lowest latency, weakest consistency
- **Session**: Default, provides read-your-writes consistency
- **Strong**: Strongest consistency, higher latency, lower availability

## Cost Optimization

### Development
- Uses serverless mode (pay per request)
- Free tier enabled (1000 RU/s and 25 GB free)
- Estimated cost: $0-5/month

### Staging
- 400 RU/s provisioned throughput
- Estimated cost: ~$24/month

### Production
- 1000 RU/s provisioned throughput
- Estimated cost: ~$58/month

## Monitoring

Key metrics to monitor:
- Request Units (RU) consumption
- Throttled requests (429 errors)
- Storage usage
- Availability
- Latency (P95, P99)

Configure alerts for:
- RU consumption > 80%
- Throttled requests
- Storage approaching limits
