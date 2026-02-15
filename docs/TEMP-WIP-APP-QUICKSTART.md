# Temporary WIP App - Quick Start Guide

This guide will help you quickly deploy the KBudget temporary Work in Progress application to Azure.

## What is This?

A fun, 90s retro-themed "Under Construction" page that can be deployed while the main KBudget GPT application is being developed. It features:

- 🎨 Authentic 90s web aesthetics with neon colors and animations
- 🚀 Fast, lightweight Node.js application
- ☁️ Ready for Azure App Service deployment
- 🔄 Automated CI/CD pipeline

## Prerequisites

Before you begin, ensure you have:

- [ ] An Azure subscription
- [ ] Azure CLI installed (for manual deployment) or GitHub repository access (for automated deployment)
- [ ] Contributor access to your Azure subscription

## Option 1: Automated Deployment (Recommended)

The fastest way to deploy using GitHub Actions:

### Step 1: Configure Azure Credentials

Create a service principal:

```bash
az ad sp create-for-rbac --name "kbudget-wip-deploy" \
  --role contributor \
  --scopes /subscriptions/{your-subscription-id} \
  --sdk-auth
```

### Step 2: Add GitHub Secret

1. Go to your repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `AZURE_CREDENTIALS`
4. Value: Paste the JSON output from Step 1
5. Click "Add secret"

### Step 3: Deploy

**Push to main branch:**
```bash
git push origin main
```

**Or manually trigger:**
1. Go to Actions tab in GitHub
2. Select "Deploy Temporary WIP App"
3. Click "Run workflow"
4. Select environment: dev/staging/prod
5. Click "Run workflow"

### Step 4: Access Your App

The workflow will display the URL in the summary. It will look like:
```
https://kbudget-wip-dev-xxxxx.azurewebsites.net
```

**Done!** Your 90s retro WIP page is live! 🎉

## Option 2: Manual Deployment (5 Minutes)

For manual control or troubleshooting:

### Step 1: Login to Azure

```bash
az login
```

### Step 2: Deploy Infrastructure

```bash
# Navigate to the template directory
cd infrastructure/arm-templates/temp-wip-app

# Create resource group
az group create --name kbudget-dev-rg --location eastus

# Deploy ARM template
az deployment group create \
  --resource-group kbudget-dev-rg \
  --template-file template.json \
  --parameters parameters.dev.json

# Get the web app name
WEB_APP_NAME=$(az deployment group show \
  --resource-group kbudget-dev-rg \
  --name template \
  --query properties.outputs.webAppName.value \
  --output tsv)

echo "Web App Name: $WEB_APP_NAME"
```

### Step 3: Deploy Application

```bash
# Navigate to the app directory
cd ../../../temp-app

# Create deployment zip
zip -r deploy.zip .

# Deploy to Azure
az webapp deployment source config-zip \
  --resource-group kbudget-dev-rg \
  --name $WEB_APP_NAME \
  --src deploy.zip
```

### Step 4: Get the URL

```bash
az deployment group show \
  --resource-group kbudget-dev-rg \
  --name template \
  --query properties.outputs.webAppUrl.value \
  --output tsv
```

**Done!** Visit the URL to see your retro WIP page! 🎉

## Option 3: Test Locally First

Want to see it before deploying?

```bash
# Navigate to app directory
cd temp-app

# Start the server
node server.js

# Open browser to http://localhost:8080
```

Press Ctrl+C to stop the server when done.

## Environments

The app can be deployed to three environments:

| Environment | Resource Group | SKU | Cost |
|-------------|----------------|-----|------|
| **dev** | kbudget-dev-rg | F1 (Free) | $0/month |
| **staging** | kbudget-staging-rg | B1 (Basic) | ~$13/month |
| **prod** | kbudget-prod-rg | B1 (Basic) | ~$13/month |

**Recommendation:** Start with dev (free tier) for testing.

## Verify Deployment

Check if your app is running:

```bash
# Get the URL from deployment outputs
URL=$(az deployment group show \
  --resource-group kbudget-dev-rg \
  --name template \
  --query properties.outputs.webAppUrl.value \
  --output tsv)

# Test the endpoint
curl -I $URL
```

Expected response: `HTTP/1.1 200 OK`

## Troubleshooting

### Issue: App returns 503 Service Unavailable

**Solution:** The app may still be starting. Wait 1-2 minutes and try again.

### Issue: Deployment fails with "Resource group not found"

**Solution:** Create the resource group first:
```bash
az group create --name kbudget-dev-rg --location eastus
```

### Issue: Can't find the web app name

**Solution:** List all web apps in the resource group:
```bash
az webapp list --resource-group kbudget-dev-rg --output table
```

### Issue: Changes not appearing

**Solution:** 
1. Clear browser cache (Ctrl+F5)
2. Verify deployment completed successfully
3. Check application logs:
```bash
az webapp log tail --resource-group kbudget-dev-rg --name $WEB_APP_NAME
```

## Next Steps

Once deployed:

1. **Share the URL** with your team
2. **Monitor the app** in Azure Portal
3. **Customize the page** by editing `temp-app/index.html`
4. **Plan migration** to the main KBudget GPT app

## Clean Up

When you're done with the temporary app:

```bash
# Delete the entire resource group
az group delete --name kbudget-dev-rg --yes --no-wait
```

**Warning:** This will delete all resources in the group!

## Cost Management

- **Free Tier (F1)**: $0/month but limited to 60 min/day compute time
- **Basic Tier (B1)**: ~$13/month with always-on capability
- **Tip**: Use F1 for dev, B1 only when needed for staging/prod

## Learn More

- [Full Deployment Guide](../infrastructure/arm-templates/temp-wip-app/README.md)
- [App README](../temp-app/README.md)
- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)

## Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting)
2. Review deployment logs in Azure Portal or GitHub Actions
3. Consult the [full deployment guide](../infrastructure/arm-templates/temp-wip-app/README.md)

---

**Ready to deploy?** Choose your preferred option above and get started! 🚀
