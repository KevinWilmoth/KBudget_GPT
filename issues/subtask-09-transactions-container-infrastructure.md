# Subtask 9: Create Transactions Container Infrastructure

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Create ARM template to provision the Cosmos DB Transactions container with appropriate partition key, indexing policy, and configuration. This container will store all financial transactions including income, expenses, and transfers between envelopes.

## Requirements

### ARM Template Specifications

#### Container Properties
- **Container Name**: `transactions`
- **Partition Key Path**: `/budgetId`
- **Partition Key Kind**: `Hash`
- **Default TTL**: Optional (configurable, default disabled)
  - Can be set to 7 years (220752000 seconds) for regulatory compliance
  - Use -1 to disable (keep forever)
- **Unique Keys**: None
- **Analytical Storage**: Optional (consider for future analytics)

#### Indexing Policy
Based on Subtask 5 architecture:

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

**Indexing Rationale**:
- Exclude `description` and `notes` to reduce index size (high write volume)
- Composite index for chronological transaction listing by budget (most common query)
- Composite index for envelope transaction history (budget + envelope scoped)
- Composite index for filtering by transaction type within a budget
- Composite index for merchant-based queries within a budget
- **Note**: `/userId` is not needed in composite indexes since partition key is `/budgetId` and all queries are budget-scoped

#### Throughput Configuration
- **Development**: Serverless (no throughput configuration)
- **Staging**: Share database-level throughput (400 RU/s)
- **Production**: Share database-level throughput initially (1000 RU/s)
  - **Note**: This container will likely consume 60% of total throughput
  - Monitor and consider dedicated throughput if needed

### File Structure

Create the following files in `infrastructure/arm-templates/cosmos-database/`:

1. **transactions-container.json** - ARM template for Transactions container
2. **transactions-container.parameters.dev.json** - Development parameters
3. **transactions-container.parameters.staging.json** - Staging parameters
4. **transactions-container.parameters.prod.json** - Production parameters
5. **transactions-container.README.md** - Documentation

### ARM Template Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| cosmosAccountName | string | Cosmos DB account name | Required |
| cosmosDatabaseName | string | Database name | Required |
| containerName | string | Container name | "transactions" |
| partitionKeyPath | string | Partition key path | "/budgetId" |
| throughput | int | Container throughput (if not shared) | null |
| defaultTtl | int | Time to live in seconds (-1 = disabled) | -1 |
| enableAnalyticalStorage | bool | Enable analytical storage | false |

### Deployment Integration

The template should integrate with:
- Main deployment script (`Deploy-AzureResources.ps1`)
- Individual container deployment capability
- Validation scripts
- Parameter files for each environment

### Validation Requirements

Pre-deployment validation:
- Cosmos DB account exists
- Database exists
- Container name is unique
- Partition key path is valid
- Indexing policy syntax is correct
- TTL value is valid (-1 or positive integer)

Post-deployment validation:
- Container created successfully
- Partition key configured correctly
- All four composite indexes applied
- Excluded paths configured (description, notes)
- Container queryable
- High-volume transaction inserts work correctly
- Query performance meets benchmarks

## Deliverables
- [ ] ARM template file created (`transactions-container.json`)
- [ ] Parameter files for all environments (dev, staging, prod)
- [ ] README documentation for container
- [ ] Integration with main deployment script
- [ ] Deployment validation added
- [ ] Test deployment to dev environment successful
- [ ] Performance testing with sample data
- [ ] Sample queries and benchmarks documented

## Sample ARM Template Snippet

```json
{
  "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers",
  "apiVersion": "2023-04-15",
  "name": "[format('{0}/{1}/{2}', parameters('cosmosAccountName'), parameters('cosmosDatabaseName'), parameters('containerName'))]",
  "dependsOn": [
    "[resourceId('Microsoft.DocumentDB/databaseAccounts/sqlDatabases', parameters('cosmosAccountName'), parameters('cosmosDatabaseName'))]"
  ],
  "properties": {
    "resource": {
      "id": "[parameters('containerName')]",
      "partitionKey": {
        "paths": [
          "[parameters('partitionKeyPath')]"
        ],
        "kind": "Hash"
      },
      "defaultTtl": "[parameters('defaultTtl')]",
      "indexingPolicy": {
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
    },
    "options": {}
  }
}
```

## Sample Queries to Test

### Get Recent Transactions for Budget
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC, t.transactionTime DESC
OFFSET 0 LIMIT 50
```

### Get Envelope Transaction History
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.envelopeId = "e12e8400-e29b-41d4-a716-446655440001"
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
OFFSET 0 LIMIT 100
```

### Get Transactions by Type
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.transactionType = "expense"
  AND t.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
ORDER BY t.transactionDate DESC
OFFSET 0 LIMIT 50
```

### Get Transactions by Merchant
```sql
SELECT * FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.merchantName = "Whole Foods Market"
ORDER BY t.transactionDate DESC
```

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

### Calculate Envelope Spending
```sql
SELECT 
  SUM(t.amount) as totalSpent,
  COUNT(1) as transactionCount
FROM transactions t 
WHERE t.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND t.envelopeId = "e12e8400-e29b-41d4-a716-446655440001"
  AND t.transactionType = "expense"
  AND t.isActive = true
  AND t.isVoid = false
```

## Deployment Commands

### PowerShell Deployment
```powershell
# Deploy Transactions container to dev environment
New-AzResourceGroupDeployment `
    -Name "transactions-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/transactions-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/transactions-container.parameters.dev.json"
```

### Validation Script
```powershell
# Validate template before deployment
Test-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/transactions-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/transactions-container.parameters.dev.json"
```

## Acceptance Criteria
- ARM template validates successfully
- Template deploys without errors to dev environment
- Transactions container created with correct partition key (`/budgetId`)
- All four composite indexes applied correctly
- Excluded paths configured (description, notes not indexed)
- TTL configuration applied correctly
- Container accessible via Azure Portal and SDK
- Sample queries execute efficiently using composite indexes
- High-volume inserts (100+ transactions) work without throttling
- Documentation includes deployment instructions and query examples
- Parameter files configured for all environments
- Integration with main deployment script working
- Validation scripts pass all checks

## Testing Checklist
- [ ] Template syntax validation passes
- [ ] Deployment to dev environment succeeds
- [ ] Container visible in Azure Portal
- [ ] Partition key set to `/budgetId`
- [ ] Can insert all transaction types (income, expense, transfer)
- [ ] Excluded paths (description, notes) are not indexed
- [ ] Query ordered by date uses composite index
- [ ] Query by envelopeId uses composite index
- [ ] Query by transactionType uses composite index
- [ ] Query by merchantName uses composite index
- [ ] Bulk insert of 100 transactions completes successfully
- [ ] Date range queries perform efficiently
- [ ] Aggregation queries (SUM, COUNT) work correctly
- [ ] TTL policy applied (if configured)

## Technical Notes
- This container will have the highest write volume (frequent transactions)
- Excluding `description` and `notes` reduces write RUs significantly
- The composite index on userId + budgetId + transactionDate is critical for performance
- Consider partition heat monitoring for high-volume users
- TTL is optional but recommended for compliance (7 years for financial records)
- If analytical storage is enabled, consider for reporting and analytics
- Monitor this container closely as it will consume most RUs

## Performance Benchmarks

Expected RU consumption:
- Point read (get transaction by id): 1-2 RUs
- Recent transactions (50 items): 10-15 RUs
- Envelope history (100 items): 15-20 RUs
- Date range query (1 month): 15-25 RUs
- Insert single transaction: 8-12 RUs
- Bulk insert (100 transactions): 800-1200 RUs
- Aggregation (SUM): 20-30 RUs

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

## Dependencies
- Cosmos DB account exists (already deployed)
- Cosmos DB database exists (already deployed)
- Transaction data model schema (Subtask 4)
- Container architecture design (Subtask 5)
- Resource group infrastructure
- Key Vault for connection strings
- Azure Blob Storage for receipt attachments (optional)

## Related Files
- Existing: `infrastructure/arm-templates/cosmos-database/cosmos-database.json`
- Existing: `infrastructure/arm-templates/cosmos-database/README.md`
- New: `infrastructure/arm-templates/cosmos-database/transactions-container.json`
- New: `infrastructure/arm-templates/cosmos-database/transactions-container.README.md`

## Estimated Effort
- ARM template development: 2.5 hours
- Parameter files creation: 1 hour
- Documentation and query examples: 2 hours
- Performance testing with sample data: 2 hours
- Testing and validation: 1.5 hours
- Integration with deployment scripts: 1 hour
- **Total**: 10 hours
