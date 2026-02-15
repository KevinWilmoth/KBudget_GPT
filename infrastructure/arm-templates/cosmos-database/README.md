# Cosmos DB ARM Templates

This directory contains ARM templates for deploying Azure Cosmos DB with multiple containers for the KBudget envelope budgeting system.

## Available Templates

### 1. cosmos-database.json (Legacy - Single Container)
Legacy template that creates a single container. **Deprecated** - Use `cosmos-containers.json` instead.

### 2. cosmos-containers.json (Recommended - Multiple Containers)
**Recommended template** that creates all four containers with optimized indexing policies:
- **Users** - User profiles and settings
- **Budgets** - Budget periods and configurations
- **Envelopes** - Envelope categories and allocations
- **Transactions** - Financial transactions

## Resources Created

The `cosmos-containers.json` template creates:
- **Cosmos DB Account**: Azure Cosmos DB account with SQL API
- **Cosmos DB Database**: Application database with shared throughput
- **Users Container**: Partition key `/userId`, custom indexing for user queries
- **Budgets Container**: Partition key `/userId`, optimized for budget timeline queries
- **Envelopes Container**: Partition key `/userId`, optimized for envelope display and filtering
- **Transactions Container**: Partition key `/userId`, optimized for transaction history and reporting

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cosmosAccountName | string | - | Cosmos DB account name (globally unique) |
| cosmosDatabaseName | string | - | Database name |
| location | string | Resource Group location | Azure region |
| consistencyLevel | string | Session | Consistency level (Eventual, Session, Strong, etc.) |
| maxStalenessPrefix | int | 100000 | Max stale requests for BoundedStaleness |
| maxIntervalInSeconds | int | 300 | Max lag time for BoundedStaleness |
| enableAutomaticFailover | bool | false | Enable automatic failover |
| enableMultipleWriteLocations | bool | false | Enable multi-region writes |
| databaseThroughput | int | 400 | Shared database throughput in RU/s (not used in serverless mode) |
| enableServerless | bool | false | Enable serverless mode (pay-per-request) |
| enableFreeTier | bool | false | Enable free tier (1000 RU/s + 25 GB free) |
| tags | object | {} | Resource tags |

## Container Architecture

### Users Container
- **Partition Key**: `/userId`
- **Indexing**: Optimized for email lookup, active user queries, login activity
- **TTL**: Disabled (retain indefinitely)
- **Purpose**: User profiles and preferences

### Budgets Container
- **Partition Key**: `/userId`
- **Indexing**: Optimized for current budget lookup, chronological listing, fiscal reporting
- **TTL**: Disabled (historical data valuable)
- **Purpose**: Budget period management

### Envelopes Container
- **Partition Key**: `/userId`
- **Indexing**: Optimized for ordered display, category filtering, recurring templates
- **TTL**: Disabled (needed for context)
- **Purpose**: Budget categories and allocations

### Transactions Container
- **Partition Key**: `/userId`
- **Indexing**: Optimized for chronological history, envelope tracking, merchant searches
- **TTL**: Optional (7 years)
- **Purpose**: Financial transaction records

For detailed container architecture, see [Cosmos Container Architecture Documentation](../../../docs/COSMOS-CONTAINER-ARCHITECTURE.md).

## Environment-Specific Configurations

### Development
- **Mode**: Serverless (pay-per-request)
- **Free Tier**: Enabled (1000 RU/s + 25 GB free)
- **Automatic Failover**: Disabled (cost savings)
- **Consistency**: Session
- **Estimated Cost**: $0-5/month

### Staging
- **Throughput**: 400 RU/s (shared database-level)
- **Automatic Failover**: Enabled
- **Consistency**: Session
- **Estimated Cost**: ~$24/month

### Production
- **Throughput**: 1000 RU/s (shared database-level)
- **Automatic Failover**: Enabled
- **Consistency**: Session
- **Estimated Cost**: ~$58/month

## Deployment

### Using PowerShell

#### Deploy All Containers (Recommended)

```powershell
# Development
New-AzResourceGroupDeployment `
    -Name "cosmos-containers-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "cosmos-containers.json" `
    -TemplateParameterFile "parameters.dev.json"

# Staging
New-AzResourceGroupDeployment `
    -Name "cosmos-containers-deployment" `
    -ResourceGroupName "kbudget-staging-rg" `
    -TemplateFile "cosmos-containers.json" `
    -TemplateParameterFile "parameters.staging.json"

# Production
New-AzResourceGroupDeployment `
    -Name "cosmos-containers-deployment" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "cosmos-containers.json" `
    -TemplateParameterFile "parameters.prod.json"
```

#### Using Azure CLI

```bash
# Development
az deployment group create \
    --name cosmos-containers-deployment \
    --resource-group kbudget-dev-rg \
    --template-file cosmos-containers.json \
    --parameters @parameters.dev.json

# Staging
az deployment group create \
    --name cosmos-containers-deployment \
    --resource-group kbudget-staging-rg \
    --template-file cosmos-containers.json \
    --parameters @parameters.staging.json

# Production
az deployment group create \
    --name cosmos-containers-deployment \
    --resource-group kbudget-prod-rg \
    --template-file cosmos-containers.json \
    --parameters @parameters.prod.json
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| cosmosAccountEndpoint | string | Cosmos DB account endpoint URL |
| cosmosAccountId | string | Cosmos DB account resource ID |
| cosmosDatabaseId | string | Database resource ID |
| usersContainerId | string | Users container resource ID |
| budgetsContainerId | string | Budgets container resource ID |
| envelopesContainerId | string | Envelopes container resource ID |
| transactionsContainerId | string | Transactions container resource ID |
| primaryMasterKey | string | Primary master key for authentication |
| connectionString | string | Connection string with key |

## Security Features

- **TLS 1.2** encryption in transit
- **Session consistency** level for read-your-writes guarantee
- **Custom indexing policies** optimized per container
- **Keys stored in Key Vault** (via deployment script)
- **Azure Services network bypass** enabled
- **Public network access** enabled (can be restricted via firewall rules)

## Connection String

After deployment, retrieve the connection string:

```powershell
# Get deployment outputs
$outputs = (Get-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "cosmos-containers-deployment").Outputs

$connectionString = $outputs.connectionString.Value
$endpoint = $outputs.cosmosAccountEndpoint.Value

# Or get key from Key Vault
$primaryKey = Get-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "CosmosDbPrimaryKey" `
    -AsPlainText

# Full connection string
$fullConnectionString = "AccountEndpoint=$endpoint;AccountKey=$primaryKey;"
```

## Post-Deployment Tasks

### 1. Configure Firewall Rules (Optional)

```powershell
# Add IP address to Cosmos DB firewall
Update-AzCosmosDBAccount `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-cosmos" `
    -IpRangeFilter "x.x.x.x"
```

### 2. Configure VNet Integration (Optional)

```powershell
# Add virtual network rule
$vnetRule = New-AzCosmosDBVirtualNetworkRule `
    -Id "/subscriptions/{sub-id}/resourceGroups/kbudget-dev-rg/providers/Microsoft.Network/virtualNetworks/kbudget-dev-vnet/subnets/app-subnet"

Update-AzCosmosDBAccount `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-cosmos" `
    -VirtualNetworkRule @($vnetRule)
```

### 3. Store Cosmos DB Key in Key Vault

```powershell
# Get Cosmos DB primary key
$cosmosKey = (Get-AzCosmosDBAccountKey `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-cosmos").PrimaryMasterKey

# Store in Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "CosmosDbPrimaryKey" `
    -SecretValue (ConvertTo-SecureString $cosmosKey -AsPlainText -Force)
```

### 4. Seed Initial Data

Connect to the database using:
- **Azure Cosmos DB SDK** (.NET, Java, Python, Node.js)
- **Azure Portal Data Explorer**
- **Azure CLI** with `az cosmosdb sql` commands

### 5. Configure Monitoring and Alerts

```powershell
# Create alert rule for high RU consumption
New-AzMetricAlertRuleV2 `
    -Name "cosmosdb-high-ru-consumption" `
    -ResourceGroupName "kbudget-dev-rg" `
    -WindowSize 00:05:00 `
    -Frequency 00:05:00 `
    -TargetResourceId "/subscriptions/{sub-id}/resourceGroups/kbudget-dev-rg/providers/Microsoft.DocumentDB/databaseAccounts/kbudget-dev-cosmos" `
    -Condition (New-AzMetricAlertRuleV2Criteria `
        -MetricName "TotalRequestUnits" `
        -TimeAggregation Total `
        -Operator GreaterThan `
        -Threshold 800) `
    -ActionGroupId "/subscriptions/{sub-id}/resourceGroups/kbudget-dev-rg/providers/microsoft.insights/actionGroups/ops-notifications"
```

## Consistency Levels

- **Eventual**: Highest availability, lowest latency, weakest consistency
- **Session** (Recommended): Provides read-your-writes consistency within a session
- **ConsistentPrefix**: Guarantees order of writes, may lag behind
- **BoundedStaleness**: Bounded by time or version lag
- **Strong**: Strongest consistency, higher latency, lower availability

## Query Performance Tips

1. **Always include partition key** (`userId`) in queries for single-partition operations
2. **Use composite indexes** for ORDER BY queries
3. **Limit result sets** with OFFSET/LIMIT for pagination
4. **Project only needed fields** (avoid SELECT *)
5. **Cache frequently accessed data** (current budget, user preferences)
6. **Use point reads** when possible (provide both partition key and id)

Example efficient query:
```sql
-- Single-partition query with composite index support
SELECT * FROM c 
WHERE c.userId = @userId 
  AND c.budgetId = @budgetId 
  AND c.isActive = true
ORDER BY c.sortOrder ASC
```

## Cost Optimization

### Throughput Recommendations

| Environment | Strategy | RU/s | Cost |
|-------------|----------|------|------|
| Development | Serverless + Free Tier | Pay-per-request | $0-5/month |
| Staging | Shared Database | 400 RU/s | ~$24/month |
| Production | Shared Database | 1000 RU/s | ~$58/month |

### Storage Costs

Storage is charged at **~$0.25 per GB per month**:
- Development: ~1-5 GB = $0.25-1.25/month
- Staging: ~10-25 GB = $2.50-6.25/month
- Production: ~100-500 GB = $25-125/month

### Cost Reduction Tips

1. **Exclude large text fields** from indexing (description, notes)
2. **Implement TTL** for old transactions (7 years)
3. **Use serverless** for development/testing
4. **Monitor RU consumption** and right-size throughput
5. **Cache frequently accessed data** to reduce RU usage

## Monitoring

### Key Metrics

Monitor these metrics via Azure Monitor:
1. **Request Units (RU) consumption** - Alert at 80% of provisioned
2. **Throttled requests (429 errors)** - Alert on any occurrence
3. **Storage usage** - Alert at 80% of limits
4. **Query latency** - Alert if P95 > 100ms
5. **Availability** - Alert if < 99.9%

### Alert Recommendations

```powershell
# RU consumption alert
New-AzMetricAlertRuleV2 -Name "cosmos-high-ru" -Threshold 800 -MetricName "TotalRequestUnits"

# Throttling alert
New-AzMetricAlertRuleV2 -Name "cosmos-throttling" -Threshold 1 -MetricName "TotalRequests" -DimensionName "StatusCode" -DimensionValue "429"

# Storage alert
New-AzMetricAlertRuleV2 -Name "cosmos-high-storage" -Threshold 40000000000 -MetricName "DataUsage"
```

## Troubleshooting

### Common Issues

**429 (Throttling) Errors**:
- Increase provisioned throughput
- Optimize queries to reduce RU consumption
- Implement retry logic with exponential backoff

**High Latency**:
- Check if queries are cross-partition (include `userId`)
- Review indexing policy and ensure composite indexes exist
- Consider using point reads instead of queries

**Storage Limits**:
- Monitor partition sizes (50 GB max per logical partition)
- Implement data archival strategies
- Consider composite partition keys if user data exceeds limits

## Related Documentation

- [Cosmos Container Architecture](../../../docs/COSMOS-CONTAINER-ARCHITECTURE.md) - Detailed architecture documentation
- [User Data Model](../../../docs/models/USER-DATA-MODEL.md)
- [Budget Data Model](../../../docs/models/BUDGET-DATA-MODEL.md)
- [Envelope Data Model](../../../docs/models/ENVELOPE-DATA-MODEL.md)
- [Transaction Data Model](../../../docs/models/TRANSACTION-DATA-MODEL.md)
- [Azure Cosmos DB Documentation](https://docs.microsoft.com/en-us/azure/cosmos-db/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-15 | 1.0 | Initial multi-container template (cosmos-containers.json) |
| Previous | 0.x | Legacy single-container template (cosmos-database.json) |

---

**Template Owner:** Infrastructure Team  
**Review Cycle:** Quarterly  
**Next Review:** 2026-05-15
