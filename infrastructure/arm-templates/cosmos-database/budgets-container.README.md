# Budgets Container ARM Template

This directory contains ARM templates for deploying the Cosmos DB Budgets container, which stores budget periods and configurations for each user in the envelope-based budgeting system.

## Container Specifications

- **Container Name**: `budgets`
- **Partition Key**: `/id` (Hash partition)
- **Unique Keys**: None
- **Default TTL**: Disabled (-1)
- **Analytical Storage**: Disabled

## Resources Created

- **Budgets Container**: Cosmos DB container for budget period data with:
  - Partition key: `/id` (budget identifier)
  - Three composite indexes for optimized queries
  - Consistent indexing mode

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cosmosAccountName | string | - | Cosmos DB account name (required) |
| cosmosDatabaseName | string | - | Database name (required) |
| containerName | string | "budgets" | Budgets container name |
| partitionKeyPath | string | "/id" | Partition key path |
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
    {"path": "/\"_etag\"/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/isCurrent", "order": "ascending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/startDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/fiscalYear", "order": "descending"}
    ]
  ]
}
```

**Key Features**:
- **Consistent indexing**: All writes are indexed before returning
- **Automatic indexing**: New properties are automatically indexed
- **Composite indexes**: Three indexes optimized for common query patterns
- **Excluded paths**: `_etag` excluded to reduce indexing overhead

### Composite Index Purposes

1. **userId + isCurrent**: Enables efficient "find current budget" queries
2. **userId + startDate**: Enables chronological listing of budgets
3. **userId + fiscalYear**: Enables fiscal year reporting and filtering

All composite indexes enable efficient single-partition queries when filtered by userId.

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

Before deploying the Budgets container:
1. Cosmos DB account must exist
2. Cosmos DB database must exist
3. Azure PowerShell module installed (`Install-Module -Name Az`)
4. Authenticated to Azure (`Connect-AzAccount`)
5. Proper permissions (Contributor or Owner on resource group)

### PowerShell Deployment

#### Deploy to Development
```powershell
New-AzResourceGroupDeployment `
    -Name "budgets-container-deployment-dev" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/budgets-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/budgets-container.parameters.dev.json"
```

#### Deploy to Staging
```powershell
New-AzResourceGroupDeployment `
    -Name "budgets-container-deployment-staging" `
    -ResourceGroupName "kbudget-staging-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/budgets-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/budgets-container.parameters.staging.json"
```

#### Deploy to Production
```powershell
New-AzResourceGroupDeployment `
    -Name "budgets-container-deployment-prod" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/budgets-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/budgets-container.parameters.prod.json"
```

### Integrated Deployment

The Budgets container can be deployed via the main deployment script:

```powershell
# Deploy all Cosmos DB containers
.\infrastructure\arm-templates\main-deployment\Deploy-AzureResources.ps1 `
    -Environment dev `
    -ResourceTypes @("cosmos-containers")

# Deploy only specific resources including Budgets container
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
    -TemplateFile "budgets-container.json" `
    -TemplateParameterFile "budgets-container.parameters.dev.json"
```

### Post-Deployment Validation

Verify the deployment was successful:

```powershell
# 1. Check container exists
$container = Get-AzCosmosDBSqlContainer `
    -ResourceGroupName "kbudget-dev-rg" `
    -AccountName "kbudget-dev-cosmos" `
    -DatabaseName "kbudget-dev-db" `
    -Name "budgets"

# 2. Verify partition key
if ($container.Resource.PartitionKey.Paths[0] -ne "/id") {
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
if ($index1[0].Path -ne "/userId" -or $index1[1].Path -ne "/isCurrent") {
    Write-Error "First composite index incorrect"
}

$index2 = $compositeIndexes[1]
if ($index2[0].Path -ne "/userId" -or $index2[1].Path -ne "/startDate") {
    Write-Error "Second composite index incorrect"
}

$index3 = $compositeIndexes[2]
if ($index3[0].Path -ne "/userId" -or $index3[1].Path -ne "/fiscalYear") {
    Write-Error "Third composite index incorrect"
}

Write-Host "✓ All validation checks passed" -ForegroundColor Green
```

## Outputs

The template provides the following outputs:

| Output | Type | Description |
|--------|------|-------------|
| containerResourceId | string | Full resource ID of the Budgets container |
| containerName | string | Name of the deployed container |

### Accessing Outputs

```powershell
$deployment = Get-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "budgets-container-deployment-dev"

$containerResourceId = $deployment.Outputs.containerResourceId.Value
$containerName = $deployment.Outputs.containerName.Value

Write-Host "Container Resource ID: $containerResourceId"
Write-Host "Container Name: $containerName"
```

## Budget Data Model

The Budgets container stores documents with this structure:

```json
{
  "id": "budget-2026-q1-user123",
  "userId": "user123",
  "name": "2026 Q1 Budget",
  "startDate": "2026-01-01T00:00:00Z",
  "endDate": "2026-03-31T23:59:59Z",
  "fiscalYear": 2026,
  "fiscalQuarter": 1,
  "isCurrent": true,
  "budgetType": "monthly",
  "envelopes": [
    {
      "id": "envelope1",
      "categoryId": "groceries",
      "name": "Groceries",
      "budgetedAmount": 500.00,
      "currentBalance": 450.00,
      "rolloverEnabled": true
    }
  ],
  "totalBudgeted": 2500.00,
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
- `id`: Budget identifier (partition key)
- `userId`: User identifier (enables cross-partition queries)
- `startDate`: Budget period start date
- `endDate`: Budget period end date
- `isCurrent`: Flag indicating if this is the active budget

### Optional Fields
- `name`: Display name for the budget period
- `fiscalYear`: Fiscal year for reporting
- `fiscalQuarter`: Fiscal quarter (1-4)
- `budgetType`: Type of budget (monthly, quarterly, annual, custom)
- `envelopes`: Array of envelope budgets
- `totalBudgeted`: Total budgeted amount across all envelopes
- `createdAt`: ISO 8601 timestamp
- `updatedAt`: ISO 8601 timestamp

## Sample Queries

### Get Current Budget (Uses Composite Index 1)
```sql
SELECT * FROM budgets b 
WHERE b.userId = "user123" 
  AND b.isCurrent = true
```
**Expected RU consumption**: 2-3 RUs

### Get Budget History - Chronological (Uses Composite Index 2)
```sql
SELECT * FROM budgets b 
WHERE b.userId = "user123" 
ORDER BY b.startDate DESC
```
**Expected RU consumption**: 3-5 RUs for 10 items

### Get Budgets by Fiscal Year (Uses Composite Index 3)
```sql
SELECT * FROM budgets b 
WHERE b.userId = "user123" 
  AND b.fiscalYear = 2026
ORDER BY b.fiscalYear DESC
```
**Expected RU consumption**: 3-5 RUs

### Point Read (Most Efficient)
```sql
SELECT * FROM budgets b WHERE b.id = "budget-2026-q1-user123"
```
**Expected RU consumption**: 1-2 RUs

### Get Budgets for Date Range
```sql
SELECT * FROM budgets b 
WHERE b.userId = "user123" 
  AND b.startDate >= "2026-01-01T00:00:00Z"
  AND b.endDate <= "2026-12-31T23:59:59Z"
ORDER BY b.startDate DESC
```
**Expected RU consumption**: 3-5 RUs

## Best Practices

### 1. Partition Key Strategy
- Use unique budget `id` as partition key for even distribution
- Always include `userId` in queries for efficient filtering
- Each budget period is in its own logical partition
- Enables efficient point reads and updates

### 2. Query Optimization
- Use point reads when possible: `WHERE b.id = @budgetId`
- Always filter by `userId` for single-partition queries
- Composite indexes optimize ORDER BY clauses exactly as defined
- Avoid cross-partition queries when possible

### 3. Current Budget Management
- Only one budget should have `isCurrent = true` per user
- Update previous budget's `isCurrent` to `false` when creating new budget
- Use composite index 1 (userId + isCurrent) for efficient lookup

### 4. Error Handling
```csharp
try {
    await container.CreateItemAsync(budget);
} catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict) {
    // Budget with this ID already exists
    throw new DuplicateBudgetException("Budget already exists");
}
```

### 5. Indexing Considerations
- All paths indexed by default (path: "/\*")
- `_etag` excluded to reduce write costs
- Composite indexes must match query ORDER BY exactly
- Add exclusions for large nested objects if needed

## Performance Benchmarks

Expected RU consumption:

| Operation | Expected RUs |
|-----------|--------------|
| Point read (get budget by id) | 1-2 RUs |
| Get current budget | 2-3 RUs |
| List budgets chronologically (10 items) | 3-5 RUs |
| Get budgets by fiscal year | 3-5 RUs |
| Create new budget | 5-10 RUs |
| Update budget | 5-10 RUs |

## Monitoring

### Key Metrics to Track

1. **Request Units (RU) Consumption**
   - Monitor RU/s usage per operation
   - Watch for throttling (HTTP 429)

2. **Storage Usage**
   - Track container size growth
   - Monitor document count per user

3. **Query Performance**
   - P95/P99 latency for reads
   - RU consumption per query type
   - Composite index usage metrics

4. **Budget Operations**
   - Budget creation frequency
   - Current budget lookups
   - Historical budget queries

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
4. Ensure userId is included in WHERE clause
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
1. Check if query uses partition key (id) for point reads
2. Verify composite index is being used (check metrics)
3. Use Query Metrics to analyze execution plan
4. Consider adding specific composite indexes for common queries
5. Ensure userId filter is included for cross-partition queries
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
2. Exclude unnecessary paths from indexing
3. Use appropriate consistency level (Session is default)
4. Monitor and optimize high-RU queries
5. Implement caching for frequently accessed budgets
6. Archive old budgets to reduce query scope

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
   - Budget data may contain sensitive financial information
   - Implement proper RBAC
   - Consider encryption for sensitive fields

4. **Audit Logging**
   - Enable diagnostic settings
   - Log all container operations
   - Monitor for suspicious activity

## Related Documentation

- [Cosmos DB Account Template](./cosmos-database.json)
- [Users Container Template](./users-container.json)
- [Main Deployment Script](../main-deployment/Deploy-AzureResources.ps1)
- [Cosmos DB Best Practices](https://docs.microsoft.com/azure/cosmos-db/sql/best-practice-query)
- [Composite Indexes Documentation](https://docs.microsoft.com/azure/cosmos-db/index-policy#composite-indexes)
- [Indexing Policies](https://docs.microsoft.com/azure/cosmos-db/index-policy)

## Testing Checklist

- [ ] Template syntax validation passes (`Test-AzResourceGroupDeployment`)
- [ ] Deployment to dev environment succeeds
- [ ] Container visible in Azure Portal
- [ ] Partition key set to `/id`
- [ ] Can insert budget document successfully
- [ ] Query for current budget uses composite index (check metrics)
- [ ] Query ordered by date uses composite index
- [ ] Query by fiscal year uses composite index
- [ ] Multiple budgets for same user stored correctly
- [ ] isCurrent flag query is efficient (< 5 RUs)
- [ ] All three composite indexes configured correctly
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
