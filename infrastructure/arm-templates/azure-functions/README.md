# Azure Functions ARM Template

This directory contains ARM templates for deploying Azure Functions with required dependencies.

## Resources Created

- **App Service Plan**: Consumption (Y1) plan for serverless hosting
- **Application Insights**: Monitoring and diagnostics
- **Function App**: Serverless function runtime
- **Managed Identity**: System-assigned identity for secure access

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| functionAppName | string | - | Function App name |
| storageAccountName | string | - | Storage account for Functions runtime |
| location | string | Resource Group location | Azure region |
| environment | string | - | Environment name |
| runtime | string | dotnet | Runtime stack (dotnet, node, python, java) |
| runtimeVersion | string | 8 | Runtime version |
| use32BitWorkerProcess | bool | false | Use 32-bit worker |
| tags | object | {} | Resource tags |

## Environment-Specific Configurations

All environments use the same configuration:
- **Plan**: Consumption (Y1) - serverless, pay-per-execution
- **Runtime**: .NET 8.0
- **Functions Version**: 4.x
- **Application Insights**: Enabled

## Deployment

**Important**: Storage Account must exist before deploying Functions.

```powershell
# Deploy Storage Account first
New-AzResourceGroupDeployment `
    -Name "storage-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "../storage-account/storage-account.json" `
    -TemplateParameterFile "../storage-account/parameters.dev.json"

# Then deploy Functions
New-AzResourceGroupDeployment `
    -Name "functions-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "azure-functions.json" `
    -TemplateParameterFile "parameters.dev.json"
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| functionAppId | string | Resource ID |
| functionAppName | string | Function App name |
| functionAppPrincipalId | string | Managed identity principal ID |
| functionAppDefaultHostName | string | Default hostname (URL) |

## Pre-configured Settings

The template automatically configures:

| Setting | Value |
|---------|-------|
| AzureWebJobsStorage | Storage account connection string |
| WEBSITE_CONTENTAZUREFILECONNECTIONSTRING | Storage for function content |
| WEBSITE_CONTENTSHARE | File share name |
| FUNCTIONS_EXTENSION_VERSION | ~4 |
| FUNCTIONS_WORKER_RUNTIME | dotnet |
| APPINSIGHTS_INSTRUMENTATIONKEY | Application Insights key |
| APPLICATIONINSIGHTS_CONNECTION_STRING | Application Insights connection |
| ENVIRONMENT | Development/Staging/Production |

## Security Features

- HTTPS only enforcement
- System-assigned managed identity
- TLS 1.2 minimum
- FTPS disabled
- Integrated Application Insights

## Post-Deployment

### Deploy Function Code

```powershell
# Using Azure Functions Core Tools
func azure functionapp publish kbudget-dev-func

# Using PowerShell
Compress-Archive -Path ./functions/* -DestinationPath ./functions.zip
Publish-AzWebApp -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-func" `
    -ArchivePath "./functions.zip"
```

### Add Application Settings

```powershell
$settings = @{
    "SqlConnectionString" = "@Microsoft.KeyVault(SecretUri=https://kbudget-dev-kv.vault.azure.net/secrets/SqlConnectionString/)"
    "OpenAIApiKey" = "@Microsoft.KeyVault(SecretUri=https://kbudget-dev-kv.vault.azure.net/secrets/OpenAIApiKey/)"
}
Update-AzFunctionAppSetting -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-func" `
    -AppSetting $settings
```

### Grant Key Vault Access

```powershell
# Get Function App managed identity
$funcIdentity = (Get-AzFunctionApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-func").IdentityPrincipalId

# Grant access to Key Vault secrets
Set-AzKeyVaultAccessPolicy -VaultName "kbudget-dev-kv" `
    -ObjectId $funcIdentity `
    -PermissionsToSecrets Get,List
```

### View Logs

```powershell
# Stream logs
Get-AzWebAppSlotPublishingLog -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-func"

# View in Application Insights
# Navigate to Azure Portal > Application Insights > kbudget-dev-func-insights
```

## Function Examples

### HTTP Trigger Function

```csharp
[FunctionName("ProcessBudget")]
public static async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest req,
    ILogger log)
{
    log.LogInformation("Processing budget calculation");
    // Your code here
    return new OkObjectResult("Success");
}
```

### Timer Trigger Function

```csharp
[FunctionName("DailyBudgetReport")]
public static void Run(
    [TimerTrigger("0 0 9 * * *")] TimerInfo myTimer,
    ILogger log)
{
    log.LogInformation($"Daily report executed at: {DateTime.Now}");
    // Your code here
}
```

## Scaling

Consumption plan automatically scales:
- Scales out: Up to 200 instances
- Scales in: When load decreases
- Billing: Pay only for execution time
- Timeout: 5 minutes default (10 minutes max)

## Monitoring

Access Application Insights for:
- Request tracking
- Performance metrics
- Failure analysis
- Custom telemetry
- Live metrics

```powershell
# Get Application Insights instrumentation key
$ai = Get-AzApplicationInsights -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-func-insights"
Write-Host "Instrumentation Key: $($ai.InstrumentationKey)"
```
