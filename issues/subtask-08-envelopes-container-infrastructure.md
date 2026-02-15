# Subtask 8: Create Envelopes Container Infrastructure

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Create ARM template to provision the Cosmos DB Envelopes container with appropriate partition key, indexing policy, and configuration. This container will store envelope categories, allocations, and balances for each user's budget.

## Requirements

### ARM Template Specifications

#### Container Properties
- **Container Name**: `envelopes`
- **Partition Key Path**: `/budgetId`
- **Partition Key Kind**: `Hash`
- **Default TTL**: Disabled (off/-1)
- **Unique Keys**: None
- **Analytical Storage**: Disabled

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

**Indexing Rationale**:
- Exclude `description` and `notes` to reduce index size and write costs
- Composite index for ordered envelope display (by sortOrder) - all queries are scoped to budgetId
- Composite index for filtering by category type within a budget
- Composite index for finding recurring envelopes within a budget
- **Note**: `/userId` is not needed in composite indexes since partition key is `/budgetId` and all queries are budget-scoped

#### Throughput Configuration
- **Development**: Serverless (no throughput configuration)
- **Staging**: Share database-level throughput (400 RU/s)
- **Production**: Share database-level throughput (1000 RU/s)

### File Structure

Create the following files in `infrastructure/arm-templates/cosmos-database/`:

1. **envelopes-container.json** - ARM template for Envelopes container
2. **envelopes-container.parameters.dev.json** - Development parameters
3. **envelopes-container.parameters.staging.json** - Staging parameters
4. **envelopes-container.parameters.prod.json** - Production parameters
5. **envelopes-container.README.md** - Documentation

### ARM Template Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| cosmosAccountName | string | Cosmos DB account name | Required |
| cosmosDatabaseName | string | Database name | Required |
| containerName | string | Container name | "envelopes" |
| partitionKeyPath | string | Partition key path | "/budgetId" |
| throughput | int | Container throughput (if not shared) | null |

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
- Excluded paths properly defined

Post-deployment validation:
- Container created successfully
- Partition key configured correctly
- All three composite indexes applied
- Excluded paths configured (description, notes)
- Container queryable
- Queries by sortOrder are efficient
- Queries by categoryType work correctly

## Deliverables
- [ ] ARM template file created (`envelopes-container.json`)
- [ ] Parameter files for all environments (dev, staging, prod)
- [ ] README documentation for container
- [ ] Integration with main deployment script
- [ ] Deployment validation added
- [ ] Test deployment to dev environment successful
- [ ] Sample queries and performance benchmarks documented

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
    }
  }
}
```

## Sample Queries to Test

### Get All Envelopes for Budget (Ordered)
```sql
SELECT * FROM envelopes e 
WHERE e.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND e.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

### Get Envelopes by Category Type
```sql
SELECT * FROM envelopes e 
WHERE e.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND e.budgetId = "b12e8400-e29b-41d4-a716-446655440001"
  AND e.categoryType = "essential"
  AND e.isActive = true
ORDER BY e.categoryType ASC
```

### Get Recurring Envelope Templates
```sql
SELECT * FROM envelopes e 
WHERE e.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND e.isRecurring = true
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

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

## Deployment Commands

### PowerShell Deployment
```powershell
# Deploy Envelopes container to dev environment
New-AzResourceGroupDeployment `
    -Name "envelopes-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/envelopes-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/envelopes-container.parameters.dev.json"
```

### Validation Script
```powershell
# Validate template before deployment
Test-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/envelopes-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/envelopes-container.parameters.dev.json"
```

## Acceptance Criteria
- ARM template validates successfully
- Template deploys without errors to dev environment
- Envelopes container created with correct partition key (`/budgetId`)
- All three composite indexes applied correctly
- Excluded paths configured (description, notes not indexed)
- Container accessible via Azure Portal and SDK
- Sample queries execute efficiently using composite indexes
- Documentation includes deployment instructions and query examples
- Parameter files configured for all environments
- Integration with main deployment script working
- Validation scripts pass all checks

## Testing Checklist
- [ ] Template syntax validation passes
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

## Technical Notes
- Excluding `description` and `notes` from indexing reduces write costs and index size
- These fields can still be queried, but without index optimization (full scan)
- If description/notes search becomes critical, consider Azure Cognitive Search integration
- The `sortOrder` field enables drag-and-drop reordering in the UI
- Composite indexes must exactly match ORDER BY clauses for optimization
- Monitor write RUs vs read RUs to validate excluded path strategy

## Performance Benchmarks

Expected RU consumption:
- Point read (get envelope by id): 1-2 RUs
- Get all envelopes for budget (20 items, ordered): 3-5 RUs
- Get envelopes by category: 3-4 RUs
- Get recurring envelopes: 2-3 RUs
- Update envelope balance: 5-10 RUs (depends on excluded fields)

## Cost Optimization Notes

By excluding `description` and `notes` from indexing:
- **Write cost reduction**: ~20-30% fewer RUs for writes
- **Index storage reduction**: ~15-20% smaller index
- **Tradeoff**: Searches on description/notes will be more expensive (full scan)

This is acceptable because:
- Envelope searches are typically by name (indexed) or category (indexed)
- Description/notes are display fields, rarely searched
- Cost savings on frequent writes outweigh occasional search cost

## Dependencies
- Cosmos DB account exists (already deployed)
- Cosmos DB database exists (already deployed)
- Envelope data model schema (Subtask 3)
- Container architecture design (Subtask 5)
- Resource group infrastructure
- Key Vault for connection strings

## Related Files
- Existing: `infrastructure/arm-templates/cosmos-database/cosmos-database.json`
- Existing: `infrastructure/arm-templates/cosmos-database/README.md`
- New: `infrastructure/arm-templates/cosmos-database/envelopes-container.json`
- New: `infrastructure/arm-templates/cosmos-database/envelopes-container.README.md`

## Estimated Effort
- ARM template development: 2 hours
- Parameter files creation: 1 hour
- Documentation and query examples: 1.5 hours
- Testing and validation: 1.5 hours
- Integration with deployment scripts: 1 hour
- **Total**: 7 hours
