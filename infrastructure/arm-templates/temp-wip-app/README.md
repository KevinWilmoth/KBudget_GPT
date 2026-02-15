# Temporary WIP App Service - Deployment Guide

## Overview

This directory contains a temporary "Work in Progress" application with a 90s retro design that can be deployed to Azure App Service. The application displays a fun, nostalgic under-construction page while the main KBudget GPT application is being developed.

## Features

- 🎨 **90s Retro Design**: Animated gradients, neon colors, marquee text, and classic web aesthetics
- 🚀 **Lightweight**: Simple Node.js server with zero dependencies
- 🐳 **Containerized**: Docker support for consistent deployments
- ☁️ **Azure Ready**: ARM templates for easy Azure App Service deployment
- 🔄 **CI/CD Pipeline**: Automated deployment via GitHub Actions

## Application Structure

```
temp-app/
├── index.html        # 90s retro WIP page
├── server.js         # Simple Node.js HTTP server
├── package.json      # Node.js package configuration
├── Dockerfile        # Container image definition
└── .dockerignore     # Docker build exclusions
```

## Local Testing

### Prerequisites
- Node.js 18 or higher
- (Optional) Docker for containerized testing

### Run Locally

1. **Navigate to the temp-app directory:**
   ```bash
   cd temp-app
   ```

2. **Start the server:**
   ```bash
   node server.js
   ```

3. **Open your browser:**
   ```
   http://localhost:8080
   ```

### Run with Docker

1. **Build the Docker image:**
   ```bash
   cd temp-app
   docker build -t kbudget-wip .
   ```

2. **Run the container:**
   ```bash
   docker run -p 8080:8080 kbudget-wip
   ```

3. **Access the app:**
   ```
   http://localhost:8080
   ```

## Deployment to Azure

### Option 1: Automated Deployment (GitHub Actions)

The easiest way to deploy is using the provided GitHub Actions workflow.

1. **Configure Azure Credentials:**

   First, create a service principal with contributor access:
   ```bash
   az ad sp create-for-rbac --name "kbudget-wip-deploy" \
     --role contributor \
     --scopes /subscriptions/{subscription-id} \
     --sdk-auth
   ```

2. **Add GitHub Secret:**
   - Go to your repository settings
   - Navigate to Secrets and variables → Actions
   - Add a new secret named `AZURE_CREDENTIALS`
   - Paste the JSON output from the previous command

3. **Trigger Deployment:**
   
   **Via Push:**
   ```bash
   # Make a change to temp-app or infrastructure files
   git add .
   git commit -m "Update temp app"
   git push origin main
   ```
   
   **Via Manual Trigger:**
   - Go to Actions tab in GitHub
   - Select "Deploy Temporary WIP App"
   - Click "Run workflow"
   - Select environment (dev/staging/prod)
   - Click "Run workflow"

4. **Monitor Deployment:**
   - The workflow will:
     - Create/update the resource group
     - Deploy the ARM template (App Service Plan + App Service)
     - Deploy the application code
     - Verify the deployment
   - Check the Actions tab for progress and logs
   - The deployment URL will be displayed in the workflow summary

### Option 2: Manual Deployment with Azure CLI

If you prefer manual control or need to troubleshoot:

1. **Login to Azure:**
   ```bash
   az login
   ```

2. **Create Resource Group (if not exists):**
   ```bash
   az group create \
     --name kbudget-dev-rg \
     --location eastus
   ```

3. **Deploy Infrastructure:**
   ```bash
   cd infrastructure/arm-templates/temp-wip-app
   
   az deployment group create \
     --resource-group kbudget-dev-rg \
     --template-file template.json \
     --parameters parameters.dev.json
   ```

4. **Get Web App Name:**
   ```bash
   az deployment group show \
     --resource-group kbudget-dev-rg \
     --name template \
     --query properties.outputs.webAppName.value \
     --output tsv
   ```

5. **Deploy Application Code:**
   ```bash
   cd ../../../temp-app
   
   # Create a zip file
   zip -r deploy.zip .
   
   # Deploy to Azure
   az webapp deployment source config-zip \
     --resource-group kbudget-dev-rg \
     --name <web-app-name-from-step-4> \
     --src deploy.zip
   ```

6. **Get the URL:**
   ```bash
   az deployment group show \
     --resource-group kbudget-dev-rg \
     --name template \
     --query properties.outputs.webAppUrl.value \
     --output tsv
   ```

### Option 3: Deploy with PowerShell

1. **Login and Set Context:**
   ```powershell
   Connect-AzAccount
   Set-AzContext -SubscriptionId <your-subscription-id>
   ```

2. **Deploy Infrastructure:**
   ```powershell
   $resourceGroup = "kbudget-dev-rg"
   $location = "eastus"
   
   # Create resource group if needed
   New-AzResourceGroup -Name $resourceGroup -Location $location -Force
   
   # Deploy template
   $deployment = New-AzResourceGroupDeployment `
     -ResourceGroupName $resourceGroup `
     -TemplateFile "infrastructure/arm-templates/temp-wip-app/template.json" `
     -TemplateParameterFile "infrastructure/arm-templates/temp-wip-app/parameters.dev.json"
   
   # Get outputs
   $webAppName = $deployment.Outputs.webAppName.Value
   $webAppUrl = $deployment.Outputs.webAppUrl.Value
   
   Write-Host "Web App Name: $webAppName"
   Write-Host "Web App URL: $webAppUrl"
   ```

3. **Deploy Application (using ZIP deployment):**
   ```powershell
   # Compress the temp-app folder
   Compress-Archive -Path "temp-app\*" -DestinationPath "deploy.zip" -Force
   
   # Deploy to Azure
   Publish-AzWebApp `
     -ResourceGroupName $resourceGroup `
     -Name $webAppName `
     -ArchivePath "deploy.zip" `
     -Force
   ```

## Environment Configuration

The application supports three environments:

### Development (dev)
- **Resource Group**: `kbudget-dev-rg`
- **App Name**: `kbudget-wip-dev`
- **SKU**: F1 (Free tier)
- **Parameters File**: `parameters.dev.json`

### Staging
- **Resource Group**: `kbudget-staging-rg`
- **App Name**: `kbudget-wip-staging`
- **SKU**: B1 (Basic tier)
- **Parameters File**: `parameters.staging.json`

### Production
- **Resource Group**: `kbudget-prod-rg`
- **App Name**: `kbudget-wip-prod`
- **SKU**: B1 (Basic tier)
- **Parameters File**: `parameters.prod.json`

## ARM Template Parameters

The `template.json` accepts the following parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `appName` | string | `kbudget-wip` | Name prefix for the app service |
| `location` | string | Resource group location | Azure region for deployment |
| `sku` | string | `F1` | App Service Plan pricing tier (F1, B1, B2, B3, S1, S2, S3) |
| `linuxFxVersion` | string | `NODE\|18-lts` | Runtime stack for the app |

## Customization

### Modify the App

To customize the Work in Progress page:

1. **Edit the HTML:**
   - Open `temp-app/index.html`
   - Modify text, colors, or animations
   - The page is self-contained with inline CSS and JavaScript

2. **Test locally:**
   ```bash
   cd temp-app
   node server.js
   ```

3. **Deploy changes:**
   - Commit and push to trigger GitHub Actions, or
   - Manually redeploy using one of the deployment options above

### Change the App Service Configuration

1. **Edit ARM template:**
   - Modify `infrastructure/arm-templates/temp-wip-app/template.json`
   - Adjust `siteConfig` settings, app settings, or other properties

2. **Update parameters:**
   - Edit the appropriate `parameters.{env}.json` file
   - Change SKU, app name, or other parameters

3. **Redeploy:**
   ```bash
   az deployment group create \
     --resource-group kbudget-dev-rg \
     --template-file infrastructure/arm-templates/temp-wip-app/template.json \
     --parameters infrastructure/arm-templates/temp-wip-app/parameters.dev.json
   ```

## Monitoring and Troubleshooting

### View Application Logs

**Azure Portal:**
1. Navigate to your App Service
2. Select "Log stream" from the left menu
3. Watch real-time logs

**Azure CLI:**
```bash
az webapp log tail \
  --resource-group kbudget-dev-rg \
  --name <web-app-name>
```

### Common Issues

**Issue: App not responding**
- Check if the app is running: Azure Portal → App Service → Overview
- Verify the deployment was successful: Check deployment logs
- Review application logs for errors

**Issue: 503 Service Unavailable**
- The app may still be starting up (wait 1-2 minutes)
- Check if there are enough resources in the App Service Plan
- Verify the PORT environment variable is set to 8080

**Issue: Changes not appearing**
- Clear browser cache (Ctrl+F5)
- Verify deployment completed successfully
- Check if files were uploaded: Azure Portal → App Service → Advanced Tools → Debug console

### Health Check

Test if the app is responding:
```bash
curl -I https://<your-app-name>.azurewebsites.net
```

Expected response: `HTTP/1.1 200 OK`

## Cost Management

### Free Tier (F1)
- **Cost**: $0/month
- **Limitations**:
  - 60 minutes/day compute time
  - 1 GB disk space
  - No custom domains
  - App sleeps after 20 minutes of inactivity

### Basic Tier (B1)
- **Cost**: ~$13/month
- **Features**:
  - Always-on capability
  - Custom domains
  - Up to 3 instances

**Recommendation**: Use F1 for dev, B1 for staging/prod

## Cleanup

### Delete Resources

**Using Azure CLI:**
```bash
# Delete entire resource group
az group delete --name kbudget-dev-rg --yes --no-wait
```

**Using PowerShell:**
```powershell
Remove-AzResourceGroup -Name "kbudget-dev-rg" -Force
```

**Via Portal:**
1. Navigate to Resource Groups
2. Select the resource group
3. Click "Delete resource group"
4. Type the resource group name to confirm
5. Click "Delete"

## Next Steps

Once the main KBudget GPT application is ready:

1. **Deploy the real application** using the existing App Service infrastructure
2. **Update the GitHub Actions workflow** to deploy the main app
3. **Remove or repurpose** this temporary WIP app
4. **Update DNS** if using custom domains

## Support and Resources

- **Azure App Service Documentation**: https://docs.microsoft.com/azure/app-service/
- **Node.js on Azure**: https://docs.microsoft.com/azure/app-service/quickstart-nodejs
- **GitHub Actions for Azure**: https://github.com/Azure/actions

## License

This temporary application is part of the KBudget GPT project.
