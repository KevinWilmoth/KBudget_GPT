# Azure Active Directory App Registration

This directory contains scripts for registering and configuring Azure Active Directory (AAD) applications for the KBudget GPT project.

## Quick Start

New to AAD authentication setup? See the **[Quick Start Guide](QUICKSTART.md)** for a 5-minute setup walkthrough.

## Overview

The AAD app registration enables enterprise-grade authentication for the KBudget GPT application using Azure Active Directory. This provides:

- **Secure Authentication**: OAuth 2.0 and OpenID Connect protocols
- **Single Sign-On**: Use existing Azure AD credentials
- **Role-Based Access**: Admin and User roles for different access levels
- **API Permissions**: Integration with Microsoft Graph API
- **Enterprise Integration**: Seamless integration with organizational identity

## Prerequisites

Before running the registration script, ensure you have:

1. **Azure PowerShell Module**:
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser
   ```

2. **Azure Authentication**:
   ```powershell
   Connect-AzAccount
   ```

3. **Required Permissions**:
   - Application Administrator role or
   - Global Administrator role in Azure AD

## Usage

### Basic Registration

Register an AAD application for a specific environment:

```powershell
# Development environment
.\Register-AADApp.ps1 -Environment dev

# Staging environment
.\Register-AADApp.ps1 -Environment staging

# Production environment
.\Register-AADApp.ps1 -Environment prod
```

### Custom App Service URL

If your App Service has a custom URL:

```powershell
.\Register-AADApp.ps1 `
    -Environment dev `
    -AppServiceUrl "https://kbudget-custom.azurewebsites.net"
```

### Custom Display Name

Use a custom display name for the AAD application:

```powershell
.\Register-AADApp.ps1 `
    -Environment dev `
    -DisplayName "My Custom KBudget App"
```

### Custom Secret Expiration

Set a custom expiration period for the client secret (default is 365 days):

```powershell
.\Register-AADApp.ps1 `
    -Environment dev `
    -SecretExpirationDays 730  # 2 years
```

### Dry Run (WhatIf)

Preview what would be created without making changes:

```powershell
.\Register-AADApp.ps1 -Environment dev -WhatIf
```

## What Gets Created

The script creates the following:

### 1. AAD Application Registration
- **Display Name**: `KBudget GPT - {Environment}`
- **Sign-in Audience**: Single tenant (AzureADMyOrg)
- **Redirect URIs**:
  - `{AppServiceUrl}/.auth/login/aad/callback`
  - `{AppServiceUrl}/signin-oidc`

### 2. API Permissions
- **Microsoft Graph**:
  - `User.Read` (Delegated): Sign in and read user profile

### 3. Client Secret
- Generated with specified expiration (default: 365 days)
- Saved securely and output for Key Vault storage

### 4. App Roles
- **Administrator**: Full access to all features
- **User**: Access to budget management features

## Output

The script generates:

### Console Output
```
Configuration Values (save these securely):
  Tenant ID:        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Application ID:   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Client Secret:    ****************************************
  App Service URL:  https://kbudget-dev-app.azurewebsites.net
```

### Configuration File
A JSON file is created: `aad-config-{environment}.json`
```json
{
  "TenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "ClientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "ClientSecret": "****************************************",
  "ApplicationObjectId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "AppServiceUrl": "https://kbudget-dev-app.azurewebsites.net",
  "Environment": "Development"
}
```

### Log File
Detailed logs are written to: `logs/aad_registration_{environment}_{timestamp}.log`

## Post-Registration Steps

After running the script, complete these steps:

### 1. Store Client Secret in Key Vault

```powershell
# Get the configuration
$config = Get-Content "aad-config-dev.json" | ConvertFrom-Json

# Store in Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $config.ClientSecret -AsPlainText -Force)
```

### 2. Grant Admin Consent (if required)

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to **Azure Active Directory** > **App registrations**
3. Find your application: `KBudget GPT - {Environment}`
4. Click **API permissions**
5. Click **Grant admin consent for {Your Tenant}**

### 3. Assign Users to Roles

1. In Azure Portal, go to **Enterprise applications**
2. Find your application
3. Click **Users and groups**
4. Click **Add user/group**
5. Assign users to either **Administrator** or **User** role

### 4. Configure App Service Authentication

Use the generated values to configure App Service authentication. This can be done either:

#### Option A: ARM Template Deployment
Use the updated App Service ARM template with AAD parameters (see `../app-service/README.md`)

#### Option B: Manual Configuration
1. In Azure Portal, navigate to your App Service
2. Go to **Authentication** (under Settings)
3. Click **Add identity provider**
4. Select **Microsoft**
5. Enter the values:
   - **Client ID**: From registration output
   - **Client Secret**: From Key Vault or registration output
   - **Issuer URL**: `https://login.microsoftonline.com/{TenantId}/v2.0`

## Security Best Practices

### ✅ DO:
- Store client secrets in Azure Key Vault
- Rotate client secrets before expiration
- Use separate AAD apps for each environment (dev, staging, prod)
- Limit app roles to required users only
- Review and audit API permissions regularly

### ❌ DON'T:
- Commit client secrets to source control
- Share client secrets via email or chat
- Use the same AAD app for multiple environments
- Grant admin consent without reviewing permissions
- Assign users to Administrator role unnecessarily

## Troubleshooting

### Error: "Not authenticated to Azure"

**Solution**: Run `Connect-AzAccount` to authenticate

### Error: "Application with name 'X' already exists"

**Solution**: The script will use the existing application. To create a new one, delete the existing app or use a different display name.

### Error: "Insufficient privileges to complete the operation"

**Solution**: Ensure you have Application Administrator or Global Administrator role in Azure AD

### Error: "Az.Resources module is not installed"

**Solution**: Install the module:
```powershell
Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser
```

### Client Secret Expired

**Solution**: Create a new client secret:
```powershell
# Get the app
$app = Get-AzADApplication -DisplayName "KBudget GPT - Development"

# Create new secret
$secret = New-AzADAppCredential `
    -ApplicationId $app.AppId `
    -EndDate (Get-Date).AddDays(365)

# Update Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $secret.SecretText -AsPlainText -Force)
```

## Integration with Main Deployment

The AAD app registration can be integrated with the main deployment script:

```powershell
# Run AAD registration first
$aadConfig = .\infrastructure\arm-templates\aad-app-registration\Register-AADApp.ps1 -Environment dev

# Then deploy infrastructure with AAD config
.\infrastructure\arm-templates\main-deployment\Deploy-AzureResources.ps1 `
    -Environment dev `
    -AADClientId $aadConfig.ClientId `
    -AADTenantId $aadConfig.TenantId
```

## Testing the Configuration

After setting up AAD authentication, use the test script to verify everything is configured correctly:

```powershell
# Run the test script
.\Test-AADAuthentication.ps1 -Environment dev
```

The test script validates:
- ✓ Azure authentication
- ✓ AAD app registration exists
- ✓ Redirect URIs are configured correctly
- ✓ App roles are configured
- ✓ Client secret is stored in Key Vault
- ✓ App Service exists and is accessible
- ✓ Authentication is enabled on App Service
- ✓ Azure AD provider is configured
- ✓ App Service redirects to Azure AD login

**Sample Output:**
```
========================================
AAD Authentication Test Suite
Environment: Development
========================================

Testing Prerequisites...
✓ Azure Authentication

Testing AAD App Registration...
✓ AAD Application exists
✓ Redirect URIs configured
✓ App Roles configured

Testing Key Vault Secret...
✓ Key Vault exists
✓ Client Secret exists in Key Vault

Testing App Service Authentication...
✓ App Service exists
✓ Authentication enabled
✓ Azure AD provider configured

Testing App Service URL...
✓ Redirects to Azure AD login

========================================
Test Summary
========================================
Total Tests:  10
Passed:       10
Failed:       0

✓ All tests passed!
```

## Files in This Directory

- **Register-AADApp.ps1**: Main script for AAD app registration
- **Test-AADAuthentication.ps1**: Test script to validate AAD configuration
- **README.md**: This documentation file
- **logs/**: Directory for log files (created automatically)
- **aad-config-{env}.json**: Generated configuration files (excluded from git)

## Additional Resources

- [Azure AD App Registration Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [App Service Authentication Documentation](https://docs.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad)
- [Microsoft Graph API Permissions](https://docs.microsoft.com/en-us/graph/permissions-reference)
