# Users Container ARM Template

This directory contains ARM templates for deploying the Cosmos DB Users container, which stores user profile information, preferences, and settings.

## Container Specifications

- **Container Name**: `users`
- **Partition Key**: `/id` (Hash partition)
- **Unique Key**: `/email` (enforces email uniqueness)
- **Default TTL**: Disabled (-1)
- **Analytical Storage**: Disabled

## Resources Created

- **Users Container**: Cosmos DB container for user profile data with:
  - Partition key: `/id` (same as userId)
  - Unique key constraint: `/email`
  - Composite index on `/id` and `/email`
  - Consistent indexing mode

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cosmosAccountName | string | - | Cosmos DB account name (required) |
| cosmosDatabaseName | string | - | Database name (required) |
| containerName | string | "users" | Users container name |
| partitionKeyPath | string | "/id" | Partition key path |
| throughput | int | -1 | Container throughput in RU/s (-1 for shared/serverless) |
| uniqueKeyPaths | array | ["/email"] | Paths for unique key constraints |
| tags | object | {} | Resource tags |

## Indexing Policy

The container uses an optimized indexing policy:

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
      {"path": "/id", "order": "ascending"},
      {"path": "/email", "order": "ascending"}
    ]
  ]
}
```

**Key Features**:
- **Consistent indexing**: All writes are indexed before returning
- **Automatic indexing**: New properties are automatically indexed
- **Composite index**: Optimizes queries by id and email together
- **Excluded paths**: `_etag` excluded to reduce indexing overhead

The composite index enables efficient lookups by email within a user's partition, supporting queries like:
```sql
SELECT * FROM c WHERE c.id = @userId AND c.email = @email
```

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

## Unique Key Constraint

The `/email` unique key constraint ensures that:
- Each email address can only be used once across all users
- Duplicate email insertions will fail with HTTP 409 Conflict
- **Important**: Unique keys must be set at container creation time and cannot be changed later

### Testing Unique Key Constraint

```csharp
// First insert succeeds
var user1 = new User { id = "user1", email = "test@example.com", name = "User 1" };
await container.CreateItemAsync(user1);

// Second insert with same email fails
var user2 = new User { id = "user2", email = "test@example.com", name = "User 2" };
// Throws CosmosException with StatusCode 409 (Conflict)
await container.CreateItemAsync(user2);
```

## Deployment

### Prerequisites

Before deploying the Users container:
1. Cosmos DB account must exist
2. Cosmos DB database must exist
3. Azure PowerShell module installed (`Install-Module -Name Az`)
4. Authenticated to Azure (`Connect-AzAccount`)
5. Proper permissions (Contributor or Owner on resource group)

### PowerShell Deployment

#### Deploy to Development
```powershell
New-AzResourceGroupDeployment `
    -Name "users-container-deployment-dev" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/users-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/users-container.parameters.dev.json"
```

#### Deploy to Staging
```powershell
New-AzResourceGroupDeployment `
    -Name "users-container-deployment-staging" `
    -ResourceGroupName "kbudget-staging-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/users-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/users-container.parameters.staging.json"
```

#### Deploy to Production
```powershell
New-AzResourceGroupDeployment `
    -Name "users-container-deployment-prod" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/users-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/users-container.parameters.prod.json"
```

### Integrated Deployment

The Users container can be deployed via the main deployment script:

```powershell
# Deploy all Cosmos DB containers
.\infrastructure\arm-templates\main-deployment\Deploy-AzureResources.ps1 `
    -Environment dev `
    -ResourceTypes @("cosmos-containers")

# Deploy only specific resources including Users container
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
    -TemplateFile "users-container.json" `
    -TemplateParameterFile "users-container.parameters.dev.json"
```

### Post-Deployment Validation

Verify the deployment was successful:

```powershell
# 1. Check container exists
$container = Get-AzCosmosDBSqlContainer `
    -ResourceGroupName "kbudget-dev-rg" `
    -AccountName "kbudget-dev-cosmos" `
    -DatabaseName "kbudget-dev-db" `
    -Name "users"

# 2. Verify partition key
if ($container.Resource.PartitionKey.Paths[0] -ne "/id") {
    Write-Error "Partition key incorrect"
}

# 3. Verify unique key constraint
$uniqueKeys = $container.Resource.UniqueKeyPolicy.UniqueKeys
if ($uniqueKeys.Count -eq 0 -or $uniqueKeys[0].Paths[0] -ne "/email") {
    Write-Error "Unique key constraint not configured"
}

# 4. Check indexing policy
$indexingPolicy = $container.Resource.IndexingPolicy
if ($indexingPolicy.IndexingMode -ne "consistent") {
    Write-Error "Indexing mode incorrect"
}

# 5. Verify composite indexes exist
$compositeIndexes = $indexingPolicy.CompositeIndexes
if ($compositeIndexes.Count -eq 0) {
    Write-Error "Composite indexes not configured"
}

Write-Host "✓ All validation checks passed" -ForegroundColor Green
```

## Outputs

The template provides the following outputs:

| Output | Type | Description |
|--------|------|-------------|
| containerResourceId | string | Full resource ID of the Users container |
| containerName | string | Name of the deployed container |

### Accessing Outputs

```powershell
$deployment = Get-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "users-container-deployment-dev"

$containerResourceId = $deployment.Outputs.containerResourceId.Value
$containerName = $deployment.Outputs.containerName.Value

Write-Host "Container Resource ID: $containerResourceId"
Write-Host "Container Name: $containerName"
```

## User Data Model

The Users container stores documents with this structure:

```json
{
  "id": "user123",
  "email": "user@example.com",
  "displayName": "John Doe",
  "firstName": "John",
  "lastName": "Doe",
  "preferences": {
    "currency": "USD",
    "locale": "en-US",
    "theme": "light",
    "notifications": {
      "email": true,
      "push": false
    }
  },
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "_rid": "...",
  "_self": "...",
  "_etag": "...",
  "_attachments": "...",
  "_ts": 1705318200
}
```

### Required Fields
- `id`: User identifier (partition key)
- `email`: User email address (unique key)

### Optional Fields
- `displayName`: User's display name
- `firstName`: User's first name
- `lastName`: User's last name
- `preferences`: User preferences object
- `createdAt`: ISO 8601 timestamp
- `updatedAt`: ISO 8601 timestamp

## Sample Queries

### Point Read (Most Efficient)
```sql
-- Direct lookup by id (partition key)
SELECT * FROM c WHERE c.id = "user123"
```

### Query by Email
```sql
-- Uses composite index for efficiency
SELECT * FROM c WHERE c.email = "user@example.com"
```

### Query by Name
```sql
-- Index automatically created for displayName
SELECT * FROM c WHERE c.displayName = "John Doe"
```

### Pagination
```sql
SELECT * FROM c 
ORDER BY c.createdAt DESC
OFFSET 0 LIMIT 20
```

## Best Practices

### 1. Partition Key Strategy
- Use `id` (userId) as partition key for even distribution
- Each user's data is isolated in their own logical partition
- Enables efficient point reads and updates

### 2. Unique Key Enforcement
- Email uniqueness enforced at database level
- No application-level duplicate checks needed
- Fails fast with 409 Conflict on duplicates

### 3. Query Optimization
- Use point reads when possible: `WHERE c.id = @userId`
- Composite index optimizes queries filtering by both id and email
- Avoid cross-partition queries when possible

### 4. Error Handling
```csharp
try {
    await container.CreateItemAsync(user);
} catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict) {
    // Email already exists
    throw new DuplicateEmailException("Email already registered");
}
```

### 5. Indexing Considerations
- All paths indexed by default (path: "/\*")
- `_etag` excluded to reduce write costs
- Add exclusions for large nested objects if needed

## Monitoring

### Key Metrics to Track

1. **Request Units (RU) Consumption**
   - Monitor RU/s usage per operation
   - Watch for throttling (HTTP 429)

2. **Storage Usage**
   - Track container size growth
   - Monitor document count

3. **Query Performance**
   - P95/P99 latency for reads
   - RU consumption per query type

4. **Unique Key Violations**
   - Count of 409 Conflict errors
   - May indicate duplicate registration attempts

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

### Unique Key Constraint Issues

**Problem**: Can't add unique key after creation
```
Solution: Unique keys can only be set during container creation. 
Must recreate container with unique key or use different container.
```

**Problem**: Existing data violates unique key
```
Solution: Clean up duplicate emails before adding unique key constraint.
Run: SELECT c.email, COUNT(1) as cnt FROM c GROUP BY c.email HAVING COUNT(1) > 1
```

### Query Performance Issues

**Problem**: Queries are slow or consume many RUs
```
Solution: 
1. Check if query uses partition key (id)
2. Verify composite index is being used
3. Use Query Metrics to analyze execution plan
4. Consider adding specific composite indexes for common queries
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
5. Consider TTL for temporary data

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
   - Email addresses are PII - handle appropriately
   - Consider encryption for sensitive preferences
   - Implement proper RBAC

4. **Audit Logging**
   - Enable diagnostic settings
   - Log all container operations
   - Monitor for suspicious activity

## Related Documentation

- [Cosmos DB Account Template](./cosmos-database.json)
- [Main Deployment Script](../main-deployment/Deploy-AzureResources.ps1)
- [Cosmos DB Best Practices](https://docs.microsoft.com/azure/cosmos-db/sql/best-practice-query)
- [Unique Keys Documentation](https://docs.microsoft.com/azure/cosmos-db/unique-keys)
- [Indexing Policies](https://docs.microsoft.com/azure/cosmos-db/index-policy)

## Testing Checklist

- [ ] Template syntax validation passes (`Test-AzResourceGroupDeployment`)
- [ ] Deployment to dev environment succeeds
- [ ] Container visible in Azure Portal
- [ ] Partition key set to `/id`
- [ ] Can insert user document successfully
- [ ] Email uniqueness constraint enforced (duplicate email rejected)
- [ ] Query against composite index performs efficiently
- [ ] No errors in deployment logs
- [ ] Container properties match specifications
- [ ] Can query users by id efficiently (point read)
- [ ] Query by email returns results quickly
- [ ] Indexing policy configured correctly
- [ ] Default TTL is disabled (-1)
- [ ] Tags applied correctly

## Support

For issues or questions:
1. Check Azure Portal diagnostics
2. Review deployment logs
3. Consult Azure Cosmos DB documentation
4. Contact DevOps team

---

**Last Updated**: February 2024  
**Version**: 1.0.0  
**Maintainer**: DevOps Team
