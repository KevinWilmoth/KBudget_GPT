# Key Vault ARM Template

This directory contains ARM templates for deploying Azure Key Vault.

## Resources Created

- **Key Vault**: Secure storage for secrets, keys, and certificates

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| keyVaultName | string | - | Key Vault name (globally unique, 3-24 chars) |
| location | string | Resource Group location | Azure region |
| tenantId | string | Current tenant | Azure AD tenant ID |
| objectId | string | - | User/SP object ID for access |
| skuName | string | standard | Key Vault SKU (standard or premium) |
| enabledForDeployment | bool | true | Enable for VM deployment |
| enabledForTemplateDeployment | bool | true | Enable for ARM templates |
| enabledForDiskEncryption | bool | false | Enable for disk encryption |
| enableSoftDelete | bool | true | Enable soft delete |
| softDeleteRetentionInDays | int | 90 | Soft delete retention (7-90 days) |
| enablePurgeProtection | bool | true | Enable purge protection |
| enableRbacAuthorization | bool | false | Use RBAC instead of access policies |
| tags | object | {} | Resource tags |

## Environment-Specific Configurations

### Development
- SKU: Standard
- Purge Protection: Disabled (allows deletion during dev)
- Retention: 90 days

### Staging
- SKU: Standard
- Purge Protection: Enabled
- Retention: 90 days

### Production
- SKU: Premium (HSM-backed keys)
- Purge Protection: Enabled
- Retention: 90 days

## Deployment

### Get Your Object ID

```powershell
# For user account
$objectId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account.Id).Id

# For service principal
$objectId = (Get-AzADServicePrincipal -ApplicationId "<app-id>").Id
```

### Update Parameter File

Edit `parameters.{env}.json` and replace `{user-or-sp-object-id}` with your actual object ID.

### Deploy with Network Restrictions (Recommended for Production)

```powershell
# Get subnet IDs for allowed access
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-vnet"
$appSubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "app-subnet"
$funcSubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "func-subnet"

# Create subnet ID objects (format required by template)
$allowedSubnets = @(
    @{ id = $appSubnet.Id },
    @{ id = $funcSubnet.Id }
)

# Create IP address objects (for admin access)
$allowedIPs = @(
    @{ value = "1.2.3.4" }  # Replace with your admin IP
)

# Deploy with network restrictions
New-AzResourceGroupDeployment `
    -Name "keyvault-deployment" `
    -ResourceGroupName "kbudget-prod-rg" `
    -TemplateFile "key-vault.json" `
    -TemplateParameterFile "parameters.prod.json" `
    -allowedSubnetIds $allowedSubnets `
    -allowedIpAddresses $allowedIPs `
    -networkAclsDefaultAction "Deny"
```

### Deploy without Network Restrictions (Development Only)

```powershell
New-AzResourceGroupDeployment `
    -Name "keyvault-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "key-vault.json" `
    -TemplateParameterFile "parameters.dev.json"
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| keyVaultId | string | Resource ID |
| keyVaultUri | string | Vault URI |
| keyVaultName | string | Vault name |

## Security Features

- Soft delete enabled (90-day retention)
- Purge protection (staging/prod)
- Network rules allow Azure services
- Access policies for specified users/SPs
- Template deployment enabled for ARM

## Post-Deployment

### Add Secrets

```powershell
$secretValue = ConvertTo-SecureString -String "MySecretValue" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "MySecret" -SecretValue $secretValue
```

### Grant Access to App Service

```powershell
# Get App Service managed identity
$appIdentity = (Get-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app").Identity.PrincipalId

# Grant access to secrets
Set-AzKeyVaultAccessPolicy -VaultName "kbudget-dev-kv" `
    -ObjectId $appIdentity `
    -PermissionsToSecrets Get,List
```

### Reference Secrets in App Service

```powershell
$appSettings = @{
    "ConnectionStrings:Database" = "@Microsoft.KeyVault(SecretUri=https://kbudget-dev-kv.vault.azure.net/secrets/SqlConnectionString/)"
    "ApiKeys:OpenAI" = "@Microsoft.KeyVault(SecretUri=https://kbudget-dev-kv.vault.azure.net/secrets/OpenAIApiKey/)"
}
Set-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app" -AppSettings $appSettings
```

### View Secrets

```powershell
# List all secrets
Get-AzKeyVaultSecret -VaultName "kbudget-dev-kv"

# Get secret value
Get-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "MySecret" -AsPlainText
```

## Common Secrets to Store

- SQL Database connection strings
- Storage Account connection strings
- API keys (OpenAI, SendGrid, etc.)
- Service principal credentials
- Encryption keys
- SSL certificates

## Access Policies

The default access policy grants full permissions to the deploying user/SP:

- **Keys**: get, list, create, update, delete, backup, restore
- **Secrets**: get, list, set, delete, backup, restore
- **Certificates**: get, list, create, update, delete, managecontacts, manageissuers

To add more access policies:

```powershell
Set-AzKeyVaultAccessPolicy -VaultName "kbudget-dev-kv" `
    -ObjectId "<object-id>" `
    -PermissionsToSecrets Get,List `
    -PermissionsToKeys Get,List
```
