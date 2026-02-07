# App Service ARM Template

This directory contains ARM templates for deploying Azure App Service (Web App) with App Service Plan.

## Resources Created

- **App Service Plan**: Linux-based hosting plan
- **App Service (Web App)**: .NET 8.0 web application
- **Managed Identity**: System-assigned identity for secure access to other Azure resources

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| appServicePlanName | string | - | Name of the App Service Plan |
| appServiceName | string | - | Name of the App Service |
| location | string | Resource Group location | Azure region |
| environment | string | - | Environment (Development, Staging, Production) |
| skuName | string | B1 | App Service Plan SKU |
| skuCapacity | int | 1 | Number of instances |
| linuxFxVersion | string | DOTNETCORE\|8.0 | Runtime stack |
| alwaysOn | bool | false | Enable Always On |
| httpsOnly | bool | true | Require HTTPS |
| tags | object | {} | Resource tags |

## Environment-Specific Configurations

### Development
- SKU: B1 (Basic)
- Instances: 1
- Always On: Disabled (to reduce cost)

### Staging
- SKU: S1 (Standard)
- Instances: 1
- Always On: Enabled

### Production
- SKU: P1v2 (Premium v2)
- Instances: 2
- Always On: Enabled

## Deployment

### Using PowerShell

```powershell
New-AzResourceGroupDeployment `
    -Name "app-service-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "app-service.json" `
    -TemplateParameterFile "parameters.dev.json"
```

### Using Azure CLI

```bash
az deployment group create \
    --name app-service-deployment \
    --resource-group kbudget-dev-rg \
    --template-file app-service.json \
    --parameters @parameters.dev.json
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| appServicePlanId | string | Resource ID of the App Service Plan |
| appServiceId | string | Resource ID of the App Service |
| appServiceDefaultHostName | string | Default hostname (URL) |
| appServicePrincipalId | string | Managed identity principal ID |

## Security Features

- HTTPS only enforcement
- System-assigned managed identity
- TLS 1.2 minimum
- FTPS disabled
- HTTP 2.0 enabled

## Post-Deployment

After deployment, you can:

1. **Configure application settings**:
   ```powershell
   Set-AzWebApp -ResourceGroupName "kbudget-dev-rg" `
       -Name "kbudget-dev-app" `
       -AppSettings @{"Setting1"="Value1"}
   ```

2. **Deploy application code**:
   ```powershell
   Publish-AzWebApp -ResourceGroupName "kbudget-dev-rg" `
       -Name "kbudget-dev-app" `
       -ArchivePath "./app.zip"
   ```

3. **View the app**:
   - Navigate to: `https://kbudget-dev-app.azurewebsites.net`
