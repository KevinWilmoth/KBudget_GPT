# Envelopes Container ARM Template

This directory contains ARM templates for deploying the Cosmos DB Envelopes container, which stores envelope categories, allocations, and balances for each user's budget in the envelope-based budgeting system.

## Container Specifications

- **Container Name**: `envelopes`
- **Partition Key**: `/budgetId` (Hash partition)
- **Unique Keys**: None
- **Default TTL**: Disabled (-1)
- **Analytical Storage**: Disabled

## Resources Created

- **Envelopes Container**: Cosmos DB container for envelope budget data with:
  - Partition key: `/budgetId` (budget identifier)
  - Three composite indexes for optimized queries
  - Consistent indexing mode
  - Excluded paths for `description` and `notes` to reduce write costs

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cosmosAccountName | string | - | Cosmos DB account name (required) |
| cosmosDatabaseName | string | - | Database name (required) |
| containerName | string | "envelopes" | Envelopes container name |
| partitionKeyPath | string | "/budgetId" | Partition key path |
| throughput | int | -1 | Container throughput in RU/s (-1 for shared/serverless) |
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
      {"path": "/sortOrder", "order": "ascending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/categoryType", "order": "ascending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/isRecurring", "order": "ascending"}
    ]
  ]
}
```

**Key Features**:
- **Consistent indexing**: All writes are indexed before returning
- **Automatic indexing**: New properties are automatically indexed
- **Composite indexes**: Three indexes optimized for common query patterns
- **Excluded paths**: `_etag`, `description`, and `notes` excluded to reduce indexing overhead and write costs

### Composite Index Purposes

1. **budgetId + sortOrder**: Enables efficient ordered envelope display within a budget
2. **budgetId + categoryType**: Enables filtering by category type within a budget
3. **budgetId + isRecurring**: Enables finding recurring envelope templates within a budget

All composite indexes are scoped to `budgetId` (partition key) for single-partition query efficiency.

### Excluded Paths Rationale

- **description** and **notes**: Excluded to reduce index size and write costs (20-30% RU reduction)
- These fields are display-only and rarely searched
- They can still be queried, but without index optimization (full scan)
- If search becomes critical, consider Azure Cognitive Search integration

## Environment-Specific Configurations

### Development
- **Mode**: Serverless (inherited from database)
- **Throughput**: Shared database-level (no container-level throughput)
- **Cost**: Pay-per-request pricing
- **Note**: Free tier enabled at account level (1000 RU/s and 25 GB free)

### Staging
- **Mode**: Provisioned throughput
- **Throughput**: Shared database-level 400 RU/s
- **Cost**: ~$24/month (shared across all containers)

### Production
- **Mode**: Provisioned throughput
- **Throughput**: Shared database-level 1000 RU/s
- **Cost**: ~$58/month (shared across all containers)

## Deployment

### Prerequisites

Before deploying the Envelopes container:
1. Cosmos DB account must exist
2. Cosmos DB database must exist
3. Azure PowerShell module installed (`Install-Module -Name Az`)
4. Authenticated to Azure (`Connect-AzAccount`)
5. Proper permissions (Contributor or Owner on resource group)

### PowerShell Deployment

#### Deploy to Development
```powershell
New-AzResourceGroupDeployment `
    -Name "envelopes-container-deployment-dev" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/envelopes-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/envelopes-container.parameters.dev.json"
```

#### Deploy to Staging
```powershell
New-AzResourceGroupDeployment `
    -Name "envelopes-container-deployment-staging" `
    -ResourceGroupName "kbudget-staging-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/envelopes-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/envelopes-container.parameters.staging.json"
```

#### Deploy to Production
```powershell
New-AzResourceGroupDeployment `
    -Name "envelopes-container-deployment-prod" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/envelopes-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/envelopes-container.parameters.prod.json"
```

### Integrated Deployment

The Envelopes container can be deployed via the main deployment script:

```powershell
# Deploy all Cosmos DB containers
.\infrastructure\arm-templates\main-deployment\Deploy-AzureResources.ps1 `
    -Environment dev `
    -ResourceTypes @("cosmos-containers")

# Deploy only specific resources including Envelopes container
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
    -TemplateFile "envelopes-container.json" `
    -TemplateParameterFile "envelopes-container.parameters.dev.json"
```

### Post-Deployment Validation

Verify the deployment was successful:

```powershell
# 1. Check container exists
$container = Get-AzCosmosDBSqlContainer `
    -ResourceGroupName "kbudget-dev-rg" `
    -AccountName "kbudget-dev-cosmos" `
    -DatabaseName "kbudget-dev-db" `
    -Name "envelopes"

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
if ($compositeIndexes.Count -ne 3) {
    Write-Error "Expected 3 composite indexes, found $($compositeIndexes.Count)"
}

# 5. Validate specific composite indexes
$index1 = $compositeIndexes[0]
if ($index1[0].Path -ne "/budgetId" -or $index1[1].Path -ne "/sortOrder") {
    Write-Error "First composite index incorrect"
}

$index2 = $compositeIndexes[1]
if ($index2[0].Path -ne "/budgetId" -or $index2[1].Path -ne "/categoryType") {
    Write-Error "Second composite index incorrect"
}

$index3 = $compositeIndexes[2]
if ($index3[0].Path -ne "/budgetId" -or $index3[1].Path -ne "/isRecurring") {
    Write-Error "Third composite index incorrect"
}

# 6. Verify excluded paths
$excludedPaths = $indexingPolicy.ExcludedPaths | ForEach-Object { $_.Path }
if (-not ($excludedPaths -contains "/description/?")) {
    Write-Error "Description path should be excluded"
}
if (-not ($excludedPaths -contains "/notes/?")) {
    Write-Error "Notes path should be excluded"
}

Write-Host "✓ All validation checks passed" -ForegroundColor Green
```

## Outputs

The template provides the following outputs:

| Output | Type | Description |
|--------|------|-------------|
| containerResourceId | string | Full resource ID of the Envelopes container |
| containerName | string | Name of the deployed container |

### Accessing Outputs

```powershell
$deployment = Get-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "envelopes-container-deployment-dev"

$containerResourceId = $deployment.Outputs.containerResourceId.Value
$containerName = $deployment.Outputs.containerName.Value

Write-Host "Container Resource ID: $containerResourceId"
Write-Host "Container Name: $containerName"
```

## Envelope Data Model

The Envelopes container stores documents with this structure:

```json
{
  "id": "envelope-groceries-budget123",
  "userId": "user123",
  "budgetId": "budget123",
  "name": "Groceries",
  "description": "Monthly grocery budget",
  "categoryType": "essential",
  "sortOrder": 1,
  "allocatedAmount": 500.00,
  "currentBalance": 450.00,
  "spentAmount": 50.00,
  "isRecurring": true,
  "isActive": true,
  "warningThreshold": 20,
  "notes": "Includes all household grocery items",
  "createdAt": "2026-01-01T10:00:00Z",
  "updatedAt": "2026-02-15T14:30:00Z",
  "_rid": "...",
  "_self": "...",
  "_etag": "...",
  "_attachments": "...",
  "_ts": 1738156200
}
```

### Required Fields
- `id`: Envelope identifier (unique within budget)
- `userId`: User identifier (enables user-scoped queries)
- `budgetId`: Budget identifier (partition key)
- `name`: Display name for the envelope
- `allocatedAmount`: Budgeted amount for this envelope
- `currentBalance`: Current remaining balance
- `isActive`: Whether the envelope is active

### Optional Fields
- `description`: Detailed description (not indexed)
- `notes`: Additional notes (not indexed)
- `categoryType`: Category type (e.g., "essential", "discretionary")
- `sortOrder`: Display order in the UI
- `spentAmount`: Amount spent from this envelope
- `isRecurring`: Whether this is a recurring envelope template
- `warningThreshold`: Percentage threshold for low balance warnings
- `createdAt`: ISO 8601 timestamp
- `updatedAt`: ISO 8601 timestamp

## Sample Queries

### Get All Envelopes for Budget (Ordered) - Uses Composite Index 1
```sql
SELECT * FROM envelopes e 
WHERE e.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND e.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```
**Expected RU consumption**: 3-5 RUs for 20 items

### Get Envelopes by Category Type - Uses Composite Index 2
```sql
SELECT * FROM envelopes e 
WHERE e.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND e.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND e.categoryType = "essential"
  AND e.isActive = true
ORDER BY e.categoryType ASC
```
**Expected RU consumption**: 3-4 RUs

### Get Recurring Envelope Templates - Uses Composite Index 3
```sql
SELECT * FROM envelopes e 
WHERE e.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND e.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND e.isRecurring = true
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```
**Expected RU consumption**: 2-3 RUs

### Get Low Balance Envelopes
```sql
SELECT 
  e.id, 
  e.name, 
  e.currentBalance, 
  e.allocatedAmount,
  (e.currentBalance / e.allocatedAmount * 100) as percentageRemaining
FROM envelopes e 
WHERE e.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND e.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND e.isActive = true
  AND e.currentBalance / e.allocatedAmount * 100 < e.warningThreshold
```
**Expected RU consumption**: 4-6 RUs (depends on result set size)

### Point Read (Most Efficient)
```sql
SELECT * FROM envelopes e 
WHERE e.id = "envelope-groceries-budget123"
  AND e.budgetId = "budget123"
```
**Expected RU consumption**: 1-2 RUs

### Get Total Allocated and Spent
```sql
SELECT 
  e.budgetId,
  SUM(e.allocatedAmount) as totalAllocated,
  SUM(e.spentAmount) as totalSpent,
  SUM(e.currentBalance) as totalRemaining
FROM envelopes e 
WHERE e.budgetId = "budget123"
  AND e.isActive = true
GROUP BY e.budgetId
```
**Expected RU consumption**: 3-5 RUs

## Best Practices

### 1. Partition Key Strategy
- Use `budgetId` as partition key for budget-scoped queries
- All envelopes for a budget are in the same logical partition
- Enables efficient queries and updates within a budget
- Always include `budgetId` in WHERE clause for best performance

### 2. Query Optimization
- Use point reads when possible: `WHERE e.id = @envelopeId AND e.budgetId = @budgetId`
- Always filter by `budgetId` for single-partition queries
- Composite indexes optimize ORDER BY clauses exactly as defined
- Include `userId` filter for additional security validation

### 3. Envelope Ordering
- Use `sortOrder` field for drag-and-drop reordering in the UI
- Update `sortOrder` values when user reorders envelopes
- Query by `sortOrder` uses composite index for efficiency

### 4. Error Handling
```csharp
try {
    await container.CreateItemAsync(envelope, new PartitionKey(envelope.BudgetId));
} catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict) {
    // Envelope with this ID already exists
    throw new DuplicateEnvelopeException("Envelope already exists");
}
```

### 5. Indexing Considerations
- All paths indexed by default (path: "/\*")
- `_etag`, `description`, and `notes` excluded to reduce write costs
- Composite indexes must match query ORDER BY exactly
- Monitor write RUs vs read RUs to validate excluded path strategy

## Performance Benchmarks

Expected RU consumption:

| Operation | Expected RUs |
|-----------|--------------|
| Point read (get envelope by id) | 1-2 RUs |
| Get all envelopes for budget (20 items, ordered) | 3-5 RUs |
| Get envelopes by category | 3-4 RUs |
| Get recurring envelopes | 2-3 RUs |
| Update envelope balance | 5-10 RUs |
| Create new envelope | 5-10 RUs |
| Get low balance envelopes | 4-6 RUs |

## Cost Optimization Notes

By excluding `description` and `notes` from indexing:
- **Write cost reduction**: ~20-30% fewer RUs for writes
- **Index storage reduction**: ~15-20% smaller index
- **Tradeoff**: Searches on description/notes will be more expensive (full scan)

This is acceptable because:
- Envelope searches are typically by name (indexed) or category (indexed)
- Description/notes are display fields, rarely searched
- Cost savings on frequent writes outweigh occasional search cost

## Monitoring

### Key Metrics to Track

1. **Request Units (RU) Consumption**
   - Monitor RU/s usage per operation
   - Watch for throttling (HTTP 429)

2. **Storage Usage**
   - Track container size growth
   - Monitor document count per budget

3. **Query Performance**
   - P95/P99 latency for reads
   - RU consumption per query type
   - Composite index usage metrics

4. **Envelope Operations**
   - Envelope creation frequency
   - Balance update patterns
   - Query performance by category

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
```

## Cost Optimization

### Development Environment
- **Serverless mode**: Pay only for RU/s consumed
- **Free tier**: First 1000 RU/s free per month
- **Estimated cost**: $0-5/month

### Staging/Production
- **Shared throughput**: Multiple containers share database-level RU/s
- **Auto-scale**: Consider enabling for variable workloads
- **Reserved capacity**: Consider for production to save 30%+

### Tips to Reduce Costs
1. Use point reads when possible (cheapest operation)
2. Exclude unnecessary paths from indexing (description, notes)
3. Use appropriate consistency level (Session is default)
4. Monitor and optimize high-RU queries
5. Implement caching for frequently accessed envelopes
6. Archive inactive budgets to reduce query scope

## Security Considerations

1. **Access Control**
   - Use Azure AD authentication when possible
   - Rotate primary keys regularly
   - Store keys in Key Vault

2. **Network Security**
   - Configure firewall rules to restrict access
   - Use private endpoints for production
   - Enable VNet integration

3. **Data Privacy**
   - Envelope data contains financial information
   - Implement proper RBAC
   - Consider encryption for sensitive fields

4. **Audit Logging**
   - Enable diagnostic settings
   - Log all container operations
   - Monitor for suspicious activity

## Related Documentation

- [Cosmos DB Account Template](./cosmos-database.json)
- [Budgets Container Template](./budgets-container.json)
- [Users Container Template](./users-container.json)
- [Main Deployment Script](../main-deployment/Deploy-AzureResources.ps1)
- [Cosmos DB Best Practices](https://docs.microsoft.com/azure/cosmos-db/sql/best-practice-query)
- [Composite Indexes Documentation](https://docs.microsoft.com/azure/cosmos-db/index-policy#composite-indexes)
- [Indexing Policies](https://docs.microsoft.com/azure/cosmos-db/index-policy)

## Testing Checklist

- [ ] Template syntax validation passes (`Test-AzResourceGroupDeployment`)
- [ ] Deployment to dev environment succeeds
- [ ] Container visible in Azure Portal
- [ ] Partition key set to `/budgetId`
- [ ] Can insert envelope document successfully
- [ ] Excluded paths (description, notes) are not indexed
- [ ] Query ordered by sortOrder uses composite index
- [ ] Query by categoryType uses composite index
- [ ] Query for recurring envelopes uses composite index
- [ ] Can create 20+ envelopes for a budget
- [ ] Envelope reordering (updating sortOrder) works correctly
- [ ] All sample queries execute with expected RU consumption
- [ ] No errors in deployment logs
- [ ] Container properties match specifications
- [ ] Default TTL is disabled (-1)
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
