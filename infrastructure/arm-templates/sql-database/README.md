# SQL Database ARM Template

This directory contains ARM templates for deploying Azure SQL Server and Database.

## Resources Created

- **SQL Server**: Azure SQL logical server
- **SQL Database**: Application database
- **Firewall Rule**: Allow Azure services access
- **Security Alert Policy**: Advanced Threat Protection (staging/prod)

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| sqlServerName | string | - | SQL Server name (globally unique) |
| sqlDatabaseName | string | - | Database name |
| location | string | Resource Group location | Azure region |
| administratorLogin | string | - | Admin username |
| administratorLoginPassword | securestring | - | Admin password (from Key Vault) |
| skuName | string | Basic | Database SKU |
| skuTier | string | Basic | Database tier |
| maxSizeBytes | int | 2GB | Maximum database size |
| enableAdvancedThreatProtection | bool | true | Enable ATP |
| allowAzureServices | bool | true | Allow Azure service access |
| tags | object | {} | Resource tags |

## Environment-Specific Configurations

### Development
- SKU: Basic
- Size: 2 GB
- Advanced Threat Protection: Disabled (cost savings)

### Staging
- SKU: S1 (Standard)
- Advanced Threat Protection: Enabled

### Production
- SKU: P1 (Premium)
- Advanced Threat Protection: Enabled

## Password Management

Passwords are **never** stored in parameter files. Instead, they're referenced from Key Vault:

```json
"administratorLoginPassword": {
  "reference": {
    "keyVault": {
      "id": "/subscriptions/{sub-id}/resourceGroups/kbudget-dev-rg/providers/Microsoft.KeyVault/vaults/kbudget-dev-kv"
    },
    "secretName": "SqlAdminPassword"
  }
}
```

The deployment script automatically generates and stores passwords in Key Vault.

## Deployment

### Using PowerShell

```powershell
New-AzResourceGroupDeployment `
    -Name "sql-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "sql-database.json" `
    -TemplateParameterFile "parameters.dev.json"
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| sqlServerFqdn | string | Fully qualified domain name |
| sqlServerId | string | SQL Server resource ID |
| sqlDatabaseId | string | Database resource ID |
| connectionString | string | Connection string template |

## Security Features

- TLS 1.2 minimum
- Advanced Threat Protection (staging/prod)
- Firewall rules for Azure services
- Passwords stored in Key Vault
- Encrypted connections enforced

## Connection String

After deployment, retrieve the connection string:

```powershell
$outputs = (Get-AzResourceGroupDeployment -ResourceGroupName "kbudget-dev-rg" -Name "sql-deployment").Outputs
$connectionString = $outputs.connectionString.Value

# Get password from Key Vault
$password = Get-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "SqlAdminPassword" -AsPlainText

# Full connection string
$fullConnectionString = $connectionString + "Password=$password;"
```

## Post-Deployment

1. **Configure firewall rules** for specific IPs:
   ```powershell
   New-AzSqlServerFirewallRule -ResourceGroupName "kbudget-dev-rg" `
       -ServerName "kbudget-dev-sql" `
       -FirewallRuleName "MyIP" `
       -StartIpAddress "x.x.x.x" `
       -EndIpAddress "x.x.x.x"
   ```

2. **Run database migrations**:
   - Connect using SSMS, Azure Data Studio, or sqlcmd
   - Apply schema and seed data
