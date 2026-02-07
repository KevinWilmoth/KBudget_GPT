# Quick Reference: Deployment Validation

This is a quick reference for using the PowerShell deployment validation features.

## Quick Commands

### Run Deployment with Validation
```powershell
# Deploy to development with automatic validation
.\Deploy-AzureResources.ps1 -Environment dev

# The script automatically:
# ✓ Deploys resources
# ✓ Validates deployment
# ✓ Exports results
# ✓ Sends alerts on failure
```

### Run Tests Locally
```powershell
# Install Pester (one-time)
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser

# Run all tests
cd infrastructure/arm-templates/main-deployment
Invoke-Pester -Path Deploy-AzureResources.Tests.ps1

# Run tests with detailed output
$config = New-PesterConfiguration
$config.Run.Path = "Deploy-AzureResources.Tests.ps1"
$config.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $config
```

### Manual Validation
```powershell
# Import validation module
Import-Module ./Deployment-Validation.psm1

# Validate all resources in development
$results = Test-DeploymentResources -Environment "dev"

# Display validation summary
Write-DeploymentSummary -ValidationResults $results

# Send alert if failed
if ($results.OverallStatus -eq "Failed") {
    Send-DeploymentAlert -ValidationResults $results -AlertLevel "Critical"
}
```

### Check Deployment Status
```powershell
# Import validation module
Import-Module ./Deployment-Validation.psm1

# Check deployment status
$status = Get-DeploymentStatus `
    -ResourceGroupName "kbudget-dev-rg" `
    -DeploymentName "vnet-deployment-20240207"

Write-Host "Status: $($status.ProvisioningState)"
Write-Host "Duration: $($status.Duration) minutes"
```

### View Deployment Outputs
```powershell
# View latest deployment results
$results = Get-Content ./outputs/deployment-results_dev_latest.json | ConvertFrom-Json

# View resource IDs
$results.DeploymentDetails | ForEach-Object { 
    $_.PSObject.Properties | ForEach-Object {
        Write-Host "$($_.Name): $($_.Value.DeploymentName) - $($_.Value.ProvisioningState)"
    }
}
```

## Validation Module Functions

| Function | Purpose |
|----------|---------|
| `Get-DeploymentStatus` | Get status of an Azure deployment |
| `Test-ResourceGroupExists` | Validate resource group existence |
| `Test-VirtualNetworkExists` | Validate virtual network existence |
| `Test-KeyVaultExists` | Validate Key Vault existence |
| `Test-StorageAccountExists` | Validate storage account existence |
| `Test-SqlServerExists` | Validate SQL Server existence |
| `Test-AppServiceExists` | Validate App Service existence |
| `Test-FunctionAppExists` | Validate Function App existence |
| `Test-DeploymentResources` | Comprehensive deployment validation |
| `Export-DeploymentOutputs` | Export deployment outputs to JSON |
| `Write-DeploymentSummary` | Display validation summary |
| `Send-DeploymentAlert` | Send alert for failures |

## Expected Resource Names

| Resource Type | Naming Pattern | Example (dev) |
|--------------|----------------|---------------|
| Resource Group | `kbudget-{env}-rg` | kbudget-dev-rg |
| Virtual Network | `kbudget-{env}-vnet` | kbudget-dev-vnet |
| Key Vault | `kbudget-{env}-kv` | kbudget-dev-kv |
| Storage Account | `kbudget{env}storage` | kbudgetdevstorage |
| SQL Server | `kbudget-{env}-sql` | kbudget-dev-sql |
| App Service | `kbudget-{env}-app` | kbudget-dev-app |
| Function App | `kbudget-{env}-func` | kbudget-dev-func |

## Output Files

### Location
`infrastructure/arm-templates/main-deployment/outputs/`

### Files
- `deployment-results_{environment}_{timestamp}.json` - Timestamped results
- `deployment-results_{environment}_latest.json` - Latest results (quick access)

### Structure
```json
{
  "Environment": "dev",
  "Timestamp": "20240207_143000",
  "DeploymentTime": "2024-02-07 14:30:00",
  "ResourceGroupName": "kbudget-dev-rg",
  "Location": "eastus",
  "ResourcesDeployed": [...],
  "DeploymentDetails": {...}
}
```

## CI/CD Workflow

The GitHub Actions workflow runs automatically when:
- Pushing to `main` or `develop` branches
- Opening pull requests
- Manual workflow trigger

### Workflow Jobs
1. **Validate Scripts** - Syntax, tests, templates
2. **Security Scan** - PSScriptAnalyzer, secrets detection
3. **Notify Status** - Overall validation status

### Viewing Results
1. Go to repository on GitHub
2. Click **Actions** tab
3. Select **PowerShell Deployment Validation** workflow
4. View job results and download artifacts

## Troubleshooting

### Validation Fails After Successful Deployment
**Issue**: Resources deployed but validation fails

**Solution**:
```powershell
# Wait a few minutes for Azure to fully provision
Start-Sleep -Seconds 60

# Run validation again manually
Import-Module ./Deployment-Validation.psm1
$results = Test-DeploymentResources -Environment "dev"
Write-DeploymentSummary -ValidationResults $results
```

### Tests Fail Locally
**Issue**: Pester tests fail with errors

**Solution**:
```powershell
# Ensure Pester 5.0+ is installed
Get-Module -ListAvailable Pester

# Update Pester if needed
Install-Module -Name Pester -Force -SkipPublisherCheck -AllowClobber

# Run tests with detailed output to see specific failures
$config = New-PesterConfiguration
$config.Run.Path = "Deploy-AzureResources.Tests.ps1"
$config.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $config
```

### Missing Output Files
**Issue**: Deployment results not exported

**Solution**:
```powershell
# Check if outputs directory exists
Test-Path ./outputs

# Create outputs directory if missing
New-Item -ItemType Directory -Path ./outputs -Force

# Re-run deployment
.\Deploy-AzureResources.ps1 -Environment dev
```

## Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success - All resources deployed and validated |
| 1 | Failure - Deployment failed or validation failed |

## Best Practices

1. ✅ Always test with `-WhatIf` first
2. ✅ Run Pester tests before committing changes
3. ✅ Review validation summaries after each deployment
4. ✅ Keep deployment output files for audit trail
5. ✅ Monitor CI/CD workflow results
6. ✅ Address validation failures immediately
7. ✅ Use consistent resource naming patterns
8. ✅ Archive logs for troubleshooting

## Getting Help

- **Full Documentation**: [Deployment Validation Guide](DEPLOYMENT-VALIDATION-GUIDE.md)
- **Deployment Guide**: [PowerShell Deployment Guide](../POWERSHELL-DEPLOYMENT-GUIDE.md)
- **Logs Directory**: `infrastructure/arm-templates/main-deployment/logs/`
- **Outputs Directory**: `infrastructure/arm-templates/main-deployment/outputs/`

---

**Last Updated**: 2024-02-07
