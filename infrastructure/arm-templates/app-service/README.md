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
| enableAadAuthentication | bool | false | Enable Azure Active Directory authentication |
| aadClientId | string | "" | Azure AD Application (Client) ID |
| aadTenantId | string | "" | Azure AD Tenant ID |
| aadClientSecret | securestring | "" | Azure AD Client Secret |

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
- Azure Active Directory authentication (optional)
  - OAuth 2.0 and OpenID Connect
  - Role-based access control
  - Token store for session management

## Azure AD Authentication

To enable Azure AD authentication:

### 1. Register AAD Application

First, register an AAD application using the provided script:

```powershell
cd infrastructure/arm-templates/aad-app-registration
.\Register-AADApp.ps1 -Environment dev
```

This creates an AAD app registration and outputs the configuration values.

### 2. Store Client Secret in Key Vault

```powershell
# Get the AAD configuration
$aadConfig = Get-Content "infrastructure/arm-templates/aad-app-registration/aad-config-dev.json" | ConvertFrom-Json

# Store secret in Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $aadConfig.ClientSecret -AsPlainText -Force)
```

### 3. Deploy with AAD Authentication Enabled

Update the parameter file (`parameters.dev.json`):

```json
{
  "enableAadAuthentication": {
    "value": true
  },
  "aadClientId": {
    "value": "your-client-id-here"
  },
  "aadTenantId": {
    "value": "your-tenant-id-here"
  }
}
```

Then deploy with the client secret from Key Vault:

```powershell
# Get client secret from Key Vault
$secret = Get-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "AAD-ClientSecret" -AsPlainText

# Deploy with AAD authentication
New-AzResourceGroupDeployment `
    -Name "app-service-deployment-aad" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "app-service.json" `
    -TemplateParameterFile "parameters.dev.json" `
    -aadClientSecret $secret
```

### 4. Assign Users to Roles

After deployment, assign users to the AAD app roles:

1. Navigate to Azure Portal > Enterprise Applications
2. Find your app: "KBudget GPT - Development"
3. Go to Users and groups
4. Add users and assign them to either **Administrator** or **User** role

For detailed AAD setup instructions, see [AAD App Registration README](../aad-app-registration/README.md).

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
