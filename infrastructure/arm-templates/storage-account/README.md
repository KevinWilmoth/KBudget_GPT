# Storage Account ARM Template

This directory contains ARM templates for deploying Azure Storage Account.

## Resources Created

- **Storage Account**: General-purpose v2 storage with blob, file, queue, and table services
- **Managed Identity**: System-assigned identity for secure access

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| storageAccountName | string | - | Storage account name (globally unique, lowercase, 3-24 chars) |
| location | string | Resource Group location | Azure region |
| skuName | string | Standard_LRS | Storage replication type |
| kind | string | StorageV2 | Storage account kind |
| accessTier | string | Hot | Access tier for blob storage |
| supportsHttpsTrafficOnly | bool | true | Require HTTPS |
| minimumTlsVersion | string | TLS1_2 | Minimum TLS version |
| allowBlobPublicAccess | bool | false | Allow public blob access |
| enableBlobEncryption | bool | true | Enable blob encryption |
| enableFileEncryption | bool | true | Enable file encryption |
| tags | object | {} | Resource tags |

## Environment-Specific Configurations

### Development
- SKU: Standard_LRS (Locally Redundant)
- Cost-effective for dev/test

### Staging
- SKU: Standard_GRS (Geo-Redundant)
- Regional redundancy

### Production
- SKU: Standard_GRS (Geo-Redundant)
- High availability and disaster recovery

## Deployment

### Using PowerShell

```powershell
New-AzResourceGroupDeployment `
    -Name "storage-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "storage-account.json" `
    -TemplateParameterFile "parameters.dev.json"
```

### Using Azure CLI

```bash
az deployment group create \
    --name storage-deployment \
    --resource-group kbudget-dev-rg \
    --template-file storage-account.json \
    --parameters @parameters.dev.json
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| storageAccountId | string | Resource ID |
| storageAccountName | string | Storage account name |
| primaryEndpoints | object | Primary blob, file, queue, table endpoints |
| storageAccountKey | string | Primary access key |

## Security Features

- HTTPS only enforcement
- TLS 1.2 minimum
- Blob and file encryption enabled
- Public access disabled by default
- Network rules allow Azure services
- System-assigned managed identity

## Post-Deployment

### Create Blob Containers

```powershell
$ctx = New-AzStorageContext -StorageAccountName "kbudgetdevst" -UseConnectedAccount
New-AzStorageContainer -Name "uploads" -Context $ctx -Permission Off
New-AzStorageContainer -Name "backups" -Context $ctx -Permission Off
```

### Get Connection String

```powershell
$key = (Get-AzStorageAccountKey -ResourceGroupName "kbudget-dev-rg" -Name "kbudgetdevst")[0].Value
$connectionString = "DefaultEndpointsProtocol=https;AccountName=kbudgetdevst;AccountKey=$key;EndpointSuffix=core.windows.net"
```

### Configure CORS (if needed)

```powershell
$ctx = New-AzStorageContext -StorageAccountName "kbudgetdevst" -UseConnectedAccount
$CorsRules = (@{
    AllowedOrigins=@("https://kbudget-dev-app.azurewebsites.net");
    AllowedMethods=@("GET","PUT");
    MaxAgeInSeconds=3600;
    ExposedHeaders=@("x-ms-*");
    AllowedHeaders=@("x-ms-*")
})
Set-AzStorageCORSRule -ServiceType Blob -CorsRules $CorsRules -Context $ctx
```

## Usage in Application

Store the connection string in Key Vault:

```powershell
$connectionString = "DefaultEndpointsProtocol=https;AccountName=kbudgetdevst;..."
$secureString = ConvertTo-SecureString -String $connectionString -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "StorageConnectionString" -SecretValue $secureString
```

Reference in App Service:

```powershell
$appSettings = @{
    "AzureStorage:ConnectionString" = "@Microsoft.KeyVault(SecretUri=https://kbudget-dev-kv.vault.azure.net/secrets/StorageConnectionString/)"
}
Set-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app" -AppSettings $appSettings
```
