################################################################################
# AAD Authentication Test Script
# 
# Purpose: Test AAD app registration and App Service authentication configuration
# Features:
#   - Validates AAD app registration exists
#   - Checks API permissions
#   - Verifies redirect URIs
#   - Tests App Service authentication configuration
#   - Validates client secret in Key Vault
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - AAD app registration completed
#   - App Service deployed
#
# Usage:
#   .\Test-AADAuthentication.ps1 -Environment dev
#   .\Test-AADAuthentication.ps1 -Environment staging
#   .\Test-AADAuthentication.ps1 -Environment prod
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

$ErrorActionPreference = "Continue"

# Environment mappings
$EnvMap = @{
    "dev"     = "Development"
    "staging" = "Staging"
    "prod"    = "Production"
}

$EnvName = $EnvMap[$Environment]
$AppDisplayName = "KBudget GPT - $EnvName"
$ResourceGroupName = "kbudget-$Environment-rg"
$AppServiceName = "kbudget-$Environment-app"
$KeyVaultName = "kbudget-$Environment-kv"

$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

################################################################################
# Helper Functions
################################################################################

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Message = ""
    )
    
    $script:TotalTests++
    
    if ($Success) {
        Write-Host "✓ $TestName" -ForegroundColor Green
        $script:PassedTests++
    }
    else {
        Write-Host "✗ $TestName" -ForegroundColor Red
        $script:FailedTests++
    }
    
    if ($Message) {
        Write-Host "  $Message" -ForegroundColor Yellow
    }
}

################################################################################
# Test Functions
################################################################################

function Test-Prerequisites {
    Write-Host "`nTesting Prerequisites..." -ForegroundColor Cyan
    
    # Test Azure authentication
    try {
        $context = Get-AzContext
        Write-TestResult -TestName "Azure Authentication" -Success ($null -ne $context) -Message "Authenticated as: $($context.Account.Id)"
    }
    catch {
        Write-TestResult -TestName "Azure Authentication" -Success $false -Message "Not authenticated to Azure"
    }
}

function Test-AADAppRegistration {
    Write-Host "`nTesting AAD App Registration..." -ForegroundColor Cyan
    
    # Test app exists
    try {
        $app = Get-AzADApplication -DisplayName $AppDisplayName -ErrorAction SilentlyContinue
        
        if ($app) {
            Write-TestResult -TestName "AAD Application exists" -Success $true -Message "App ID: $($app.AppId)"
            
            # Test redirect URIs
            $expectedUris = @(
                "https://$AppServiceName.azurewebsites.net/.auth/login/aad/callback",
                "https://$AppServiceName.azurewebsites.net/signin-oidc"
            )
            
            $redirectUris = $app.Web.RedirectUri
            $hasCorrectUris = $true
            foreach ($uri in $expectedUris) {
                if ($redirectUris -notcontains $uri) {
                    $hasCorrectUris = $false
                    break
                }
            }
            
            Write-TestResult -TestName "Redirect URIs configured" -Success $hasCorrectUris -Message "Expected URIs: $($expectedUris -join ', ')"
            
            # Test app roles
            if ($app.AppRole -and $app.AppRole.Count -gt 0) {
                Write-TestResult -TestName "App Roles configured" -Success $true -Message "Found $($app.AppRole.Count) roles"
            }
            else {
                Write-TestResult -TestName "App Roles configured" -Success $false -Message "No app roles found"
            }
        }
        else {
            Write-TestResult -TestName "AAD Application exists" -Success $false -Message "App '$AppDisplayName' not found"
        }
    }
    catch {
        Write-TestResult -TestName "AAD Application exists" -Success $false -Message "Error: $_"
    }
}

function Test-KeyVaultSecret {
    Write-Host "`nTesting Key Vault Secret..." -ForegroundColor Cyan
    
    try {
        # Check if Key Vault exists
        $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
        
        if ($keyVault) {
            Write-TestResult -TestName "Key Vault exists" -Success $true -Message "Name: $KeyVaultName"
            
            # Check if secret exists
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "AAD-ClientSecret" -ErrorAction SilentlyContinue
                
                if ($secret) {
                    Write-TestResult -TestName "Client Secret exists in Key Vault" -Success $true -Message "Expires: $($secret.Attributes.Expires)"
                }
                else {
                    Write-TestResult -TestName "Client Secret exists in Key Vault" -Success $false -Message "Secret 'AAD-ClientSecret' not found"
                }
            }
            catch {
                Write-TestResult -TestName "Client Secret exists in Key Vault" -Success $false -Message "Error accessing secret: $_"
            }
        }
        else {
            Write-TestResult -TestName "Key Vault exists" -Success $false -Message "Key Vault '$KeyVaultName' not found"
        }
    }
    catch {
        Write-TestResult -TestName "Key Vault exists" -Success $false -Message "Error: $_"
    }
}

function Test-AppServiceAuthentication {
    Write-Host "`nTesting App Service Authentication..." -ForegroundColor Cyan
    
    try {
        # Check if App Service exists
        $appService = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction SilentlyContinue
        
        if ($appService) {
            Write-TestResult -TestName "App Service exists" -Success $true -Message "Name: $AppServiceName"
            
            # Check authentication settings
            try {
                # Note: Getting auth settings V2 requires special handling
                $authSettings = Invoke-AzResourceAction `
                    -ResourceGroupName $ResourceGroupName `
                    -ResourceType "Microsoft.Web/sites/config" `
                    -ResourceName "$AppServiceName/authsettingsV2" `
                    -Action list `
                    -ApiVersion "2022-03-01" `
                    -Force `
                    -ErrorAction SilentlyContinue
                
                if ($authSettings -and $authSettings.properties.platform.enabled) {
                    Write-TestResult -TestName "Authentication enabled" -Success $true
                    
                    $aadConfig = $authSettings.properties.identityProviders.azureActiveDirectory
                    if ($aadConfig -and $aadConfig.enabled) {
                        Write-TestResult -TestName "Azure AD provider configured" -Success $true -Message "Client ID: $($aadConfig.registration.clientId)"
                    }
                    else {
                        Write-TestResult -TestName "Azure AD provider configured" -Success $false -Message "Azure AD provider not enabled"
                    }
                }
                else {
                    Write-TestResult -TestName "Authentication enabled" -Success $false -Message "Authentication not enabled or using V1 settings"
                }
            }
            catch {
                Write-TestResult -TestName "Authentication configuration" -Success $false -Message "Could not retrieve auth settings: $_"
            }
        }
        else {
            Write-TestResult -TestName "App Service exists" -Success $false -Message "App Service '$AppServiceName' not found"
        }
    }
    catch {
        Write-TestResult -TestName "App Service exists" -Success $false -Message "Error: $_"
    }
}

function Test-AppServiceUrl {
    Write-Host "`nTesting App Service URL..." -ForegroundColor Cyan
    
    try {
        $appService = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction SilentlyContinue
        
        if ($appService) {
            $url = "https://$($appService.DefaultHostName)"
            Write-Host "  App URL: $url" -ForegroundColor Cyan
            
            try {
                # Test if the URL redirects to login
                $response = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -ErrorAction SilentlyContinue
            }
            catch {
                # We expect a redirect (302) which throws an error
                if ($_.Exception.Response.StatusCode -eq 302) {
                    $location = $_.Exception.Response.Headers.Location
                    if ($location -like "*login.microsoftonline.com*") {
                        Write-TestResult -TestName "Redirects to Azure AD login" -Success $true -Message "Location: $location"
                    }
                    else {
                        Write-TestResult -TestName "Redirects to Azure AD login" -Success $false -Message "Unexpected redirect: $location"
                    }
                }
                else {
                    Write-TestResult -TestName "Redirects to Azure AD login" -Success $false -Message "Unexpected response: $($_.Exception.Response.StatusCode)"
                }
            }
        }
    }
    catch {
        Write-TestResult -TestName "App Service URL test" -Success $false -Message "Error: $_"
    }
}

################################################################################
# Main Execution
################################################################################

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AAD Authentication Test Suite" -ForegroundColor Cyan
Write-Host "Environment: $EnvName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Test-Prerequisites
Test-AADAppRegistration
Test-KeyVaultSecret
Test-AppServiceAuthentication
Test-AppServiceUrl

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests:  $TotalTests" -ForegroundColor Cyan
Write-Host "Passed:       $PassedTests" -ForegroundColor Green
Write-Host "Failed:       $FailedTests" -ForegroundColor $(if ($FailedTests -gt 0) { "Red" } else { "Green" })

if ($FailedTests -eq 0) {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n✗ Some tests failed. Please review the errors above." -ForegroundColor Red
    exit 1
}
