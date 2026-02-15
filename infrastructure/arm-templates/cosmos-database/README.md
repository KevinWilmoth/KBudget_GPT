# Cosmos DB ARM Template

This directory contains ARM templates for deploying Azure Cosmos DB.

## Resources Created

- **Cosmos DB Account**: Azure Cosmos DB account with SQL API
- **Cosmos DB Database**: Application database
- **Cosmos DB Containers**: Four containers for the envelope-based budgeting data model
  - **Users Container**: User profiles and authentication data
  - **Budgets Container**: Budget definitions and settings
  - **Envelopes Container**: Budget envelopes for spending categories
  - **Transactions Container**: Financial transactions and spending records
- **Indexing Policy**: Automatic indexing for all paths

## Container Architecture

### Users Container
- **Purpose**: Store user profiles, authentication, and settings
- **Partition Key**: `/id` (user ID for optimal isolation)
- **Unique Keys**: `/email` (ensures email uniqueness)
- **Composite Indexes**: 
  - `id` + `email` (ascending)
- **Typical Queries**:
  - Get user by ID
  - Find user by email
  - List all users (admin)

### Budgets Container
- **Purpose**: Store budget definitions and settings
- **Partition Key**: `/id` (budget ID for optimal isolation)
- **Unique Keys**: None
- **Typical Queries**:
  - Get budget by ID
  - List budgets for a user
  - Get active budgets

### Envelopes Container
- **Purpose**: Store budget envelopes (spending categories)
- **Partition Key**: `/budgetId` (enables efficient budget-scoped queries)
- **Unique Keys**: None
- **Typical Queries**:
  - Get all envelopes for a budget
  - Get envelope by ID within a budget
  - Update envelope balance

### Transactions Container
- **Purpose**: Store financial transactions and spending records
- **Partition Key**: `/budgetId` (enables efficient budget-scoped queries)
- **Unique Keys**: None
- **Typical Queries**:
  - Get all transactions for a budget
  - Get transactions for an envelope
  - Get transactions by date range
  - Calculate spending totals

## Partition Key Strategy

The partition key strategy is optimized for common query patterns:

- **Users and Budgets** use `/id` as partition key:
  - Provides strong isolation per entity
  - Efficient point reads by ID
  - Suitable for single-document operations

- **Envelopes and Transactions** use `/budgetId` as partition key:
  - Enables efficient queries across all envelopes in a budget
  - Enables efficient queries across all transactions in a budget
  - Optimizes for budget-scoped operations
  - Reduces cross-partition queries for common use cases

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

### Using PowerShell - Main Deployment Script

The recommended way to deploy all containers is using the main deployment script:

```powershell
# Deploy all Cosmos DB containers to dev environment
cd infrastructure/arm-templates/main-deployment
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("cosmos-containers")
```

### Using PowerShell - Individual Container

Deploy a single container:

```powershell
# Deploy Users container
New-AzResourceGroupDeployment `
    -Name "users-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "users-container.json" `
    -TemplateParameterFile "users-container.parameters.dev.json"

# Deploy Budgets container
New-AzResourceGroupDeployment `
    -Name "budgets-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "budgets-container.json" `
    -TemplateParameterFile "budgets-container.parameters.dev.json"

# Deploy Envelopes container
New-AzResourceGroupDeployment `
    -Name "envelopes-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "envelopes-container.json" `
    -TemplateParameterFile "envelopes-container.parameters.dev.json"

# Deploy Transactions container
New-AzResourceGroupDeployment `
    -Name "transactions-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "transactions-container.json" `
    -TemplateParameterFile "transactions-container.parameters.dev.json"
```

### Using PowerShell - Cosmos DB Account and Database

Deploy the Cosmos DB account and database (required before containers):

```powershell
New-AzResourceGroupDeployment `
    -Name "cosmos-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "cosmos-database.json" `
    -TemplateParameterFile "parameters.dev.json"
```

### Deployment Order

Containers must be deployed after the Cosmos DB account and database:

1. **Cosmos DB Account** (via cosmos-database.json)
2. **Cosmos DB Database** (via cosmos-database.json)
3. **Containers** (can be deployed in any order or in parallel):
   - Users container
   - Budgets container
   - Envelopes container
   - Transactions container

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

## Post-Deployment

1. **Verify containers were created**:
   ```powershell
   # Get all containers in the database
   Get-AzCosmosDBSqlContainer `
       -ResourceGroupName "kbudget-dev-rg" `
       -AccountName "kbudget-dev-cosmos" `
       -DatabaseName "kbudget-dev-db" | Format-Table
   
   # Check specific container
   Get-AzCosmosDBSqlContainer `
       -ResourceGroupName "kbudget-dev-rg" `
       -AccountName "kbudget-dev-cosmos" `
       -DatabaseName "kbudget-dev-db" `
       -Name "users"
   ```

2. **Query Examples**:

   **Users Container**:
   ```sql
   -- Get user by ID
   SELECT * FROM c WHERE c.id = 'user-123'
   
   -- Find user by email
   SELECT * FROM c WHERE c.email = 'user@example.com'
   
   -- Get all active users
   SELECT * FROM c WHERE c.isActive = true
   ```

   **Budgets Container**:
   ```sql
   -- Get budget by ID
   SELECT * FROM c WHERE c.id = 'budget-456'
   
   -- Get all budgets for a user
   SELECT * FROM c WHERE c.userId = 'user-123'
   
   -- Get active budgets
   SELECT * FROM c WHERE c.isActive = true AND c.userId = 'user-123'
   ```

   **Envelopes Container**:
   ```sql
   -- Get all envelopes for a budget (efficient - same partition)
   SELECT * FROM c WHERE c.budgetId = 'budget-456'
   
   -- Get specific envelope
   SELECT * FROM c WHERE c.budgetId = 'budget-456' AND c.id = 'envelope-789'
   
   -- Get envelopes by category
   SELECT * FROM c WHERE c.budgetId = 'budget-456' AND c.category = 'Housing'
   
   -- Get overspent envelopes
   SELECT * FROM c WHERE c.budgetId = 'budget-456' AND c.balance < 0
   ```

   **Transactions Container**:
   ```sql
   -- Get all transactions for a budget (efficient - same partition)
   SELECT * FROM c WHERE c.budgetId = 'budget-456'
   
   -- Get transactions for an envelope
   SELECT * FROM c WHERE c.budgetId = 'budget-456' AND c.envelopeId = 'envelope-789'
   
   -- Get transactions by date range
   SELECT * FROM c 
   WHERE c.budgetId = 'budget-456' 
   AND c.date >= '2024-01-01' 
   AND c.date <= '2024-01-31'
   
   -- Calculate total spending
   SELECT SUM(c.amount) as totalSpent 
   FROM c 
   WHERE c.budgetId = 'budget-456' 
   AND c.type = 'debit'
   ```

3. **Configure firewall rules** for specific IPs (optional):
   ```powershell
   # Add IP address to Cosmos DB firewall
   $cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-cosmos"
   Update-AzCosmosDBAccount -ResourceGroupName "kbudget-dev-rg" `
       -Name "kbudget-dev-cosmos" `
       -IpRangeFilter "x.x.x.x"
   ```

4. **Configure VNet integration** (optional):
   ```powershell
   # Add virtual network rule
   $vnetRule = New-AzCosmosDBVirtualNetworkRule `
       -Id "/subscriptions/{sub-id}/resourceGroups/kbudget-dev-rg/providers/Microsoft.Network/virtualNetworks/kbudget-dev-vnet/subnets/app-subnet"
   
   Update-AzCosmosDBAccount -ResourceGroupName "kbudget-dev-rg" `
       -Name "kbudget-dev-cosmos" `
       -VirtualNetworkRule @($vnetRule)
   ```

5. **Seed initial data**:
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
