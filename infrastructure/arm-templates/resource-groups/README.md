# Azure Resource Groups - ARM Templates

This directory contains ARM templates for provisioning Azure Resource Groups for the KBudget GPT project following the documented naming conventions.

## Overview

The templates create resource groups for three environments:
- **Development**: `kbudget-dev-rg`
- **Staging**: `kbudget-staging-rg`
- **Production**: `kbudget-prod-rg`

All resource groups follow the naming convention documented in [Azure Resource Group Naming Conventions](../../../docs/azure-resource-group-naming-conventions.md).

## Files

| File | Purpose |
|------|---------|
| `resource-group.json` | Main ARM template for resource group creation |
| `parameters.dev.json` | Parameters for development environment |
| `parameters.staging.json` | Parameters for staging environment |
| `parameters.prod.json` | Parameters for production environment |
| `deploy-resource-groups.sh` | Deployment script with logging and validation |
| `README.md` | This file |

## Prerequisites

1. **Azure CLI**: Install from [here](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **Azure Subscription**: Active Azure subscription
3. **Permissions**: Contributor or Owner role at subscription level

## Authentication

Before deploying, authenticate with Azure:

```bash
# Login to Azure
az login

# Set the correct subscription (if you have multiple)
az account set --subscription "<subscription-id-or-name>"

# Verify the current subscription
az account show
```

## Deployment

### Deploy a Single Environment

Deploy development environment:
```bash
./deploy-resource-groups.sh dev
```

Deploy staging environment:
```bash
./deploy-resource-groups.sh staging
```

Deploy production environment:
```bash
./deploy-resource-groups.sh prod
```

### Deploy All Environments

Deploy all environments at once:
```bash
./deploy-resource-groups.sh all
```

## Features

### Idempotency
The deployment is idempotent - running it multiple times will not create duplicate resource groups. Azure Resource Manager will:
- Create the resource group if it doesn't exist
- Update tags and properties if the resource group exists
- Leave existing resources within the resource group untouched

### Logging
All deployments create detailed logs in the `logs/` directory with:
- Timestamp for each operation
- Deployment status and outputs
- Resource group details
- Color-coded messages (INFO, SUCCESS, WARNING, ERROR)

Log files are named: `deployment_YYYYMMDD_HHMMSS.log`

### Validation
The deployment script validates:
- Azure CLI is installed
- User is authenticated to Azure
- Environment parameter is valid
- Parameters files exist
- Template syntax is correct

## Template Details

### Parameters

The ARM template accepts the following parameters:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `resourceGroupName` | string | Resource group name following naming convention | Required |
| `location` | string | Azure region | `eastus` |
| `environment` | string | Environment identifier | Required |
| `project` | string | Project identifier | `KBudget-GPT` |
| `owner` | string | Team or person responsible | `DevOps-Team` |
| `costCenter` | string | Cost center for billing | `CC-12345` |
| `createdDate` | string | Creation date | Current UTC date |
| `application` | string | Application name | `KBudget` |

### Tags

All resource groups are tagged with:
- `Environment`: Development, Staging, or Production
- `Project`: KBudget-GPT
- `Owner`: DevOps-Team
- `CostCenter`: CC-12345
- `CreatedDate`: Deployment date
- `Application`: KBudget

### Outputs

The deployment provides the following outputs:
- `resourceGroupName`: Name of the created resource group
- `resourceGroupId`: Resource ID of the resource group
- `resourceGroupLocation`: Azure region where the resource group is located
- `tags`: All tags applied to the resource group

## Manual Deployment (Alternative)

If you prefer to deploy manually using Azure CLI:

```bash
# Deploy development environment
az deployment sub create \
  --name rg-deployment-dev \
  --location eastus \
  --template-file resource-group.json \
  --parameters @parameters.dev.json

# Deploy staging environment
az deployment sub create \
  --name rg-deployment-staging \
  --location eastus \
  --template-file resource-group.json \
  --parameters @parameters.staging.json

# Deploy production environment
az deployment sub create \
  --name rg-deployment-prod \
  --location eastus \
  --template-file resource-group.json \
  --parameters @parameters.prod.json
```

## Verification

After deployment, verify the resource groups:

```bash
# List all KBudget resource groups
az group list --query "[?starts_with(name, 'kbudget-')].{Name:name, Location:location, Tags:tags}" --output table

# View specific resource group details
az group show --name kbudget-dev-rg --output json

# View resource group tags
az group show --name kbudget-dev-rg --query tags
```

## Customization

To customize the deployment:

1. **Change Location**: Edit the `location` parameter in the respective parameters file
2. **Update Tags**: Modify tag values in the parameters files
3. **Add Custom Tags**: Add additional tags in the template or parameters files
4. **Change Cost Center**: Update the `costCenter` parameter value

## Troubleshooting

### Common Issues

**Issue**: "Az command not found"
- **Solution**: Install Azure CLI from [here](https://docs.microsoft.com/cli/azure/install-azure-cli)

**Issue**: "Please run 'az login' to setup account"
- **Solution**: Run `az login` to authenticate

**Issue**: "Insufficient permissions to create resource group"
- **Solution**: Ensure you have Contributor or Owner role at subscription level

**Issue**: "Template validation failed"
- **Solution**: Check the template syntax using:
  ```bash
  az deployment sub validate \
    --location eastus \
    --template-file resource-group.json \
    --parameters @parameters.dev.json
  ```

### Viewing Logs

Check deployment logs for detailed error messages:
```bash
# View most recent log
tail -f logs/deployment_*.log

# View specific log
cat logs/deployment_YYYYMMDD_HHMMSS.log
```

## CI/CD Integration

This template can be integrated into Azure DevOps, GitHub Actions, or other CI/CD pipelines:

### GitHub Actions Example
```yaml
- name: Deploy Resource Groups
  run: |
    az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} -p ${{ secrets.AZURE_CLIENT_SECRET }} --tenant ${{ secrets.AZURE_TENANT_ID }}
    cd infrastructure/arm-templates/resource-groups
    ./deploy-resource-groups.sh all
```

### Azure DevOps Example
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Azure-Service-Connection'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: 'infrastructure/arm-templates/resource-groups/deploy-resource-groups.sh'
    arguments: 'all'
```

## Cleanup

To delete the resource groups (⚠️ WARNING: This will delete ALL resources within the groups):

```bash
# Delete development resource group
az group delete --name kbudget-dev-rg --yes --no-wait

# Delete staging resource group
az group delete --name kbudget-staging-rg --yes --no-wait

# Delete production resource group (be very careful!)
az group delete --name kbudget-prod-rg --yes --no-wait
```

## Related Documentation

- [Azure Resource Group Naming Conventions](../../../docs/azure-resource-group-naming-conventions.md)
- [Azure Resource Group Best Practices](../../../docs/azure-resource-group-best-practices.md)
- [Azure ARM Template Reference](https://docs.microsoft.com/azure/azure-resource-manager/templates/)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)

## Support

For questions or issues, contact:
- **DevOps Team**: devops-team@company.com
- **Document Owner**: Kevin Wilmoth
