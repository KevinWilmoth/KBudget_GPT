################################################################################
# Application Gateway with WAF Deployment Script
# 
# Purpose: Deploy Azure Application Gateway with Web Application Firewall (WAF)
# Features:
#   - Deploys Application Gateway with WAF v2 SKU
#   - Configures OWASP rule set for threat protection
#   - Sets up HTTP and HTTPS listeners
#   - Configures backend pool pointing to App Service
#   - Supports custom SSL certificates
#   - Configures health probes for backend monitoring
#   - Supports dev, staging, and production environments
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Virtual Network and subnet must exist
#   - App Service must be deployed and accessible
#   - Proper permissions (Contributor or Owner)
#
# Usage:
#   .\Deploy-ApplicationGateway.ps1 -Environment dev
#   .\Deploy-ApplicationGateway.ps1 -Environment staging
#   .\Deploy-ApplicationGateway.ps1 -Environment prod
#   .\Deploy-ApplicationGateway.ps1 -Environment dev -SslCertificatePath ".\cert.pfx" -SslCertificatePassword "password"
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [ValidateSet("eastus", "westus", "westus2", "centralus", "northeurope", "westeurope")]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$SslCertificatePath = "",

    [Parameter(Mandatory = $false)]
    [securestring]$SslCertificatePassword,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateFile = Join-Path $ScriptDir "application-gateway.json"
$ParameterFile = Join-Path $ScriptDir "parameters.$Environment.json"
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "deployment_$($Environment)_$Timestamp.log"

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
$ResourceGroupName = "kbudget-$Environment-rg"

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

function Write-SectionHeader {
    param([string]$Title)
    
    $separator = "=" * 80
    Write-Log ""
    Write-Log $separator
    Write-Log $Title
    Write-Log $separator
}

################################################################################
# Validation Functions
################################################################################

function Test-Prerequisites {
    Write-SectionHeader "VALIDATING PREREQUISITES"
    
    # Check Azure PowerShell module
    Write-Log "Checking Azure PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name Az)) {
        Write-Log "Azure PowerShell module (Az) is not installed" "ERROR"
        throw "Please install Azure PowerShell: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
    }
    Write-Log "Azure PowerShell module is installed" "SUCCESS"
    
    # Check Azure authentication
    Write-Log "Checking Azure authentication..."
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "Not authenticated"
        }
        Write-Log "Authenticated as: $($context.Account.Id)" "SUCCESS"
        Write-Log "Subscription: $($context.Subscription.Name)" "INFO"
    }
    catch {
        Write-Log "Not authenticated to Azure" "ERROR"
        throw "Please run Connect-AzAccount first"
    }
    
    # Check template file exists
    Write-Log "Checking template file..."
    if (-not (Test-Path $TemplateFile)) {
        Write-Log "Template file not found: $TemplateFile" "ERROR"
        throw "Template file is missing"
    }
    Write-Log "Template file found" "SUCCESS"
    
    # Check parameter file exists
    Write-Log "Checking parameter file..."
    if (-not (Test-Path $ParameterFile)) {
        Write-Log "Parameter file not found: $ParameterFile" "ERROR"
        throw "Parameter file is missing"
    }
    Write-Log "Parameter file found" "SUCCESS"
    
    # Validate resource group exists
    Write-Log "Checking resource group..."
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Log "Resource group '$ResourceGroupName' does not exist" "ERROR"
        throw "Please create the resource group first or run the main deployment script"
    }
    Write-Log "Resource group '$ResourceGroupName' exists" "SUCCESS"
}

function Test-VirtualNetwork {
    param(
        [string]$ResourceGroupName,
        [string]$VNetName,
        [string]$SubnetName
    )
    
    Write-Log "Validating Virtual Network and subnet..."
    
    # Check VNet exists
    $vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vnet) {
        Write-Log "Virtual Network '$VNetName' not found in resource group '$ResourceGroupName'" "ERROR"
        throw "Virtual Network must exist before deploying Application Gateway"
    }
    Write-Log "Virtual Network '$VNetName' found" "SUCCESS"
    
    # Check subnet exists
    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $SubnetName }
    if (-not $subnet) {
        Write-Log "Subnet '$SubnetName' not found in Virtual Network '$VNetName'" "ERROR"
        throw "Subnet must exist before deploying Application Gateway"
    }
    Write-Log "Subnet '$SubnetName' found" "SUCCESS"
    
    # Check subnet is large enough (at least /24 for Application Gateway)
    $subnetPrefix = $subnet.AddressPrefix
    $prefixLength = [int]($subnetPrefix -split '/')[1]
    if ($prefixLength -gt 24) {
        Write-Log "Subnet prefix length is /$prefixLength (requires at least /24)" "WARNING"
    }
    
    return $true
}

function Test-AppService {
    param(
        [string]$ResourceGroupName,
        [string]$AppServiceName
    )
    
    Write-Log "Validating App Service backend..."
    
    $appService = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction SilentlyContinue
    if (-not $appService) {
        Write-Log "App Service '$AppServiceName' not found" "WARNING"
        Write-Log "Deployment will continue, but backend pool will not be accessible until App Service is deployed" "WARNING"
    }
    else {
        Write-Log "App Service '$AppServiceName' found" "SUCCESS"
        Write-Log "Default hostname: $($appService.DefaultHostName)" "INFO"
    }
}

################################################################################
# SSL Certificate Functions
################################################################################

function Get-SslCertificateData {
    param(
        [string]$CertificatePath,
        [securestring]$Password
    )
    
    if ([string]::IsNullOrEmpty($CertificatePath)) {
        Write-Log "No SSL certificate provided, HTTPS listener will be configured without certificate" "WARNING"
        return $null
    }
    
    Write-Log "Processing SSL certificate..."
    
    if (-not (Test-Path $CertificatePath)) {
        Write-Log "SSL certificate file not found: $CertificatePath" "ERROR"
        throw "Certificate file does not exist"
    }
    
    # Read certificate file and convert to base64
    $certBytes = [System.IO.File]::ReadAllBytes($CertificatePath)
    $certBase64 = [System.Convert]::ToBase64String($certBytes)
    
    Write-Log "SSL certificate loaded successfully" "SUCCESS"
    Write-Log "Certificate size: $($certBytes.Length) bytes" "INFO"
    
    return $certBase64
}

################################################################################
# Deployment Functions
################################################################################

function Deploy-ApplicationGateway {
    Write-SectionHeader "DEPLOYING APPLICATION GATEWAY WITH WAF"
    
    # Load parameters from file
    $params = Get-Content $ParameterFile | ConvertFrom-Json
    $vnetName = $params.parameters.virtualNetworkName.value
    $subnetName = $params.parameters.subnetName.value
    $backendFqdn = $params.parameters.backendAppServiceFqdn.value
    
    # Extract App Service name - handle both azurewebsites.net and custom domains
    # For azurewebsites.net: extract the name before .azurewebsites.net
    # For custom domains: try to find matching App Service in resource group
    if ($backendFqdn -match '^([^.]+)\.azurewebsites\.net$') {
        $appServiceName = $matches[1]
    }
    else {
        # For custom domains, we'll skip the App Service validation
        # since we can't reliably determine the App Service name
        $appServiceName = $null
        Write-Log "Backend uses custom domain: $backendFqdn" "INFO"
        Write-Log "Skipping App Service validation (only applicable for *.azurewebsites.net)" "INFO"
    }
    
    # Validate dependencies
    Test-VirtualNetwork -ResourceGroupName $ResourceGroupName -VNetName $vnetName -SubnetName $subnetName
    
    # Only validate App Service if we could determine the name
    if ($appServiceName) {
        Test-AppService -ResourceGroupName $ResourceGroupName -AppServiceName $appServiceName
    }
    
    # Prepare deployment parameters
    $deploymentParams = @{
        ResourceGroupName     = $ResourceGroupName
        TemplateFile          = $TemplateFile
        TemplateParameterFile = $ParameterFile
        Name                  = "appgw-deployment-$Timestamp"
    }
    
    # Add SSL certificate if provided
    if (-not [string]::IsNullOrEmpty($SslCertificatePath)) {
        $certData = Get-SslCertificateData -CertificatePath $SslCertificatePath -Password $SslCertificatePassword
        
        if ($certData) {
            $deploymentParams.Add('sslCertificateData', $certData)
            
            if ($SslCertificatePassword) {
                $deploymentParams.Add('sslCertificatePassword', $SslCertificatePassword)
            }
            
            Write-Log "SSL certificate will be included in deployment" "INFO"
        }
    }
    
    Write-Log "Starting Application Gateway deployment..."
    Write-Log "Environment: $EnvName" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Location: $Location" "INFO"
    
    if ($WhatIf) {
        Write-Log "Running in WhatIf mode - no changes will be made" "WARNING"
        $deploymentParams.Add('WhatIf', $true)
    }
    
    try {
        $deployment = New-AzResourceGroupDeployment @deploymentParams -Verbose
        
        Write-Log "Application Gateway deployment completed successfully" "SUCCESS"
        
        # Display outputs
        if ($deployment.Outputs) {
            Write-SectionHeader "DEPLOYMENT OUTPUTS"
            
            if ($deployment.Outputs.publicIpAddress) {
                Write-Log "Public IP Address: $($deployment.Outputs.publicIpAddress.Value)" "INFO"
            }
            
            if ($deployment.Outputs.publicIpFqdn) {
                Write-Log "Public FQDN: $($deployment.Outputs.publicIpFqdn.Value)" "INFO"
            }
            
            if ($deployment.Outputs.applicationGatewayId) {
                Write-Log "Application Gateway ID: $($deployment.Outputs.applicationGatewayId.Value)" "INFO"
            }
            
            if ($deployment.Outputs.wafPolicyId) {
                Write-Log "WAF Policy ID: $($deployment.Outputs.wafPolicyId.Value)" "INFO"
            }
        }
        
        return $deployment
    }
    catch {
        Write-Log "Application Gateway deployment failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Show-PostDeploymentInstructions {
    Write-SectionHeader "POST-DEPLOYMENT INSTRUCTIONS"
    
    Write-Log "Application Gateway has been deployed successfully!" "SUCCESS"
    Write-Log ""
    Write-Log "Next Steps:" "INFO"
    Write-Log "1. Configure custom domain DNS to point to the Application Gateway public IP/FQDN" "INFO"
    Write-Log "2. Upload SSL certificate if not done during deployment (see README.md)" "INFO"
    Write-Log "3. Test WAF protection using the Test-WAF.ps1 script" "INFO"
    Write-Log "4. Monitor Application Gateway metrics in Azure Portal" "INFO"
    Write-Log "5. Review WAF logs for detected threats" "INFO"
    Write-Log ""
    Write-Log "Documentation:" "INFO"
    Write-Log "- README.md - Complete deployment guide" "INFO"
    Write-Log "- WAF-CONFIGURATION-GUIDE.md - WAF rules and configuration" "INFO"
    Write-Log "- INTEGRATION-GUIDE.md - Backend integration guide" "INFO"
    Write-Log ""
}

################################################################################
# Main Script Execution
################################################################################

try {
    Write-SectionHeader "APPLICATION GATEWAY WITH WAF DEPLOYMENT"
    Write-Log "Starting deployment for $EnvName environment" "INFO"
    Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    
    # Run prerequisites check
    Test-Prerequisites
    
    # Deploy Application Gateway
    $deployment = Deploy-ApplicationGateway
    
    # Show post-deployment instructions
    Show-PostDeploymentInstructions
    
    Write-Log "Deployment completed successfully!" "SUCCESS"
    Write-Log "Log file: $LogFile" "INFO"
    
    exit 0
}
catch {
    Write-Log "Deployment failed with error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" "ERROR"
    Write-Log "Log file: $LogFile" "INFO"
    
    exit 1
}
