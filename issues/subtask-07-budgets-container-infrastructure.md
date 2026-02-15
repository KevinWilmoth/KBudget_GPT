# Subtask 7: Create Budgets Container Infrastructure

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Create ARM template to provision the Cosmos DB Budgets container with appropriate partition key, indexing policy, and configuration. This container will store budget periods and configurations for each user.

## Requirements

### ARM Template Specifications

#### Container Properties
- **Container Name**: `budgets`
- **Partition Key Path**: `/userId`
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

#### Throughput Configuration
- **Development**: Serverless (no throughput configuration)
- **Staging**: Share database-level throughput (400 RU/s)
- **Production**: Share database-level throughput (1000 RU/s)

### File Structure

Create the following files in `infrastructure/arm-templates/cosmos-database/`:

1. **budgets-container.json** - ARM template for Budgets container
2. **budgets-container.parameters.dev.json** - Development parameters
3. **budgets-container.parameters.staging.json** - Staging parameters
4. **budgets-container.parameters.prod.json** - Production parameters
5. **budgets-container.README.md** - Documentation

### ARM Template Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| cosmosAccountName | string | Cosmos DB account name | Required |
| cosmosDatabaseName | string | Database name | Required |
| containerName | string | Container name | "budgets" |
| partitionKeyPath | string | Partition key path | "/userId" |
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
- Composite indexes are properly structured

Post-deployment validation:
- Container created successfully
- Partition key configured correctly
- All three composite indexes applied
- Container queryable
- Can query by isCurrent flag efficiently
- Can query by date range efficiently

## Deliverables
- [ ] ARM template file created (`budgets-container.json`)
- [ ] Parameter files for all environments (dev, staging, prod)
- [ ] README documentation for container
- [ ] Integration with main deployment script
- [ ] Deployment validation added
- [ ] Test deployment to dev environment successful
- [ ] Sample queries documented

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
    }
  }
}
```

## Sample Queries to Test

### Get Current Budget
```sql
SELECT * FROM budgets b 
WHERE b.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND b.isCurrent = true
```

### Get Budget History (Chronological)
```sql
SELECT * FROM budgets b 
WHERE b.userId = "550e8400-e29b-41d4-a716-446655440000" 
ORDER BY b.startDate DESC
```

### Get Budgets by Fiscal Year
```sql
SELECT * FROM budgets b 
WHERE b.userId = "550e8400-e29b-41d4-a716-446655440000" 
  AND b.fiscalYear = 2026
ORDER BY b.fiscalYear DESC
```

## Deployment Commands

### PowerShell Deployment
```powershell
# Deploy Budgets container to dev environment
New-AzResourceGroupDeployment `
    -Name "budgets-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/budgets-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/budgets-container.parameters.dev.json"
```

### Validation Script
```powershell
# Validate template before deployment
Test-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/budgets-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/budgets-container.parameters.dev.json"
```

## Acceptance Criteria
- ARM template validates successfully
- Template deploys without errors to dev environment
- Budgets container created with correct partition key (`/userId`)
- All three composite indexes applied correctly
- Container accessible via Azure Portal and SDK
- Sample queries execute efficiently (< 10 RUs)
- Documentation includes deployment instructions and query examples
- Parameter files configured for all environments
- Integration with main deployment script working
- Validation scripts pass all checks

## Testing Checklist
- [ ] Template syntax validation passes
- [ ] Deployment to dev environment succeeds
- [ ] Container visible in Azure Portal
- [ ] Partition key set to `/userId`
- [ ] Can insert budget document successfully
- [ ] Query for current budget uses composite index (check metrics)
- [ ] Query ordered by date uses composite index
- [ ] Query by fiscal year uses composite index
- [ ] Multiple budgets for same user stored correctly
- [ ] isCurrent flag query is efficient (< 5 RUs)

## Technical Notes
- The composite indexes must match query ORDER BY clauses exactly
- Composite index on userId + isCurrent enables efficient "find current budget" queries
- Composite index on userId + startDate enables chronological listing
- Composite index on userId + fiscalYear enables fiscal reporting
- All queries should be single-partition queries (include userId in WHERE clause)
- Monitor index metrics in Azure Portal to validate performance

## Performance Benchmarks

Expected RU consumption:
- Point read (get budget by id): 1-2 RUs
- Get current budget: 2-3 RUs
- List budgets chronologically (10 items): 3-5 RUs
- Get budgets by fiscal year: 3-5 RUs

## Dependencies
- Cosmos DB account exists (already deployed)
- Cosmos DB database exists (already deployed)
- Budget data model schema (Subtask 2)
- Container architecture design (Subtask 5)
- Resource group infrastructure
- Key Vault for connection strings

## Related Files
- Existing: `infrastructure/arm-templates/cosmos-database/cosmos-database.json`
- Existing: `infrastructure/arm-templates/cosmos-database/README.md`
- New: `infrastructure/arm-templates/cosmos-database/budgets-container.json`
- New: `infrastructure/arm-templates/cosmos-database/budgets-container.README.md`

## Estimated Effort
- ARM template development: 2 hours
- Parameter files creation: 1 hour
- Documentation and query examples: 1 hour
- Testing and validation: 1 hour
- Integration with deployment scripts: 1 hour
- **Total**: 6 hours
