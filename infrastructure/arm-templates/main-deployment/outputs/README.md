# Deployment Outputs Directory

This directory contains the output files generated during Azure resource deployments.

## Contents

Deployment results are automatically exported to JSON files after each deployment:

- `deployment-results_{environment}_{timestamp}.json` - Timestamped deployment results
- `deployment-results_{environment}_latest.json` - Latest deployment results for quick reference

## Output File Structure

Each output file contains:

```json
{
  "Environment": "dev",
  "Timestamp": "20240207_143000",
  "DeploymentTime": "2024-02-07 14:30:00",
  "ResourceGroupName": "kbudget-dev-rg",
  "Location": "eastus",
  "ResourcesDeployed": ["ResourceGroup", "VNet", "KeyVault", "Storage", "SqlDatabase", "AppService", "Functions"],
  "DeploymentDetails": {
    "VNet": {
      "DeploymentName": "vnet-deployment-20240207",
      "ProvisioningState": "Succeeded",
      "Timestamp": "2024-02-07 14:25:00",
      "Outputs": {
        "vnetId": "/subscriptions/.../resourceGroups/kbudget-dev-rg/providers/Microsoft.Network/virtualNetworks/kbudget-dev-vnet",
        "vnetName": "kbudget-dev-vnet"
      }
    }
  }
}
```

## Usage

These output files are automatically created by the `Deploy-AzureResources.ps1` script and can be used for:

- **Auditing** - Track what resources were deployed and when
- **Troubleshooting** - Review deployment details and outputs
- **Integration** - Pass resource IDs to other automation scripts
- **Compliance** - Maintain deployment records

## Note

Output files are excluded from version control via `.gitignore` to avoid storing environment-specific data in the repository.
