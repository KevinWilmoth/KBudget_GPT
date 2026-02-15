# Subtask 6: Create Users Container Infrastructure

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Create ARM template to provision the Cosmos DB Users container with appropriate partition key, indexing policy, and configuration. This container will store user profile information, preferences, and settings.

## Requirements

### ARM Template Specifications

#### Container Properties
- **Container Name**: `users`
- **Partition Key Path**: `/id`
- **Partition Key Kind**: `Hash`
- **Default TTL**: Disabled (off/-1)
- **Unique Keys**: `/email` (enforce email uniqueness)
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
      {"path": "/email", "order": "ascending"}
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

1. **users-container.json** - ARM template for Users container
2. **users-container.parameters.dev.json** - Development parameters
3. **users-container.parameters.staging.json** - Staging parameters
4. **users-container.parameters.prod.json** - Production parameters
5. **users-container.README.md** - Documentation

### ARM Template Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| cosmosAccountName | string | Cosmos DB account name | Required |
| cosmosDatabaseName | string | Database name | Required |
| containerName | string | Container name | "users" |
| partitionKeyPath | string | Partition key path | "/id" |
| throughput | int | Container throughput (if not shared) | null |
| uniqueKeyPaths | array | Paths for unique key constraints | ["/email"] |

### Template Structure

The ARM template should:
1. Reference existing Cosmos DB account and database
2. Create the Users container with specified configuration
3. Apply the indexing policy
4. Configure unique key constraints
5. Output container resource ID and name

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

Post-deployment validation:
- Container created successfully
- Partition key configured correctly
- Indexing policy applied
- Unique key constraint active
- Container queryable

## Deliverables
- [ ] ARM template file created (`users-container.json`)
- [ ] Parameter files for all environments (dev, staging, prod)
- [ ] README documentation for container
- [ ] Integration with main deployment script
- [ ] Deployment validation added
- [ ] Test deployment to dev environment successful
- [ ] Documentation includes usage examples

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
      "uniqueKeyPolicy": {
        "uniqueKeys": [
          {
            "paths": "[parameters('uniqueKeyPaths')]"
          }
        ]
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
            {"path": "/email", "order": "ascending"}
          ]
        ]
      }
    }
  }
}
```

## Deployment Commands

### PowerShell Deployment
```powershell
# Deploy Users container to dev environment
New-AzResourceGroupDeployment `
    -Name "users-container-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/users-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/users-container.parameters.dev.json"
```

### Integrated Deployment
```powershell
# Deploy all containers using main script
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("cosmos-containers")
```

## Acceptance Criteria
- ARM template validates successfully
- Template deploys without errors to dev environment
- Users container created with correct partition key (`/id`)
- Indexing policy applied correctly
- Unique key constraint on email enforced
- Container accessible via Azure Portal and SDK
- Documentation includes deployment instructions
- Parameter files configured for all environments
- Integration with main deployment script working
- Validation scripts pass all checks

## Testing Checklist
- [ ] Template syntax validation passes
- [ ] Deployment to dev environment succeeds
- [ ] Container visible in Azure Portal
- [ ] Partition key set to `/id`
- [ ] Can insert user document successfully
- [ ] Email uniqueness constraint enforced (duplicate email rejected)
- [ ] Query against composite index performs efficiently
- [ ] No errors in deployment logs
- [ ] Container properties match specifications
- [ ] Can query users by id efficiently (point read)

## Technical Notes
- Unique key constraints must be set at container creation time (cannot be added later)
- If serverless mode is enabled at database level, container inherits this
- Composite indexes improve query performance but are not required for basic functionality
- The container will inherit consistency level from the database account
- Monitor RU consumption in dev to validate indexing policy efficiency

## Dependencies
- Cosmos DB account exists (already deployed)
- Cosmos DB database exists (already deployed)
- User data model schema (Subtask 1)
- Container architecture design (Subtask 5)
- Resource group infrastructure
- Key Vault for connection strings

## Related Files
- Existing: `infrastructure/arm-templates/cosmos-database/cosmos-database.json`
- Existing: `infrastructure/arm-templates/cosmos-database/README.md`
- New: `infrastructure/arm-templates/cosmos-database/users-container.json`
- New: `infrastructure/arm-templates/cosmos-database/users-container.README.md`

## Estimated Effort
- ARM template development: 2 hours
- Parameter files creation: 1 hour
- Documentation: 1 hour
- Testing and validation: 1 hour
- Integration with deployment scripts: 1 hour
- **Total**: 6 hours
