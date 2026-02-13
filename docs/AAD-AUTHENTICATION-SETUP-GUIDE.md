# Azure Active Directory Authentication Setup Guide

This guide provides comprehensive instructions for setting up and configuring Azure Active Directory (AAD) authentication for the KBudget GPT application.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Setup Steps](#setup-steps)
4. [Configuration](#configuration)
5. [Testing](#testing)
6. [User Management](#user-management)
7. [Troubleshooting](#troubleshooting)
8. [Security Best Practices](#security-best-practices)

## Overview

Azure Active Directory authentication provides:

- **Enterprise-Grade Security**: OAuth 2.0 and OpenID Connect protocols
- **Single Sign-On (SSO)**: Users authenticate with their organizational credentials
- **Role-Based Access Control**: Separate Admin and User roles
- **Centralized Management**: User access managed through Azure AD
- **Audit Logging**: Complete audit trail of authentication events
- **Multi-Factor Authentication**: Optional MFA support

### Architecture

```
User Browser → App Service → Azure AD
                    ↓
              Authentication
                    ↓
          Token Store (Session)
                    ↓
            Application Access
```

## Prerequisites

### For DevOps/Administrators

1. **Azure Subscription** with appropriate permissions
2. **Azure PowerShell Module**:
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   ```
3. **Azure AD Permissions**:
   - Application Administrator role **OR**
   - Global Administrator role
4. **Resource Permissions**:
   - Contributor or Owner on the resource group

### For Developers

1. **Azure Account** with access to the application
2. **Assigned Role**: Admin or User role in the AAD application
3. **Development Tools**: Visual Studio, VS Code, or preferred IDE
4. **Browser**: Modern browser (Chrome, Edge, Firefox)

## Setup Steps

### Step 1: Register Azure AD Application

Run the AAD registration script for your environment:

```powershell
# Navigate to the AAD app registration directory
cd infrastructure/arm-templates/aad-app-registration

# Register for development environment
.\Register-AADApp.ps1 -Environment dev

# Register for staging environment
.\Register-AADApp.ps1 -Environment staging

# Register for production environment
.\Register-AADApp.ps1 -Environment prod
```

**Output:**
The script will output:
- Tenant ID
- Application (Client) ID
- Client Secret
- Application Object ID

**IMPORTANT:** Save these values securely. The client secret cannot be retrieved later.

### Step 2: Store Client Secret in Azure Key Vault

```powershell
# Load the AAD configuration
$aadConfig = Get-Content "infrastructure/arm-templates/aad-app-registration/aad-config-dev.json" | ConvertFrom-Json

# Store the client secret in Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $aadConfig.ClientSecret -AsPlainText -Force)

Write-Host "Client secret stored in Key Vault: kbudget-dev-kv" -ForegroundColor Green
```

### Step 3: Grant Admin Consent for API Permissions

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to **Azure Active Directory** > **App registrations**
3. Find your application: `KBudget GPT - Development`
4. Click **API permissions**
5. Review the permissions:
   - Microsoft Graph → User.Read (Delegated)
6. Click **Grant admin consent for {Your Organization}**
7. Confirm the consent

### Step 4: Configure App Roles (Optional but Recommended)

App roles are automatically configured by the registration script. To verify:

1. In Azure Portal, go to your app registration
2. Click **App roles**
3. Verify the following roles exist:
   - **Administrator**: Full access to all features
   - **User**: Access to budget management features

### Step 5: Deploy App Service with AAD Authentication

Update the App Service parameter file:

**File:** `infrastructure/arm-templates/app-service/parameters.dev.json`

```json
{
  "enableAadAuthentication": {
    "value": true
  },
  "aadClientId": {
    "value": "YOUR_CLIENT_ID_HERE"
  },
  "aadTenantId": {
    "value": "YOUR_TENANT_ID_HERE"
  }
}
```

Deploy the App Service:

```powershell
# Navigate to app service directory
cd infrastructure/arm-templates/app-service

# Get client secret from Key Vault
$secret = Get-AzKeyVaultSecret -VaultName "kbudget-dev-kv" -Name "AAD-ClientSecret" -AsPlainText

# Deploy with AAD authentication enabled
New-AzResourceGroupDeployment `
    -Name "app-service-aad-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "app-service.json" `
    -TemplateParameterFile "parameters.dev.json" `
    -aadClientSecret $secret
```

### Step 6: Verify Deployment

```powershell
# Check App Service authentication configuration
$webApp = Get-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"
$authSettings = Get-AzWebAppAuthSettings -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"

Write-Host "Authentication Enabled: $($authSettings.Enabled)" -ForegroundColor Cyan
Write-Host "Default Provider: $($authSettings.DefaultProvider)" -ForegroundColor Cyan
```

## Configuration

### Environment-Specific Configuration

#### Development
- **Purpose**: Testing and development
- **AAD App**: `KBudget GPT - Development`
- **URL**: `https://kbudget-dev-app.azurewebsites.net`
- **Users**: Development team members

#### Staging
- **Purpose**: Pre-production testing
- **AAD App**: `KBudget GPT - Staging`
- **URL**: `https://kbudget-staging-app.azurewebsites.net`
- **Users**: QA team and stakeholders

#### Production
- **Purpose**: Live application
- **AAD App**: `KBudget GPT - Production`
- **URL**: `https://kbudget-prod-app.azurewebsites.net`
- **Users**: End users and administrators

### Authentication Settings

The following settings are configured by the ARM template:

- **Authentication Provider**: Azure Active Directory
- **Require Authentication**: Yes
- **Unauthenticated Action**: Redirect to login page
- **Token Store**: Enabled (for session management)
- **Allowed Audiences**: `api://{ClientId}`

## Testing

### Testing as Administrator

1. **Assign Admin Role**:
   ```powershell
   # Get your user object ID
   $userId = (Get-AzADUser -UserPrincipalName "admin@yourdomain.com").Id
   
   # Get the app
   $app = Get-AzADApplication -DisplayName "KBudget GPT - Development"
   
   # Assign admin role (use Azure Portal for role assignment)
   ```

2. **Access the Application**:
   - Open browser and navigate to: `https://kbudget-dev-app.azurewebsites.net`
   - You'll be redirected to Microsoft login page
   - Sign in with your organizational credentials
   - Grant consent if prompted
   - Verify you're redirected to the application
   - Verify you have admin-level access

3. **Verify Admin Permissions**:
   - Check that all admin features are accessible
   - Verify you can access administrative sections
   - Test admin-specific functionality

### Testing as Standard User

1. **Assign User Role**:
   - In Azure Portal, go to **Enterprise applications**
   - Find `KBudget GPT - Development`
   - Go to **Users and groups**
   - Add a test user with the **User** role

2. **Access the Application**:
   - Open browser in incognito/private mode
   - Navigate to: `https://kbudget-dev-app.azurewebsites.net`
   - Sign in with the test user credentials
   - Verify you're redirected to the application

3. **Verify User Permissions**:
   - Verify standard features are accessible
   - Verify admin features are NOT accessible
   - Test user-specific functionality

### Testing Sign-Out

1. Navigate to: `https://kbudget-dev-app.azurewebsites.net/.auth/logout`
2. Verify you're signed out
3. Navigate back to the app
4. Verify you're redirected to the login page

### Automated Testing

Create a test script to verify authentication:

```powershell
# Test-AADAuthentication.ps1
param(
    [string]$AppUrl = "https://kbudget-dev-app.azurewebsites.net"
)

Write-Host "Testing AAD Authentication..." -ForegroundColor Cyan

# Test 1: Verify unauthenticated access redirects to login
$response = Invoke-WebRequest -Uri $AppUrl -MaximumRedirection 0 -ErrorAction SilentlyContinue
if ($response.StatusCode -eq 302 -and $response.Headers.Location -like "*login.microsoftonline.com*") {
    Write-Host "✓ Unauthenticated redirect works" -ForegroundColor Green
} else {
    Write-Host "✗ Unauthenticated redirect failed" -ForegroundColor Red
}

# Test 2: Verify auth endpoints are accessible
$authConfig = Invoke-RestMethod -Uri "$AppUrl/.auth/me" -ErrorAction SilentlyContinue
if ($authConfig) {
    Write-Host "✓ Auth configuration endpoint works" -ForegroundColor Green
} else {
    Write-Host "✗ Auth configuration endpoint failed" -ForegroundColor Red
}

Write-Host "Testing complete!" -ForegroundColor Cyan
```

## User Management

### Adding Users

#### Via Azure Portal

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to **Enterprise applications**
3. Find your app: `KBudget GPT - {Environment}`
4. Click **Users and groups**
5. Click **Add user/group**
6. Select users and assign role (Administrator or User)
7. Click **Assign**

#### Via PowerShell

```powershell
# Add user with User role
$userId = (Get-AzADUser -UserPrincipalName "user@yourdomain.com").Id
$appId = (Get-AzADApplication -DisplayName "KBudget GPT - Development").Id

# Note: Role assignment requires using Azure Portal or Azure CLI
# PowerShell does not have direct cmdlets for app role assignment
```

### Removing Users

1. Go to **Enterprise applications** > Your app
2. Click **Users and groups**
3. Select the user
4. Click **Remove**

### Changing User Roles

1. Remove the user from their current role
2. Re-add the user with the new role

## Troubleshooting

### Issue: "AADSTS50011: The reply URL specified in the request does not match"

**Cause**: Redirect URI mismatch

**Solution**:
1. Verify the redirect URIs in your AAD app registration
2. Ensure they match your App Service URL:
   - `https://{app-name}.azurewebsites.net/.auth/login/aad/callback`
   - `https://{app-name}.azurewebsites.net/signin-oidc`

### Issue: "AADSTS700016: Application with identifier 'X' was not found"

**Cause**: Client ID is incorrect

**Solution**:
1. Verify the client ID in your parameter file matches the AAD app
2. Check the `aadClientId` parameter value
3. Re-run the registration script if needed

### Issue: "User is signed in but gets access denied"

**Cause**: User is not assigned to an app role

**Solution**:
1. Go to Enterprise applications > Your app > Users and groups
2. Verify the user is listed
3. If not, add the user with appropriate role
4. Have the user sign out and sign in again

### Issue: "Client secret has expired"

**Cause**: The client secret has passed its expiration date

**Solution**:
```powershell
# Create a new secret
$app = Get-AzADApplication -DisplayName "KBudget GPT - Development"
$newSecret = New-AzADAppCredential -ApplicationId $app.AppId -EndDate (Get-Date).AddDays(365)

# Update Key Vault
Set-AzKeyVaultSecret `
    -VaultName "kbudget-dev-kv" `
    -Name "AAD-ClientSecret" `
    -SecretValue (ConvertTo-SecureString $newSecret.SecretText -AsPlainText -Force)

# Restart the App Service
Restart-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"
```

### Issue: "Infinite redirect loop"

**Cause**: Authentication configuration error

**Solution**:
1. Check the authentication settings in Azure Portal
2. Verify the issuer URL is correct
3. Restart the App Service
4. Clear browser cookies and try again

### Enable Diagnostic Logging

```powershell
# Enable authentication logging
Set-AzWebApp `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudget-dev-app" `
    -DetailedErrorLoggingEnabled $true `
    -HttpLoggingEnabled $true `
    -RequestTracingEnabled $true
```

## Security Best Practices

### ✅ DO:

1. **Use Separate AAD Apps per Environment**
   - Development, Staging, and Production should each have their own AAD app
   - Prevents cross-environment access issues

2. **Rotate Client Secrets Regularly**
   - Set up calendar reminders for secret expiration
   - Rotate secrets before they expire
   - Use Azure Key Vault for secret storage

3. **Use Least Privilege**
   - Assign users only the roles they need
   - Limit Administrator role to necessary personnel
   - Review user assignments regularly

4. **Enable Audit Logging**
   - Configure diagnostic settings
   - Send logs to Log Analytics workspace
   - Set up alerts for suspicious activity

5. **Review API Permissions**
   - Only request permissions you actually need
   - Document why each permission is required
   - Review permissions annually

6. **Use Multi-Factor Authentication**
   - Enforce MFA for admin accounts
   - Consider requiring MFA for all users
   - Configure Conditional Access policies

### ❌ DON'T:

1. **Don't Commit Secrets to Source Control**
   - Always use Key Vault
   - Never put secrets in parameter files
   - Use `.gitignore` to exclude config files

2. **Don't Share Client Secrets**
   - Don't send secrets via email or chat
   - Don't store secrets in wikis or documentation
   - Use Key Vault access policies to control access

3. **Don't Use the Same AAD App for Multiple Environments**
   - Creates security risks
   - Makes troubleshooting difficult
   - Can lead to production data exposure

4. **Don't Ignore Expiration Warnings**
   - Set up monitoring for secret expiration
   - Rotate secrets proactively
   - Have a documented rotation process

5. **Don't Grant Admin Consent Without Review**
   - Understand what permissions you're granting
   - Review the impact on user privacy
   - Document the business justification

## Monitoring and Maintenance

### Regular Tasks

**Weekly:**
- Review sign-in logs for anomalies
- Check for failed authentication attempts

**Monthly:**
- Review user access and roles
- Audit admin role assignments
- Verify app registration settings

**Quarterly:**
- Review and update API permissions
- Audit diagnostic log retention
- Test disaster recovery procedures

**Annually:**
- Rotate client secrets
- Review and update documentation
- Audit security configuration

### Monitoring Queries

Use Log Analytics to monitor authentication:

```kusto
// Failed sign-in attempts
SigninLogs
| where ResultType != 0
| where AppDisplayName == "KBudget GPT - Development"
| summarize count() by UserPrincipalName, ResultType
| order by count_ desc

// Successful sign-ins by role
SigninLogs
| where ResultType == 0
| where AppDisplayName == "KBudget GPT - Development"
| extend Role = tostring(parse_json(AuthenticationDetails)[0].authenticationMethod)
| summarize count() by UserPrincipalName, Role
```

## Additional Resources

### Microsoft Documentation
- [Azure AD App Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [App Service Authentication](https://docs.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad)
- [Microsoft Graph Permissions](https://docs.microsoft.com/en-us/graph/permissions-reference)
- [OAuth 2.0 and OpenID Connect](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-protocols)

### Internal Documentation
- [AAD App Registration Script](../infrastructure/arm-templates/aad-app-registration/README.md)
- [App Service ARM Template](../infrastructure/arm-templates/app-service/README.md)
- [Main Deployment Guide](../infrastructure/arm-templates/main-deployment/README.md)

### Support
For issues or questions:
- Create an issue in the repository
- Contact the DevOps team
- Consult Azure Support for platform issues
