################################################################################
# Azure Active Directory App Registration Script
# 
# Purpose: Register and configure an AAD application for KBudget GPT
# Features:
#   - Creates AAD app registration
#   - Configures API permissions (Microsoft Graph)
#   - Sets up redirect URIs for web app authentication
#   - Creates client secret for service authentication
#   - Configures app roles for admin and user access
#   - Outputs configuration values for App Service
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Azure AD PowerShell module (Az.Resources)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Proper permissions (Application Administrator or Global Administrator)
#
# Usage:
#   .\Register-AADApp.ps1 -Environment dev
#   .\Register-AADApp.ps1 -Environment staging
#   .\Register-AADApp.ps1 -Environment prod
#   .\Register-AADApp.ps1 -Environment dev -AppServiceUrl "https://kbudget-dev-app.azurewebsites.net"
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$AppServiceUrl,

    [Parameter(Mandatory = $false)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [int]$SecretExpirationDays = 365,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "aad_registration_$($Environment)_$Timestamp.log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Environment mappings
$EnvMap = @{
    "dev"     = "Development"
    "staging" = "Staging"
    "prod"    = "Production"
}

$EnvName = $EnvMap[$Environment]
$AppDisplayName = if ($DisplayName) { $DisplayName } else { "KBudget GPT - $EnvName" }

# Default App Service URL if not provided
if (-not $AppServiceUrl) {
    $AppServiceUrl = "https://kbudget-$Environment-app.azurewebsites.net"
}

################################################################################
# Logging Functions
################################################################################

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Level] $TimeStamp - $Message"
    
    # Color coding for console output
    switch ($Level) {
        "INFO"    { Write-Host $LogMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage
}

################################################################################
# Validation Functions
################################################################################

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level "INFO"
    
    # Check if Az module is installed
    if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Log "Az.Resources module is not installed. Install it using: Install-Module -Name Az.Resources" -Level "ERROR"
        throw "Missing required module: Az.Resources"
    }
    
    # Check Azure authentication
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not authenticated to Azure. Run Connect-AzAccount first." -Level "ERROR"
            throw "Not authenticated to Azure"
        }
        Write-Log "Authenticated as: $($context.Account.Id)" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error checking Azure authentication: $_" -Level "ERROR"
        throw
    }
    
    Write-Log "All prerequisites validated successfully" -Level "SUCCESS"
}

################################################################################
# AAD App Registration Functions
################################################################################

function New-AADAppRegistration {
    param(
        [string]$DisplayName,
        [string]$AppServiceUrl
    )
    
    Write-Log "Creating AAD App Registration: $DisplayName" -Level "INFO"
    
    if ($WhatIf) {
        Write-Log "[WHATIF] Would create AAD app registration: $DisplayName" -Level "WARNING"
        return $null
    }
    
    try {
        # Check if app already exists
        $existingApp = Get-AzADApplication -DisplayName $DisplayName -ErrorAction SilentlyContinue
        
        if ($existingApp) {
            Write-Log "App registration '$DisplayName' already exists. Using existing app." -Level "WARNING"
            return $existingApp
        }
        
        # Define redirect URIs
        $redirectUris = @(
            "$AppServiceUrl/.auth/login/aad/callback"
            "$AppServiceUrl/signin-oidc"
        )
        
        # Create the application with web platform
        $webApp = @{
            RedirectUri = $redirectUris
        }
        
        $app = New-AzADApplication `
            -DisplayName $DisplayName `
            -SignInAudience "AzureADMyOrg" `
            -Web $webApp
        
        Write-Log "AAD App Registration created successfully" -Level "SUCCESS"
        Write-Log "Application ID: $($app.AppId)" -Level "INFO"
        
        return $app
    }
    catch {
        Write-Log "Error creating AAD app registration: $_" -Level "ERROR"
        throw
    }
}

function Set-AADAppPermissions {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication]$Application
    )
    
    Write-Log "Configuring API permissions for app..." -Level "INFO"
    
    if ($WhatIf) {
        Write-Log "[WHATIF] Would configure API permissions" -Level "WARNING"
        return
    }
    
    try {
        # Microsoft Graph API ID
        $graphApiId = "00000003-0000-0000-c000-000000000000"
        
        # Define required permissions
        # User.Read: Sign in and read user profile (delegated permission)
        $userReadPermissionId = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
        
        # Create the resource access object
        $resourceAccess = @{
            Id = $userReadPermissionId
            Type = "Scope"  # Scope = Delegated permission
        }
        
        # Create the required resource access object for Microsoft Graph
        $requiredResourceAccess = @{
            ResourceAppId = $graphApiId
            ResourceAccess = @($resourceAccess)
        }
        
        # Update the application with required permissions
        # Note: This sets the permissions but admin consent is still required.
        # Admin consent can be granted via:
        # 1. Azure Portal: App registrations > Your app > API permissions > Grant admin consent
        # 2. PowerShell (if available): Grant-AzADAppPermission cmdlet
        # 3. URL: https://login.microsoftonline.com/{tenantId}/adminconsent?client_id={clientId}
        Update-AzADApplication `
            -ObjectId $Application.Id `
            -RequiredResourceAccess @($requiredResourceAccess)
        
        Write-Log "API permissions configured successfully" -Level "SUCCESS"
        Write-Log "Note: Admin consent may be required for the permissions" -Level "WARNING"
        Write-Log "Grant consent via Azure Portal or use the admin consent URL" -Level "INFO"
    }
    catch {
        Write-Log "Error configuring API permissions: $_" -Level "ERROR"
        throw
    }
}

function New-AADAppSecret {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication]$Application,
        [int]$ExpirationDays
    )
    
    Write-Log "Creating client secret for app..." -Level "INFO"
    
    if ($WhatIf) {
        Write-Log "[WHATIF] Would create client secret" -Level "WARNING"
        return "whatif-secret-value"
    }
    
    try {
        # Create a new client secret
        $endDate = (Get-Date).AddDays($ExpirationDays)
        
        $secret = New-AzADAppCredential `
            -ApplicationId $Application.AppId `
            -EndDate $endDate
        
        Write-Log "Client secret created successfully" -Level "SUCCESS"
        Write-Log "Secret expires on: $($endDate.ToString('yyyy-MM-dd'))" -Level "INFO"
        Write-Log "IMPORTANT: Save the secret value securely. It cannot be retrieved later." -Level "WARNING"
        
        return $secret.SecretText
    }
    catch {
        Write-Log "Error creating client secret: $_" -Level "ERROR"
        throw
    }
}

function New-AADAppRoles {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication]$Application
    )
    
    Write-Log "Configuring app roles..." -Level "INFO"
    
    if ($WhatIf) {
        Write-Log "[WHATIF] Would configure app roles" -Level "WARNING"
        return
    }
    
    try {
        # Check if app roles already exist
        $existingRoles = $Application.AppRole
        
        if ($existingRoles -and $existingRoles.Count -gt 0) {
            Write-Log "App roles already exist on the application. Checking for required roles..." -Level "INFO"
            
            # Check if Admin and User roles already exist
            $hasAdminRole = $existingRoles | Where-Object { $_.Value -eq "Admin" }
            $hasUserRole = $existingRoles | Where-Object { $_.Value -eq "User" }
            
            if ($hasAdminRole -and $hasUserRole) {
                Write-Log "Required app roles (Admin, User) already exist. Skipping role creation." -Level "SUCCESS"
                return
            }
            else {
                Write-Log "Some required roles are missing. Please manage app roles manually in Azure Portal." -Level "WARNING"
                Write-Log "Skipping app role configuration to preserve existing roles." -Level "WARNING"
                return
            }
        }
        
        # Define app roles (only if no existing roles)
        $adminRole = @{
            AllowedMemberTypes = @("User")
            Description = "Administrators have full access to all features"
            DisplayName = "Administrator"
            Id = [Guid]::NewGuid().ToString()
            IsEnabled = $true
            Value = "Admin"
        }
        
        $userRole = @{
            AllowedMemberTypes = @("User")
            Description = "Standard users have access to budget management features"
            DisplayName = "User"
            Id = [Guid]::NewGuid().ToString()
            IsEnabled = $true
            Value = "User"
        }
        
        # Update the application with app roles
        Update-AzADApplication `
            -ObjectId $Application.Id `
            -AppRole @($adminRole, $userRole)
        
        Write-Log "App roles configured successfully" -Level "SUCCESS"
        Write-Log "Created roles: Administrator, User" -Level "INFO"
    }
    catch {
        Write-Log "Error configuring app roles: $_" -Level "ERROR"
        # Don't throw - app roles are nice to have but not critical
        Write-Log "Continuing without app roles..." -Level "WARNING"
    }
}

################################################################################
# Main Execution
################################################################################

function Main {
    Write-Log "========================================" -Level "INFO"
    Write-Log "AAD App Registration Script" -Level "INFO"
    Write-Log "Environment: $EnvName" -Level "INFO"
    Write-Log "App Service URL: $AppServiceUrl" -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    try {
        # Validate prerequisites
        Test-Prerequisites
        
        # Create AAD app registration
        $app = New-AADAppRegistration -DisplayName $AppDisplayName -AppServiceUrl $AppServiceUrl
        
        if (-not $WhatIf -and $app) {
            # Configure API permissions
            Set-AADAppPermissions -Application $app
            
            # Create client secret
            $secretValue = New-AADAppSecret -Application $app -ExpirationDays $SecretExpirationDays
            
            # Configure app roles
            New-AADAppRoles -Application $app
            
            # Get tenant ID
            $context = Get-AzContext
            $tenantId = $context.Tenant.Id
            
            Write-Log "========================================" -Level "SUCCESS"
            Write-Log "AAD App Registration Complete!" -Level "SUCCESS"
            Write-Log "========================================" -Level "SUCCESS"
            Write-Log "" -Level "INFO"
            Write-Log "Configuration Values (save these securely):" -Level "INFO"
            Write-Log "  Tenant ID:        $tenantId" -Level "INFO"
            Write-Log "  Application ID:   $($app.AppId)" -Level "INFO"
            Write-Log "  Client Secret:    $secretValue" -Level "INFO"
            Write-Log "  App Service URL:  $AppServiceUrl" -Level "INFO"
            Write-Log "" -Level "INFO"
            Write-Log "Next Steps:" -Level "INFO"
            Write-Log "1. Store the Client Secret in Azure Key Vault" -Level "INFO"
            Write-Log "2. Grant admin consent for API permissions (if required)" -Level "INFO"
            Write-Log "3. Assign users to app roles in Azure Portal" -Level "INFO"
            Write-Log "4. Configure App Service authentication using these values" -Level "INFO"
            Write-Log "" -Level "INFO"
            
            # Output as object for pipeline
            $output = @{
                TenantId = $tenantId
                ClientId = $app.AppId
                ClientSecret = $secretValue
                ApplicationObjectId = $app.Id
                AppServiceUrl = $AppServiceUrl
                Environment = $EnvName
            }
            
            # Save output to file
            $outputFile = Join-Path $ScriptDir "aad-config-$Environment.json"
            $output | ConvertTo-Json | Out-File -FilePath $outputFile -Force
            Write-Log "Configuration saved to: $outputFile" -Level "SUCCESS"
            
            return $output
        }
    }
    catch {
        Write-Log "========================================" -Level "ERROR"
        Write-Log "AAD App Registration Failed!" -Level "ERROR"
        Write-Log "Error: $_" -Level "ERROR"
        Write-Log "========================================" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
