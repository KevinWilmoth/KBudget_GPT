# Azure AD Authentication - Quick Start Guide

This guide provides step-by-step instructions to quickly set up Azure Active Directory authentication for the KBudget GPT application.

## Prerequisites

Before starting, ensure you have:

- ✅ Azure subscription with appropriate permissions
- ✅ Azure PowerShell module installed (`Install-Module -Name Az`)
- ✅ Authenticated to Azure (`Connect-AzAccount`)
- ✅ Application Administrator or Global Administrator role in Azure AD
- ✅ Azure resources deployed (App Service, Key Vault, etc.)

## Quick Setup (5 minutes)

### Step 1: Register Azure AD Application

```powershell
# Navigate to AAD app registration directory
cd infrastructure/arm-templates/aad-app-registration

# Register the application for your environment
.\Register-AADApp.ps1 -Environment dev

# Save the output values - you'll need them!
```

**Output will include:**
- Tenant ID
- Client ID (Application ID)
- Client Secret
- Configuration file: `aad-config-dev.json`

### Step 2: Store Secret in Key Vault

```powershell
# Load the configuration
$config = Get-Content "aad-config-dev.json" | ConvertFrom-Json

# Store the client secret securely
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $config.ClientSecret -AsPlainText -Force)

Write-Host "✓ Client secret stored in Key Vault" -ForegroundColor Green
```

### Step 3: Update App Service Parameters

Edit `infrastructure/arm-templates/app-service/parameters.dev.json`:

```json
{
  "enableAadAuthentication": {
    "value": true
  },
  "aadClientId": {
    "value": "paste-your-client-id-here"
  },
  "aadTenantId": {
    "value": "paste-your-tenant-id-here"
  }
}
```

### Step 4: Deploy App Service with Authentication

```powershell
# Navigate to app service directory
cd ../app-service

# Get the client secret from Key Vault
$secret = Get-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "AAD-ClientSecret" -AsPlainText

# Deploy with authentication enabled
New-AzResourceGroupDeployment `
    -Name "app-service-aad-$(Get-Date -Format 'yyyyMMddHHmmss')" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "app-service.json" `
    -TemplateParameterFile "parameters.dev.json" `
    -aadClientSecret $secret

Write-Host "✓ App Service deployed with AAD authentication" -ForegroundColor Green
```

### Step 5: Grant Admin Consent (Required)

1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Find your app: **KBudget GPT - Development**
4. Click **API permissions** in the left menu
5. Click **Grant admin consent for [Your Organization]**
6. Click **Yes** to confirm

### Step 6: Assign Users

1. In Azure Portal, go to **Enterprise applications**
2. Search for and select **KBudget GPT - Development**
3. Click **Users and groups**
4. Click **+ Add user/group**
5. Select users and assign them to either:
   - **Administrator** role (full access)
   - **User** role (standard access)
6. Click **Assign**

### Step 7: Test the Configuration

```powershell
# Run the validation script
cd ../aad-app-registration
.\Test-AADAuthentication.ps1 -Environment dev
```

Expected output:
```
========================================
AAD Authentication Test Suite
Environment: Development
========================================

✓ Azure Authentication
✓ AAD Application exists
✓ Redirect URIs configured
✓ App Roles configured
✓ Key Vault exists
✓ Client Secret exists in Key Vault
✓ App Service exists
✓ Authentication enabled
✓ Azure AD provider configured
✓ Redirects to Azure AD login

✓ All tests passed!
```

### Step 8: Test User Access

1. Open your browser
2. Navigate to: `https://kbudget-dev-app.azurewebsites.net`
3. You should be redirected to Microsoft login page
4. Sign in with your organizational credentials
5. Grant consent if prompted
6. Verify you're redirected back to the application

## Troubleshooting

### Issue: Redirect URI mismatch error

**Fix:** Verify the redirect URIs in Azure Portal:
- Go to App registrations > Your app > Authentication
- Ensure these URIs are listed:
  - `https://kbudget-dev-app.azurewebsites.net/.auth/login/aad/callback`
  - `https://kbudget-dev-app.azurewebsites.net/signin-oidc`

### Issue: User gets "Access Denied" after login

**Fix:** Assign the user to a role:
- Go to Enterprise applications > Your app > Users and groups
- Add the user with appropriate role

### Issue: "Client secret is invalid"

**Fix:** Re-create and update the secret:
```powershell
# Create new secret
$app = Get-AzADApplication -DisplayName "KBudget GPT - Development"
$newSecret = New-AzADAppCredential -ApplicationId $app.AppId -EndDate (Get-Date).AddDays(365)

# Update Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $newSecret.SecretText -AsPlainText -Force)

# Restart App Service
Restart-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"
```

## For Other Environments

### Staging

```powershell
# Register AAD app
.\Register-AADApp.ps1 -Environment staging

# Store secret
$config = Get-Content "aad-config-staging.json" | ConvertFrom-Json
Set-AzKeyVaultSecret -VaultName "kbudget-staging-kv" -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $config.ClientSecret -AsPlainText -Force)

# Update parameters.staging.json and deploy
# ... (same steps as dev)
```

### Production

```powershell
# Register AAD app
.\Register-AADApp.ps1 -Environment prod

# Store secret
$config = Get-Content "aad-config-prod.json" | ConvertFrom-Json
Set-AzKeyVaultSecret -VaultName "kbudget-prod-kv" -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $config.ClientSecret -AsPlainText -Force)

# Update parameters.prod.json and deploy
# ... (same steps as dev)
```

## Next Steps

- ✅ Set up automated secret rotation (recommended every 6 months)
- ✅ Configure Conditional Access policies for enhanced security
- ✅ Enable MFA for admin accounts
- ✅ Set up monitoring and alerting for authentication events
- ✅ Document your organization's user onboarding process
- ✅ Schedule regular access reviews

## Additional Resources

- **[Complete Setup Guide](../../docs/AAD-AUTHENTICATION-SETUP-GUIDE.md)** - Comprehensive documentation
- **[AAD App Registration README](README.md)** - Detailed script documentation
- **[App Service README](../app-service/README.md)** - App Service deployment guide
- **[Azure AD Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)** - Microsoft's official docs

## Support

If you encounter issues:
1. Review the troubleshooting section above
2. Check the detailed logs in `logs/` directory
3. Run the test script: `.\Test-AADAuthentication.ps1 -Environment dev`
4. Consult the [Complete Setup Guide](../../docs/AAD-AUTHENTICATION-SETUP-GUIDE.md)
5. Create an issue in the repository if problems persist
