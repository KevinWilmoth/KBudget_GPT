################################################################################
# Deploy Azure Virtual Network Script
# 
# Purpose: Deploy and configure Azure Virtual Network with subnets for KBudget GPT application
# Features:
#   - Deploy VNet with segmented subnets (frontend, app, database, functions)
#   - Configure Network Security Groups (NSGs) with proper traffic rules
#   - Enable service endpoints for secure Azure service access
#   - Support for multiple environments (dev, staging, production)
#   - Comprehensive validation and testing
#   - Detailed logging and reporting
#
# Prerequisites:
#   - Azure PowerShell module (Az.Network, Az.Resources)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Proper permissions (Contributor or Owner)
#
# Usage:
#   .\Deploy-VirtualNetwork.ps1 -Environment dev
#   .\Deploy-VirtualNetwork.ps1 -Environment staging -Location westus2
#   .\Deploy-VirtualNetwork.ps1 -Environment prod -ValidateOnly
#   .\Deploy-VirtualNetwork.ps1 -Environment dev -WhatIf
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
    [switch]$ValidateOnly,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation,

    [Parameter(Mandatory = $false)]
    [switch]$ShowDiagnostics
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "vnet-deployment_$($Environment)_$Timestamp.log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Environment configuration
$ResourceGroupName = "kbudget-$Environment-rg"
$TemplateFile = Join-Path $ScriptDir "virtual-network.json"
$ParameterFile = Join-Path $ScriptDir "parameters.$Environment.json"
$DeploymentName = "vnet-deployment-$Timestamp"

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
    Write-Log "Checking prerequisites..." "INFO"
    
    # Check for Az.Network module
    if (-not (Get-Module -ListAvailable -Name Az.Network)) {
        Write-Log "Azure Network PowerShell module is not installed" "ERROR"
        Write-Log "Install with: Install-Module -Name Az.Network -Force" "ERROR"
        throw "Missing prerequisite: Az.Network module"
    }
    
    # Check for Az.Resources module
    if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Log "Azure Resources PowerShell module is not installed" "ERROR"
        Write-Log "Install with: Install-Module -Name Az.Resources -Force" "ERROR"
        throw "Missing prerequisite: Az.Resources module"
    }
    
    # Import modules
    Import-Module Az.Network -ErrorAction Stop
    Import-Module Az.Resources -ErrorAction Stop
    
    # Check Azure context
    $context = Get-AzContext
    if (-not $context) {
        Write-Log "Not authenticated to Azure" "ERROR"
        Write-Log "Run: Connect-AzAccount" "ERROR"
        throw "Not authenticated to Azure"
    }
    
    Write-Log "Authenticated as: $($context.Account.Id)" "INFO"
    Write-Log "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" "INFO"
    
    # Check if template file exists
    if (-not (Test-Path $TemplateFile)) {
        Write-Log "Template file not found: $TemplateFile" "ERROR"
        throw "Template file not found"
    }
    
    # Check if parameter file exists
    if (-not (Test-Path $ParameterFile)) {
        Write-Log "Parameter file not found: $ParameterFile" "ERROR"
        throw "Parameter file not found"
    }
    
    Write-Log "Prerequisites validated successfully" "SUCCESS"
}

function Test-Template {
    Write-Log "Validating ARM template..." "INFO"
    
    try {
        $validation = Test-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParameterFile `
            -ErrorAction Stop
        
        if ($validation) {
            Write-Log "Template validation failed:" "ERROR"
            foreach ($error in $validation) {
                Write-Log "  - $($error.Message)" "ERROR"
            }
            throw "Template validation failed"
        }
        
        Write-Log "ARM template validated successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Template validation error: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Test-ResourceGroup {
    Write-Log "Checking resource group: $ResourceGroupName" "INFO"
    
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    
    if (-not $rg) {
        Write-Log "Resource group does not exist: $ResourceGroupName" "WARNING"
        Write-Log "Creating resource group..." "INFO"
        
        if (-not $WhatIf) {
            New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
            Write-Log "Resource group created: $ResourceGroupName" "SUCCESS"
        }
        else {
            Write-Log "WHATIF: Would create resource group: $ResourceGroupName" "INFO"
        }
    }
    else {
        Write-Log "Resource group exists: $ResourceGroupName (Location: $($rg.Location))" "SUCCESS"
    }
}

################################################################################
# Deployment Functions
################################################################################

function Start-VNetDeployment {
    Write-Log "Starting Virtual Network deployment..." "INFO"
    Write-Log "Environment: $Environment" "INFO"
    Write-Log "Location: $Location" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Deployment Name: $DeploymentName" "INFO"
    
    try {
        if ($WhatIf) {
            Write-Log "WHATIF: Would deploy Virtual Network" "INFO"
            
            # Show what would be deployed
            $parameters = Get-Content $ParameterFile | ConvertFrom-Json
            Write-Log "VNet Name: $($parameters.parameters.vnetName.value)" "INFO"
            Write-Log "Address Space: $($parameters.parameters.vnetAddressPrefix.value)" "INFO"
            Write-Log "Subnets:" "INFO"
            Write-Log "  - Frontend: $($parameters.parameters.frontendSubnetPrefix.value)" "INFO"
            Write-Log "  - Application: $($parameters.parameters.appSubnetPrefix.value)" "INFO"
            Write-Log "  - Database: $($parameters.parameters.dbSubnetPrefix.value)" "INFO"
            Write-Log "  - Functions: $($parameters.parameters.funcSubnetPrefix.value)" "INFO"
            
            return
        }
        
        $deployment = New-AzResourceGroupDeployment `
            -Name $DeploymentName `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParameterFile `
            -Mode Incremental `
            -Force `
            -Verbose `
            -ErrorAction Stop
        
        Write-Log "Deployment completed successfully" "SUCCESS"
        Write-Log "Deployment State: $($deployment.ProvisioningState)" "SUCCESS"
        
        return $deployment
    }
    catch {
        Write-Log "Deployment failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Show-DeploymentOutputs {
    param(
        [Parameter(Mandatory = $true)]
        $Deployment
    )
    
    Write-Log "Deployment Outputs:" "INFO"
    Write-Log "===================" "INFO"
    
    if ($Deployment.Outputs) {
        foreach ($output in $Deployment.Outputs.GetEnumerator()) {
            Write-Log "$($output.Key): $($output.Value.Value)" "INFO"
        }
    }
    else {
        Write-Log "No outputs available" "WARNING"
    }
}

################################################################################
# Diagnostic Functions
################################################################################

function Show-NetworkDiagnostics {
    Write-Log "Retrieving network diagnostics..." "INFO"
    
    try {
        # Get VNet details
        $parameters = Get-Content $ParameterFile | ConvertFrom-Json
        $vnetName = $parameters.parameters.vnetName.value
        
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $vnetName -ErrorAction SilentlyContinue
        
        if (-not $vnet) {
            Write-Log "Virtual Network not found: $vnetName" "WARNING"
            return
        }
        
        Write-Log "Virtual Network Details:" "INFO"
        Write-Log "========================" "INFO"
        Write-Log "Name: $($vnet.Name)" "INFO"
        Write-Log "Location: $($vnet.Location)" "INFO"
        Write-Log "Address Space: $($vnet.AddressSpace.AddressPrefixes -join ', ')" "INFO"
        Write-Log "DDoS Protection: $($vnet.EnableDdosProtection)" "INFO"
        
        Write-Log "" "INFO"
        Write-Log "Subnets:" "INFO"
        Write-Log "========" "INFO"
        
        foreach ($subnet in $vnet.Subnets) {
            Write-Log "  Subnet: $($subnet.Name)" "INFO"
            Write-Log "    Address Prefix: $($subnet.AddressPrefix)" "INFO"
            
            if ($subnet.NetworkSecurityGroup) {
                $nsgName = ($subnet.NetworkSecurityGroup.Id -split '/')[-1]
                Write-Log "    NSG: $nsgName" "INFO"
            }
            
            if ($subnet.ServiceEndpoints) {
                Write-Log "    Service Endpoints: $($subnet.ServiceEndpoints.Service -join ', ')" "INFO"
            }
            
            if ($subnet.Delegations) {
                Write-Log "    Delegations: $($subnet.Delegations.ServiceName -join ', ')" "INFO"
            }
            
            Write-Log "" "INFO"
        }
        
        # Show NSG rules
        Write-Log "Network Security Groups:" "INFO"
        Write-Log "=======================" "INFO"
        
        $nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName
        foreach ($nsg in $nsgs) {
            Write-Log "  NSG: $($nsg.Name)" "INFO"
            
            foreach ($rule in $nsg.SecurityRules) {
                Write-Log "    Rule: $($rule.Name)" "INFO"
                Write-Log "      Priority: $($rule.Priority)" "INFO"
                Write-Log "      Direction: $($rule.Direction)" "INFO"
                Write-Log "      Access: $($rule.Access)" "INFO"
                Write-Log "      Protocol: $($rule.Protocol)" "INFO"
                Write-Log "      Source: $($rule.SourceAddressPrefix)" "INFO"
                Write-Log "      Destination Port: $($rule.DestinationPortRange)" "INFO"
            }
            
            Write-Log "" "INFO"
        }
    }
    catch {
        Write-Log "Error retrieving diagnostics: $($_.Exception.Message)" "ERROR"
    }
}

################################################################################
# Main Execution
################################################################################

function Main {
    Write-Log "========================================" "INFO"
    Write-Log "Virtual Network Deployment Script" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "" "INFO"
    
    try {
        # Step 1: Prerequisites
        Test-Prerequisites
        Write-Log "" "INFO"
        
        # Step 2: Resource Group
        Test-ResourceGroup
        Write-Log "" "INFO"
        
        # Step 3: Template Validation
        if (-not $SkipValidation) {
            Test-Template
            Write-Log "" "INFO"
        }
        
        # If validate only, stop here
        if ($ValidateOnly) {
            Write-Log "Validation complete. Exiting (ValidateOnly mode)" "SUCCESS"
            return
        }
        
        # Step 4: Deploy
        $deployment = Start-VNetDeployment
        Write-Log "" "INFO"
        
        # Step 5: Show outputs
        if ($deployment) {
            Show-DeploymentOutputs -Deployment $deployment
            Write-Log "" "INFO"
        }
        
        # Step 6: Diagnostics
        if ($ShowDiagnostics -and -not $WhatIf) {
            Show-NetworkDiagnostics
            Write-Log "" "INFO"
        }
        
        Write-Log "========================================" "INFO"
        Write-Log "Deployment completed successfully!" "SUCCESS"
        Write-Log "========================================" "INFO"
        Write-Log "Log file: $LogFile" "INFO"
    }
    catch {
        Write-Log "" "INFO"
        Write-Log "========================================" "ERROR"
        Write-Log "Deployment failed!" "ERROR"
        Write-Log "Error: $($_.Exception.Message)" "ERROR"
        Write-Log "========================================" "ERROR"
        Write-Log "Log file: $LogFile" "ERROR"
        throw
    }
    finally {
        Write-Log "Finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    }
}

# Execute main function
Main
