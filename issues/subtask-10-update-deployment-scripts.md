# Subtask 10: Update Main Deployment Scripts for New Containers

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Update the main deployment scripts to include the new Cosmos DB containers (Users, Budgets, Envelopes, Transactions) in the automated infrastructure deployment pipeline. This ensures all containers are created consistently across dev, staging, and production environments.

## Requirements

### Update Deploy-AzureResources.ps1

Modify the main deployment script to:
1. Add new container deployment steps
2. Integrate container parameter files
3. Add validation for container creation
4. Store container outputs in Key Vault
5. Generate deployment summary including containers

### Files to Update

1. **infrastructure/arm-templates/main-deployment/Deploy-AzureResources.ps1**
   - Add container deployment logic
   - Add parameter handling for containers
   - Add validation checks
   - Add output collection

2. **infrastructure/arm-templates/cosmos-database/README.md**
   - Update with new container information
   - Add deployment instructions
   - Document container architecture

3. **infrastructure/arm-templates/main-deployment/README.md**
   - Update deployment guide
   - Add container deployment examples

### Integration Requirements

#### 1. Resource Type Parameter
Add `cosmos-containers` to the `-ResourceTypes` parameter:

```powershell
[Parameter()]
[ValidateSet("all", "vnet", "keyvault", "storage", "cosmos", "cosmos-containers", "appservice", "functions", "monitoring")]
[string[]]$ResourceTypes = @("all")
```

#### 2. Container Deployment Logic
Add deployment steps for each container:

```powershell
# Deploy Cosmos DB Containers
if ($ResourceTypes -contains "cosmos-containers" -or $ResourceTypes -contains "all") {
    Write-Host "Deploying Cosmos DB containers..." -ForegroundColor Cyan
    
    $containers = @("users", "budgets", "envelopes", "transactions")
    
    foreach ($container in $containers) {
        $containerTemplatePath = Join-Path $cosmosDbPath "$container-container.json"
        $containerParamsPath = Join-Path $cosmosDbPath "$container-container.parameters.$Environment.json"
        
        if (Test-Path $containerTemplatePath) {
            Write-Host "  Deploying $container container..." -ForegroundColor Gray
            
            $containerDeployment = New-AzResourceGroupDeployment `
                -Name "$container-container-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                -ResourceGroupName $resourceGroupName `
                -TemplateFile $containerTemplatePath `
                -TemplateParameterFile $containerParamsPath `
                -ErrorAction Stop
            
            Write-Host "  ✓ $container container deployed successfully" -ForegroundColor Green
        } else {
            Write-Warning "  Template not found: $containerTemplatePath"
        }
    }
}
```

#### 3. Validation Steps
Add pre-deployment validation:

```powershell
function Test-CosmosContainerPrerequisites {
    param(
        [string]$ResourceGroupName,
        [string]$CosmosAccountName,
        [string]$DatabaseName
    )
    
    Write-Host "Validating Cosmos DB prerequisites..." -ForegroundColor Cyan
    
    # Check if Cosmos DB account exists
    $cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroupName -Name $CosmosAccountName -ErrorAction SilentlyContinue
    if (-not $cosmosAccount) {
        throw "Cosmos DB account '$CosmosAccountName' not found in resource group '$ResourceGroupName'"
    }
    
    # Check if database exists
    $database = Get-AzCosmosDBSqlDatabase -ResourceGroupName $ResourceGroupName -AccountName $CosmosAccountName -Name $DatabaseName -ErrorAction SilentlyContinue
    if (-not $database) {
        throw "Cosmos DB database '$DatabaseName' not found in account '$CosmosAccountName'"
    }
    
    Write-Host "✓ Cosmos DB prerequisites validated" -ForegroundColor Green
    return $true
}
```

#### 4. Post-Deployment Validation
Add container verification:

```powershell
function Test-CosmosContainers {
    param(
        [string]$ResourceGroupName,
        [string]$CosmosAccountName,
        [string]$DatabaseName,
        [string[]]$ExpectedContainers
    )
    
    Write-Host "Validating Cosmos DB containers..." -ForegroundColor Cyan
    
    foreach ($containerName in $ExpectedContainers) {
        $container = Get-AzCosmosDBSqlContainer `
            -ResourceGroupName $ResourceGroupName `
            -AccountName $CosmosAccountName `
            -DatabaseName $DatabaseName `
            -Name $containerName `
            -ErrorAction SilentlyContinue
        
        if ($container) {
            Write-Host "  ✓ Container '$containerName' exists" -ForegroundColor Green
            
            # Validate partition key
            $partitionKey = $container.Resource.PartitionKey.Paths[0]
            
            # Validate partition key based on container name (using optimized strategy from Subtask 13)
            $expectedPartitionKey = switch ($containerName) {
                "users" { "/id" }
                "budgets" { "/id" }
                "envelopes" { "/budgetId" }
                "transactions" { "/budgetId" }
                default { "/userId" }  # fallback for any other containers
            }
            
            if ($partitionKey -eq $expectedPartitionKey) {
                Write-Host "    ✓ Partition key: $partitionKey" -ForegroundColor Gray
            } else {
                Write-Warning "    Unexpected partition key: $partitionKey (expected $expectedPartitionKey)"
            }
        } else {
            Write-Warning "  ✗ Container '$containerName' not found"
        }
    }
}
```

### Deployment Order

Ensure containers are deployed in the correct order:
1. Cosmos DB account (already exists)
2. Cosmos DB database (already exists)
3. **New**: Users container
4. **New**: Budgets container
5. **New**: Envelopes container
6. **New**: Transactions container

### Output Collection

Collect and store container information:

```powershell
$deploymentOutputs = @{
    cosmosEndpoint = $cosmosAccount.DocumentEndpoint
    containers = @{
        users = @{
            id = "/subscriptions/.../containers/users"
            partitionKey = "/userId"
        }
        budgets = @{
            id = "/subscriptions/.../containers/budgets"
            partitionKey = "/userId"
        }
        envelopes = @{
            id = "/subscriptions/.../containers/envelopes"
            partitionKey = "/userId"
        }
        transactions = @{
            id = "/subscriptions/.../containers/transactions"
            partitionKey = "/userId"
        }
    }
}

# Save to file
$outputPath = Join-Path $outputDir "cosmos-containers-$Environment.json"
$deploymentOutputs | ConvertTo-Json -Depth 10 | Out-File $outputPath
```

### Error Handling

Add error handling for container deployment:

```powershell
try {
    # Deploy container
    $deployment = New-AzResourceGroupDeployment @deployParams
} catch {
    Write-Error "Failed to deploy $container container: $_"
    
    # Check for specific errors
    if ($_.Exception.Message -like "*already exists*") {
        Write-Warning "Container already exists. Skipping..."
        continue
    } elseif ($_.Exception.Message -like "*quota exceeded*") {
        Write-Error "Cosmos DB quota exceeded. Check account limits."
        throw
    } else {
        throw
    }
}
```

### Documentation Updates

Update documentation files:

1. **Main Deployment README**:
   - Add section on container deployment
   - Include examples of deploying specific containers
   - Document validation steps

2. **Cosmos DB README**:
   - List all containers with descriptions
   - Document partition keys
   - Include query examples

3. **PowerShell Deployment Guide**:
   - Add container-specific deployment examples
   - Document troubleshooting steps

## Deliverables
- [ ] Deploy-AzureResources.ps1 updated with container deployment logic
- [ ] Container validation functions added
- [ ] Error handling implemented
- [ ] Output collection configured
- [ ] Documentation updated (all READMEs)
- [ ] Deployment tested in dev environment
- [ ] All four containers deploy successfully
- [ ] Validation scripts pass
- [ ] Deployment outputs saved correctly

## Sample Deployment Commands

### Deploy All Containers
```powershell
# Deploy all Cosmos containers to dev environment
.\Deploy-AzureResources.ps1 -Environment dev -ResourceTypes @("cosmos-containers")
```

### Deploy Specific Container
```powershell
# Deploy only Users container
New-AzResourceGroupDeployment `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "infrastructure/arm-templates/cosmos-database/users-container.json" `
    -TemplateParameterFile "infrastructure/arm-templates/cosmos-database/users-container.parameters.dev.json"
```

### Deploy with Validation
```powershell
# Deploy with pre and post validation
.\Deploy-AzureResources.ps1 `
    -Environment dev `
    -ResourceTypes @("cosmos-containers") `
    -Validate
```

## Acceptance Criteria
- Main deployment script successfully deploys all four containers
- Container deployment can be run independently
- Pre-deployment validation checks pass
- Post-deployment validation verifies container creation
- Error handling catches and reports deployment failures
- Deployment outputs are collected and saved
- Documentation is updated with clear instructions
- Script works across all environments (dev, staging, prod)
- Idempotent deployment (safe to run multiple times)
- Integration with existing deployment pipeline works
- All validation functions execute successfully

## Testing Checklist
- [ ] Script syntax validation passes
- [ ] Deployment to clean dev environment succeeds
- [ ] All four containers created correctly
- [ ] Re-running deployment doesn't cause errors (idempotent)
- [ ] Validation functions detect missing prerequisites
- [ ] Error handling catches deployment failures
- [ ] Output files generated correctly
- [ ] Documentation is clear and accurate
- [ ] Works with `-ResourceTypes @("all")`
- [ ] Works with `-ResourceTypes @("cosmos-containers")`
- [ ] Individual container deployment works
- [ ] Deployment to staging environment succeeds
- [ ] Parameter files work for all environments

## Technical Notes
- Container deployment depends on Cosmos DB account and database
- Deployment should be idempotent (check if container exists first)
- Use timestamped deployment names to avoid conflicts
- Collect deployment outputs for troubleshooting
- Log all operations for audit trail
- Consider parallel deployment of containers (they're independent)

## Integration Points

### CI/CD Pipeline
- Add container deployment step to GitHub Actions workflow
- Validate containers after Cosmos DB deployment
- Store outputs as pipeline artifacts

### Monitoring
- Add container metrics collection
- Configure alerts for container health
- Monitor RU consumption per container

### Testing
- Add Pester tests for container deployment
- Validate container properties programmatically
- Test rollback scenarios

## Dependencies
- Subtask 6: Users Container Infrastructure
- Subtask 7: Budgets Container Infrastructure
- Subtask 8: Envelopes Container Infrastructure
- Subtask 9: Transactions Container Infrastructure
- Existing Cosmos DB account and database
- Main deployment script infrastructure
- PowerShell Az module

## Related Files
- `infrastructure/arm-templates/main-deployment/Deploy-AzureResources.ps1`
- `infrastructure/arm-templates/main-deployment/README.md`
- `infrastructure/arm-templates/cosmos-database/README.md`
- `docs/POWERSHELL-DEPLOYMENT-GUIDE.md`
- `.github/workflows/*.yml` (if CI/CD integration)

## Estimated Effort
- Script updates: 3 hours
- Validation functions: 2 hours
- Error handling: 1 hour
- Documentation updates: 2 hours
- Testing across environments: 2 hours
- Integration testing: 1 hour
- **Total**: 11 hours
