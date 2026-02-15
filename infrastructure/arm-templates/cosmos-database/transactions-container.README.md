# Transactions Container ARM Template

This directory contains ARM templates for deploying the Cosmos DB Transactions container, which stores all financial transactions including income, expenses, and transfers between envelopes for the envelope-based budgeting system.

## Container Specifications

- **Container Name**: `transactions`
- **Partition Key**: `/budgetId` (Hash partition)
- **Unique Keys**: None
- **Default TTL**: Configurable (-1 = disabled, 220752000 = 7 years)
- **Analytical Storage**: Optional (disabled by default, can be enabled for analytics)

## Resources Created

- **Transactions Container**: Cosmos DB container for transaction data with:
  - Partition key: `/budgetId` (budget identifier)
  - Four composite indexes for optimized queries
  - Consistent indexing mode
  - Excluded paths for `description` and `notes` to reduce write costs (30-40% RU reduction)
  - Configurable TTL for regulatory compliance

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cosmosAccountName | string | - | Cosmos DB account name (required) |
| cosmosDatabaseName | string | - | Database name (required) |
| containerName | string | "transactions" | Transactions container name |
| partitionKeyPath | string | "/budgetId" | Partition key path |
| throughput | int | -1 | Container throughput in RU/s (-1 for shared/serverless) |
| defaultTtl | int | -1 | Time to live in seconds (-1 = disabled, 220752000 = 7 years) |
| enableAnalyticalStorage | bool | false | Enable analytical storage for analytics |
| tags | object | {} | Resource tags |

## Indexing Policy

The container uses an optimized indexing policy with composite indexes for efficient querying:

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {"path": "/*"}
  ],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"},
    {"path": "/description/?"},
    {"path": "/notes/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/envelopeId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/transactionType", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/merchantName", "order": "ascending"}
    ]
  ]
}
```

**Key Features**:
- **Consistent indexing**: All writes are indexed before returning
- **Automatic indexing**: New properties are automatically indexed
- **Composite indexes**: Four indexes optimized for common transaction query patterns
- **Excluded paths**: `_etag`, `description`, and `notes` excluded to reduce indexing overhead and write costs

### Composite Index Purposes

1. **budgetId + transactionDate**: Enables efficient chronological transaction listing by budget (most common query)
2. **budgetId + envelopeId + transactionDate**: Enables envelope transaction history queries (budget + envelope scoped)
3. **budgetId + transactionType + transactionDate**: Enables filtering by transaction type within a budget (income, expense, transfer)
4. **budgetId + merchantName**: Enables merchant-based queries within a budget

All composite indexes are scoped to `budgetId` (partition key) for single-partition query efficiency. Note that `/userId` is not needed in composite indexes since all queries are budget-scoped.

### Excluded Paths Rationale

- **description** and **notes**: Excluded to reduce index size and write costs (30-40% RU reduction)
- These fields are display-only and rarely searched
- They can still be queried, but without index optimization (full scan)
- This is critical for the Transactions container due to high write volume
- Write cost reduction outweighs occasional search cost

## Environment-Specific Configurations

### Development
- **Mode**: Serverless (inherited from database)
- **Throughput**: Shared database-level (no container-level throughput)
- **TTL**: Disabled (-1) - Keep all data for testing
- **Cost**: Pay-per-request pricing
- **Note**: Free tier enabled at account level (1000 RU/s and 25 GB free)

### Staging
- **Mode**: Provisioned throughput
- **Throughput**: Shared database-level 400 RU/s
- **TTL**: 1 year (31536000 seconds) - Limit test data accumulation
- **Cost**: ~$24/month (shared across all containers)

### Production
- **Mode**: Provisioned throughput
- **Throughput**: Shared database-level 1000 RU/s
- **TTL**: 7 years (220752000 seconds) - Regulatory compliance
- **Cost**: ~$58/month (shared across all containers)
- **Note**: This container will likely consume 60% of total throughput

## Deployment

### Prerequisites

Before deploying the Transactions container:
1. Cosmos DB account must exist
2. Cosmos DB database must exist
3. Azure PowerShell module installed (`Install-Module -Name Az`)
4. Authenticated to Azure (`Connect-AzAccount`)
5. Proper permissions (Contributor or Owner on resource group)

### PowerShell Deployment

#### Deploy to Development
```powershell
New-AzResourceGroupDeployment `
    -Name "transactions-container-deployment-dev" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/transactions-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/transactions-container.parameters.dev.json"
```

#### Deploy to Staging
```powershell
New-AzResourceGroupDeployment `
    -Name "transactions-container-deployment-staging" `
    -ResourceGroupName "kbudget-staging-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/transactions-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/transactions-container.parameters.staging.json"
```

#### Deploy to Production
```powershell
New-AzResourceGroupDeployment `
    -Name "transactions-container-deployment-prod" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/transactions-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/transactions-container.parameters.prod.json"
```

### Integrated Deployment

The Transactions container can be deployed via the main deployment script:

```powershell
# Deploy all Cosmos DB containers
.\infrastructure\arm-templates\main-deployment\Deploy-AzureResources.ps1 `
    -Environment dev `
    -ResourceTypes @("cosmos-containers")

# Deploy only specific resources including Transactions container
.\infrastructure\arm-templates\main-deployment\Deploy-AzureResources.ps1 `
    -Environment staging `
    -ResourceTypes @("cosmos-database", "cosmos-containers")
```

## Validation

### Pre-Deployment Validation

Run these checks before deploying:

```powershell
# 1. Verify Cosmos DB account exists
$cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-cosmos"
if (-not $cosmosAccount) {
    Write-Error "Cosmos DB account not found"
}

# 2. Verify database exists
$database = Get-AzCosmosDBSqlDatabase -ResourceGroupName "kbudget-dev-rg" `
    -AccountName "kbudget-dev-cosmos" `
    -Name "kbudget-dev-db"
if (-not $database) {
    Write-Error "Database not found"
}

# 3. Validate template syntax
Test-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "transactions-container.json" `
    -TemplateParameterFile "transactions-container.parameters.dev.json"
```

### Post-Deployment Validation

Verify the deployment was successful:

```powershell
# 1. Check container exists
$container = Get-AzCosmosDBSqlContainer `
    -ResourceGroupName "kbudget-dev-rg" `
    -AccountName "kbudget-dev-cosmos" `
    -DatabaseName "kbudget-dev-db" `
    -Name "transactions"

# 2. Verify partition key
if ($container.Resource.PartitionKey.Paths[0] -ne "/budgetId") {
    Write-Error "Partition key incorrect"
}

# 3. Check indexing policy
$indexingPolicy = $container.Resource.IndexingPolicy
if ($indexingPolicy.IndexingMode -ne "consistent") {
    Write-Error "Indexing mode incorrect"
}

# 4. Verify composite indexes exist
$compositeIndexes = $indexingPolicy.CompositeIndexes
if ($compositeIndexes.Count -ne 4) {
    Write-Error "Expected 4 composite indexes, found $($compositeIndexes.Count)"
}

# 5. Validate specific composite indexes
$index1 = $compositeIndexes[0]
if ($index1[0].Path -ne "/budgetId" -or $index1[1].Path -ne "/transactionDate") {
    Write-Error "First composite index incorrect"
}

$index2 = $compositeIndexes[1]
if ($index2[0].Path -ne "/budgetId" -or $index2[1].Path -ne "/envelopeId" -or $index2[2].Path -ne "/transactionDate") {
    Write-Error "Second composite index incorrect"
}

$index3 = $compositeIndexes[2]
if ($index3[0].Path -ne "/budgetId" -or $index3[1].Path -ne "/transactionType" -or $index3[2].Path -ne "/transactionDate") {
    Write-Error "Third composite index incorrect"
}

$index4 = $compositeIndexes[3]
if ($index4[0].Path -ne "/budgetId" -or $index4[1].Path -ne "/merchantName") {
    Write-Error "Fourth composite index incorrect"
}

# 6. Verify excluded paths
$excludedPaths = $indexingPolicy.ExcludedPaths | ForEach-Object { $_.Path }
if (-not ($excludedPaths -contains "/description/?")) {
    Write-Error "Description path should be excluded"
}
if (-not ($excludedPaths -contains "/notes/?")) {
    Write-Error "Notes path should be excluded"
}

# 7. Verify TTL configuration
$ttl = $container.Resource.DefaultTtl
Write-Host "TTL configured: $ttl seconds" -ForegroundColor Green

Write-Host "✓ All validation checks passed" -ForegroundColor Green
```

## Outputs

The template provides the following outputs:

| Output | Type | Description |
|--------|------|-------------|
| containerResourceId | string | Full resource ID of the Transactions container |
| containerName | string | Name of the deployed container |

### Accessing Outputs

```powershell
$deployment = Get-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "transactions-container-deployment-dev"

$containerResourceId = $deployment.Outputs.containerResourceId.Value
$containerName = $deployment.Outputs.containerName.Value

Write-Host "Container Resource ID: $containerResourceId"
Write-Host "Container Name: $containerName"
```

## Transaction Data Model

The Transactions container stores documents with this structure:

```json
{
  "id": "trans-550e8400-e29b-41d4-a716-446655440000",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "envelopeId": "e12e8400-e29b-41d4-a716-446655440001",
  "transactionType": "expense",
  "transactionDate": "2026-02-15",
  "transactionTime": "14:30:00Z",
  "amount": 45.67,
  "merchantName": "Whole Foods Market",
  "description": "Weekly groceries",
  "notes": "Bought organic vegetables",
  "isActive": true,
  "isVoid": false,
  "createdAt": "2026-02-15T14:30:00Z",
  "updatedAt": "2026-02-15T14:30:00Z",
  "_rid": "...",
  "_self": "...",
  "_etag": "...",
  "_attachments": "...",
  "_ts": 1739625000
}
```

### Required Fields
- `id`: Transaction identifier (unique within partition)
- `userId`: User identifier (enables user-scoped queries)
- `budgetId`: Budget identifier (partition key)
- `transactionType`: Type of transaction (income, expense, transfer)
- `transactionDate`: Date of transaction (ISO 8601 date)
- `amount`: Transaction amount (positive number)
- `isActive`: Whether the transaction is active
- `isVoid`: Whether the transaction has been voided

### Optional Fields
- `envelopeId`: Envelope identifier (for envelope transactions)
- `transactionTime`: Time of transaction (ISO 8601 time)
- `merchantName`: Name of merchant/payee
- `description`: Transaction description (not indexed)
- `notes`: Additional notes (not indexed)
- `createdAt`: ISO 8601 timestamp
- `updatedAt`: ISO 8601 timestamp

## Sample Queries

### Get Recent Transactions for Budget - Uses Composite Index 1
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC, t.transactionTime DESC
OFFSET 0 LIMIT 50
```
**Expected RU consumption**: 10-15 RUs for 50 items

### Get Envelope Transaction History - Uses Composite Index 2
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND t.envelopeId = "e12e8400-e29b-41d4-a716-446655440001"
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
OFFSET 0 LIMIT 100
```
**Expected RU consumption**: 15-20 RUs for 100 items

### Get Transactions by Type - Uses Composite Index 3
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND t.transactionType = "expense"
ORDER BY t.transactionDate DESC
OFFSET 0 LIMIT 50
```
**Expected RU consumption**: 12-18 RUs for 50 items

### Get Transactions by Merchant - Uses Composite Index 4
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND t.merchantName = "Whole Foods Market"
ORDER BY t.transactionDate DESC
```
**Expected RU consumption**: 8-12 RUs (depends on result set size)

### Get Transactions by Date Range
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND t.transactionDate >= "2026-02-01" 
  AND t.transactionDate <= "2026-02-15"
  AND t.isActive = true
ORDER BY t.transactionDate DESC
```
**Expected RU consumption**: 15-25 RUs (depends on result set size)

### Calculate Envelope Spending - Aggregation Query
```sql
SELECT 
  SUM(t.amount) as totalSpent,
  COUNT(1) as transactionCount
FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND t.envelopeId = "e12e8400-e29b-41d4-a716-446655440001"
  AND t.transactionType = "expense"
  AND t.isActive = true
  AND t.isVoid = false
```
**Expected RU consumption**: 20-30 RUs

### Point Read (Most Efficient)
```sql
SELECT * FROM transactions t 
WHERE t.id = "trans-550e8400-e29b-41d4-a716-446655440000"
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
```
**Expected RU consumption**: 1-2 RUs

## Best Practices

### 1. Partition Key Strategy
- Use `budgetId` as partition key for budget-scoped queries
- All transactions for a budget are in the same logical partition
- Enables efficient queries and updates within a budget
- Always include `budgetId` in WHERE clause for best performance
- Monitor partition heat for high-volume users

### 2. Query Optimization
- Use point reads when possible: `WHERE t.id = @transactionId AND t.budgetId = @budgetId`
- Always filter by `budgetId` for single-partition queries
- Composite indexes optimize ORDER BY clauses exactly as defined
- Include `userId` filter for additional security validation
- Use OFFSET/LIMIT for pagination

### 3. Write Optimization
- Batch writes when inserting multiple transactions
- Use async processing for background transaction imports
- Cache aggregated balances to avoid repeated calculations
- Monitor write RUs vs read RUs to validate excluded path strategy

### 4. Transaction Types
Supported transaction types:
- **income**: Money added to the budget
- **expense**: Money spent from an envelope
- **transfer**: Money moved between envelopes

### 5. Error Handling
```csharp
try {
    await container.CreateItemAsync(transaction, new PartitionKey(transaction.BudgetId));
} catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict) {
    // Transaction with this ID already exists
    throw new DuplicateTransactionException("Transaction already exists");
} catch (CosmosException ex) when (ex.StatusCode == (HttpStatusCode)429) {
    // Throttling - retry with exponential backoff
    await Task.Delay(TimeSpan.FromSeconds(1));
    // Retry logic here
}
```

### 6. TTL Considerations
- TTL of 7 years meets most financial record retention requirements
- After TTL expiration, transactions are automatically deleted
- For archival: Export to Azure Blob Storage before TTL
- Use Azure Data Factory for periodic archival
- Consider soft TTL (archive flag) instead of hard delete

## Performance Benchmarks

Expected RU consumption:

| Operation | Expected RUs |
|-----------|--------------|
| Point read (get transaction by id) | 1-2 RUs |
| Recent transactions (50 items) | 10-15 RUs |
| Envelope history (100 items) | 15-20 RUs |
| Date range query (1 month) | 15-25 RUs |
| Insert single transaction | 8-12 RUs |
| Bulk insert (100 transactions) | 800-1200 RUs |
| Aggregation (SUM) | 20-30 RUs |
| Transactions by type (50 items) | 12-18 RUs |
| Merchant search | 8-12 RUs |

## Scaling Considerations

### When to consider dedicated throughput:
- Transaction volume exceeds 1000 writes/day per user
- Container consistently uses > 600 RU/s
- Throttling (429 errors) occurs regularly
- Other containers are starved of throughput

### Optimization strategies:
1. **Batch writes**: Group multiple transactions in a single request
2. **Async processing**: Queue transactions for background processing
3. **Cache aggregations**: Pre-calculate and cache balances
4. **Partition monitoring**: Monitor hot partition warnings
5. **Index tuning**: Review excluded paths based on actual query patterns

## TTL Configuration

### Recommended TTL Strategy:
- **Development**: Disabled (-1) - Keep all data for testing
- **Staging**: 1 year (31536000 seconds) - Limit test data accumulation
- **Production**: 7 years (220752000 seconds) - Regulatory compliance

### TTL Implementation:
```json
"defaultTtl": 220752000  // 7 years in seconds
```

After TTL expiration, transactions are automatically deleted. For archival:
- Export to Azure Blob Storage before TTL
- Use Azure Data Factory for periodic archival
- Implement soft TTL (archive flag) instead of hard delete

## Cost Optimization

### Index Optimization:
By excluding `description` and `notes`:
- **Write cost reduction**: ~30-40% fewer RUs
- **Index storage reduction**: ~20-25% smaller index
- **Annual savings**: Estimated $200-500 for active users

### Throughput Optimization:
- Monitor actual RU consumption daily
- Scale down if consistently under 50% utilization
- Consider serverless for dev/staging (pay per use)
- Use autoscale in production if usage varies significantly
- This container will consume ~60% of total throughput

### Tips to Reduce Costs
1. Use point reads when possible (cheapest operation)
2. Exclude unnecessary paths from indexing (description, notes)
3. Use appropriate consistency level (Session is default)
4. Monitor and optimize high-RU queries
5. Implement caching for frequently accessed transactions
6. Batch insert operations when importing transactions
7. Archive old transactions to reduce query scope

## Monitoring

### Key Metrics to Track

1. **Request Units (RU) Consumption**
   - Monitor RU/s usage per operation
   - Watch for throttling (HTTP 429)
   - This container will consume most RUs

2. **Storage Usage**
   - Track container size growth
   - Monitor document count per budget
   - Plan for archival when approaching limits

3. **Query Performance**
   - P95/P99 latency for reads
   - RU consumption per query type
   - Composite index usage metrics

4. **Transaction Operations**
   - Transaction creation frequency
   - High-volume user detection
   - Query performance by transaction type

5. **Partition Health**
   - Monitor hot partition warnings
   - Track partition size and RU distribution
   - Identify users with excessive transactions

### Sample Monitoring Queries

```powershell
# Get container metrics
$metrics = Get-AzMetric `
    -ResourceId $containerResourceId `
    -MetricName "TotalRequests" `
    -StartTime (Get-Date).AddHours(-1) `
    -EndTime (Get-Date) `
    -TimeGrain 00:05:00
```

## Troubleshooting

### Container Creation Fails

**Problem**: Deployment fails with "Container already exists"
```
Solution: Container already deployed. Use portal to verify or redeploy with -Force
```

**Problem**: Deployment fails with "Database not found"
```
Solution: Deploy the database first using cosmos-database.json template
```

### Composite Index Issues

**Problem**: Queries not using composite indexes
```
Solution: 
1. Verify query ORDER BY matches composite index exactly
2. Check that query includes all index fields in correct order
3. Use Query Metrics to analyze execution plan
4. Ensure budgetId is included in WHERE clause
```

**Problem**: Query returns "Index not available" error
```
Solution: 
Wait for indexing to complete after container creation.
Check indexing progress in Azure Portal > Container > Scale & Settings
```

### Query Performance Issues

**Problem**: Queries are slow or consume many RUs
```
Solution: 
1. Check if query uses partition key (budgetId) for efficient queries
2. Verify composite index is being used (check metrics)
3. Use Query Metrics to analyze execution plan
4. Consider adding specific composite indexes for common queries
5. Ensure budgetId filter is included for single-partition queries
6. Use pagination (OFFSET/LIMIT) for large result sets
```

### High RU Consumption

**Problem**: Transaction inserts consume excessive RUs
```
Solution:
1. Verify description and notes are excluded from indexing
2. Use batch inserts for multiple transactions
3. Consider async processing for bulk imports
4. Monitor for duplicate index definitions
5. Review actual vs expected RU costs
```

### Throttling (429 Errors)

**Problem**: Getting throttled on high transaction volume
```
Solution:
1. Implement retry logic with exponential backoff
2. Consider dedicated throughput for this container
3. Use autoscale mode for variable workloads
4. Batch operations when possible
5. Monitor and optimize query patterns
```

## Security Considerations

1. **Access Control**
   - Use Azure AD authentication when possible
   - Rotate primary keys regularly
   - Store keys in Key Vault
   - Implement RBAC for container access

2. **Network Security**
   - Configure firewall rules to restrict access
   - Use private endpoints for production
   - Enable VNet integration
   - Disable public access if not needed

3. **Data Privacy**
   - Transaction data contains sensitive financial information
   - Implement proper RBAC
   - Consider encryption for sensitive fields
   - Audit access to transaction data

4. **Audit Logging**
   - Enable diagnostic settings
   - Log all container operations
   - Monitor for suspicious activity
   - Review transaction deletion patterns

## Related Documentation

- [Cosmos DB Account Template](./cosmos-database.json)
- [Budgets Container Template](./budgets-container.json)
- [Envelopes Container Template](./envelopes-container.json)
- [Users Container Template](./users-container.json)
- [Main Deployment Script](../main-deployment/Deploy-AzureResources.ps1)
- [Cosmos DB Best Practices](https://docs.microsoft.com/azure/cosmos-db/sql/best-practice-query)
- [Composite Indexes Documentation](https://docs.microsoft.com/azure/cosmos-db/index-policy#composite-indexes)
- [Indexing Policies](https://docs.microsoft.com/azure/cosmos-db/index-policy)
- [TTL in Azure Cosmos DB](https://docs.microsoft.com/azure/cosmos-db/time-to-live)

## Testing Checklist

- [ ] Template syntax validation passes (`Test-AzResourceGroupDeployment`)
- [ ] Deployment to dev environment succeeds
- [ ] Container visible in Azure Portal
- [ ] Partition key set to `/budgetId`
- [ ] Can insert all transaction types (income, expense, transfer)
- [ ] Excluded paths (description, notes) are not indexed
- [ ] Query ordered by date uses composite index (index 1)
- [ ] Query by envelopeId uses composite index (index 2)
- [ ] Query by transactionType uses composite index (index 3)
- [ ] Query by merchantName uses composite index (index 4)
- [ ] Bulk insert of 100 transactions completes successfully
- [ ] Date range queries perform efficiently
- [ ] Aggregation queries (SUM, COUNT) work correctly
- [ ] TTL policy applied (if configured)
- [ ] All sample queries execute with expected RU consumption
- [ ] No errors in deployment logs
- [ ] Container properties match specifications
- [ ] Tags applied correctly

## Support

For issues or questions:
1. Check Azure Portal diagnostics
2. Review deployment logs
3. Consult Azure Cosmos DB documentation
4. Contact DevOps team

---

**Last Updated**: February 2026  
**Version**: 1.0.0  
**Maintainer**: DevOps Team
