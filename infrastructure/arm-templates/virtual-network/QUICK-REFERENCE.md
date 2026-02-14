# Virtual Network Quick Reference Guide

Quick reference for common network operations and troubleshooting.

## Table of Contents

- [Deployment](#deployment)
- [Validation](#validation)
- [Common Operations](#common-operations)
- [Troubleshooting](#troubleshooting)
- [Useful Commands](#useful-commands)

## Deployment

### Deploy VNet (Recommended Method)

```powershell
# Deploy to development
.\Deploy-VirtualNetwork.ps1 -Environment dev

# Deploy to staging with custom location
.\Deploy-VirtualNetwork.ps1 -Environment staging -Location westus2

# Deploy to production with diagnostics
.\Deploy-VirtualNetwork.ps1 -Environment prod -ShowDiagnostics
```

### Validate Before Deployment

```powershell
# Validate template only (no deployment)
.\Deploy-VirtualNetwork.ps1 -Environment dev -ValidateOnly

# Preview changes (WhatIf mode)
.\Deploy-VirtualNetwork.ps1 -Environment dev -WhatIf
```

### Manual ARM Deployment

```powershell
New-AzResourceGroupDeployment `
    -Name "vnet-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "virtual-network.json" `
    -TemplateParameterFile "parameters.dev.json"
```

## Validation

### Verify VNet Deployment

```powershell
# Check VNet exists
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"
$vnet | Format-List Name, Location, AddressSpace

# List all subnets
$vnet.Subnets | Select-Object Name, AddressPrefix

# Verify NSG associations
$vnet.Subnets | Select-Object Name, @{Name="NSG";Expression={($_.NetworkSecurityGroup.Id -split '/')[-1]}}
```

### Check NSG Rules

```powershell
# Get all NSGs in resource group
$nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-dev-rg"

# List all rules
foreach ($nsg in $nsgs) {
    Write-Host "NSG: $($nsg.Name)" -ForegroundColor Cyan
    $nsg.SecurityRules | Format-Table Name, Priority, Direction, Access, Protocol, DestinationPortRange
}
```

### Verify Service Endpoints

```powershell
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "app-subnet" -VirtualNetwork $vnet

# Check service endpoints
$subnet.ServiceEndpoints | Select-Object Service, ProvisioningState
```

## Common Operations

### Add NSG Rule

```powershell
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet-app-nsg"

# Add new rule
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowCustomPort" `
    -Priority 120 `
    -Direction Inbound `
    -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange "8080" | Set-AzNetworkSecurityGroup
```

### Modify NSG Rule

```powershell
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet-app-nsg"

# Update existing rule
$nsg | Set-AzNetworkSecurityRuleConfig `
    -Name "AllowHTTPS" `
    -Priority 100 `
    -Direction Inbound `
    -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "10.0.4.0/24" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange "443" | Set-AzNetworkSecurityGroup
```

### Remove NSG Rule

```powershell
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet-app-nsg"
$nsg | Remove-AzNetworkSecurityRuleConfig -Name "AllowCustomPort" | Set-AzNetworkSecurityGroup
```

### Add Service Endpoint to Existing Subnet

```powershell
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "app-subnet" -VirtualNetwork $vnet

# Add service endpoint
$subnet.ServiceEndpoints.Add(@{service="Microsoft.EventHub"})
Set-AzVirtualNetwork -VirtualNetwork $vnet
```

### VNet Integration for App Service

```powershell
# Get subnet for integration
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "app-subnet" -VirtualNetwork $vnet

# Integrate App Service with VNet
$webApp = Get-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"
Set-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app" -VnetSubnetId $subnet.Id

# Verify integration
$webApp = Get-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"
$webApp.SiteConfig.VnetName
```

### Configure SQL VNet Rule

```powershell
# Get app subnet ID
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "app-subnet" -VirtualNetwork $vnet

# Add VNet rule to SQL Server
New-AzSqlServerVirtualNetworkRule `
    -ResourceGroupName "kbudget-dev-rg" `
    -ServerName "kbudget-dev-sql" `
    -VirtualNetworkRuleName "AllowAppSubnet" `
    -VirtualNetworkSubnetId $subnet.Id

# List all VNet rules
Get-AzSqlServerVirtualNetworkRule -ResourceGroupName "kbudget-dev-rg" -ServerName "kbudget-dev-sql"
```

### Configure Storage VNet Rule

```powershell
# Get app subnet ID
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "app-subnet" -VirtualNetwork $vnet

# Add VNet rule to storage account
Add-AzStorageAccountNetworkRule `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudgetdevstorage" `
    -VirtualNetworkResourceId $subnet.Id

# Restrict to VNet only (deny public access)
Update-AzStorageAccountNetworkRuleSet `
    -ResourceGroupName "kbudget-dev-rg" `
    -Name "kbudgetdevstorage" `
    -DefaultAction Deny

# View network rules
Get-AzStorageAccountNetworkRuleSet -ResourceGroupName "kbudget-dev-rg" -Name "kbudgetdevstorage"
```

## Troubleshooting

### Test Network Connectivity

#### From App Service to SQL Database

```powershell
# Use Kudu console: https://<app-name>.scm.azurewebsites.net
# Navigate to Debug Console > PowerShell
# Run:
Test-NetConnection -ComputerName <sql-server>.database.windows.net -Port 1433

# Alternative using tcpping (built into Kudu)
tcpping <sql-server>.database.windows.net 1433
```

#### DNS Resolution

```powershell
# From Kudu console
nslookup <sql-server>.database.windows.net

# Alternative
Resolve-DnsName <sql-server>.database.windows.net
```

### View Effective NSG Rules

```powershell
# For App Service VNet integration (requires network interface)
$nic = Get-AzNetworkInterface -ResourceGroupName "kbudget-dev-rg"
Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName $nic.Name -ResourceGroupName "kbudget-dev-rg"
```

### Check Subnet IP Usage

```powershell
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"

foreach ($subnet in $vnet.Subnets) {
    $ipConfigs = $subnet.IpConfigurations.Count
    $total = [Math]::Pow(2, (32 - [int]($subnet.AddressPrefix -split '/')[-1])) - 5  # Azure reserves 5 IPs
    $available = $total - $ipConfigs
    
    Write-Host "Subnet: $($subnet.Name)" -ForegroundColor Cyan
    Write-Host "  CIDR: $($subnet.AddressPrefix)"
    Write-Host "  Used IPs: $ipConfigs"
    Write-Host "  Available IPs: $available"
    Write-Host "  Utilization: $([Math]::Round(($ipConfigs/$total)*100, 2))%"
    Write-Host ""
}
```

### Enable NSG Flow Logs

```powershell
# Requires Network Watcher and Storage Account

# Get NSG
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet-app-nsg"

# Get Network Watcher
$nw = Get-AzNetworkWatcher -ResourceGroupName "NetworkWatcherRG" -Name "NetworkWatcher_eastus"

# Get storage account for logs
$storage = Get-AzStorageAccount -ResourceGroupName "kbudget-dev-rg" -Name "kbudgetdevstorage"

# Enable flow logs
Set-AzNetworkWatcherConfigFlowLog `
    -NetworkWatcher $nw `
    -TargetResourceId $nsg.Id `
    -StorageAccountId $storage.Id `
    -EnableFlowLog $true `
    -FormatType Json `
    -FormatVersion 2 `
    -EnableRetention $true `
    -RetentionInDays 90
```

### Test IP Flow (Network Watcher)

```powershell
# Verify if traffic is allowed/denied by NSG rules
Test-AzNetworkWatcherIPFlow `
    -NetworkWatcher $nw `
    -TargetVirtualMachineId $vm.Id `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 1433 `
    -RemotePort 12345 `
    -LocalIPAddress 10.0.2.4 `
    -RemoteIPAddress 10.0.1.4
```

### View Network Topology

```powershell
# Requires Network Watcher

$nw = Get-AzNetworkWatcher -ResourceGroupName "NetworkWatcherRG" -Name "NetworkWatcher_eastus"

Get-AzNetworkWatcherTopology `
    -NetworkWatcher $nw `
    -TargetResourceGroupName "kbudget-dev-rg"
```

## Useful Commands

### Quick Status Check

```powershell
# One-liner to check VNet status
Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" | 
    Select-Object Name, Location, 
    @{N='AddressSpace';E={$_.AddressSpace.AddressPrefixes -join ','}}, 
    @{N='Subnets';E={$_.Subnets.Count}}, 
    @{N='DDoS';E={$_.EnableDdosProtection}}
```

### Export VNet Configuration

```powershell
# Export to JSON
$vnet = Get-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet"
$vnet | ConvertTo-Json -Depth 10 | Out-File "vnet-config-$(Get-Date -Format 'yyyyMMdd').json"
```

### Bulk NSG Rule Export

```powershell
# Export all NSG rules to CSV
$nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName "kbudget-dev-rg"
$rules = @()

foreach ($nsg in $nsgs) {
    foreach ($rule in $nsg.SecurityRules) {
        $rules += [PSCustomObject]@{
            NSG = $nsg.Name
            Rule = $rule.Name
            Priority = $rule.Priority
            Direction = $rule.Direction
            Access = $rule.Access
            Protocol = $rule.Protocol
            Source = $rule.SourceAddressPrefix
            SourcePort = $rule.SourcePortRange
            Destination = $rule.DestinationAddressPrefix
            DestPort = $rule.DestinationPortRange
        }
    }
}

$rules | Export-Csv "nsg-rules-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
```

### Monitor Outbound IPs

```powershell
# Check App Service outbound IPs
$webApp = Get-AzWebApp -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-app"
Write-Host "Outbound IPs: $($webApp.OutboundIpAddresses)"
Write-Host "Possible Outbound IPs: $($webApp.PossibleOutboundIpAddresses)"
```

### Clean Up Test Resources

```powershell
# Remove VNet (WARNING: This will delete all associated resources)
Remove-AzVirtualNetwork -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet" -Force

# Remove specific NSG
Remove-AzNetworkSecurityGroup -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev-vnet-app-nsg" -Force
```

## Environment Variables

Useful environment shortcuts:

```powershell
# Set common variables
$rgDev = "kbudget-dev-rg"
$rgStaging = "kbudget-staging-rg"
$rgProd = "kbudget-prod-rg"

$vnetDev = "kbudget-dev-vnet"
$vnetStaging = "kbudget-staging-vnet"
$vnetProd = "kbudget-prod-vnet"

# Quick switch between environments
function Set-DevEnvironment {
    $global:CurrentRG = $rgDev
    $global:CurrentVNet = $vnetDev
    Write-Host "Switched to Development environment" -ForegroundColor Green
}

function Set-StagingEnvironment {
    $global:CurrentRG = $rgStaging
    $global:CurrentVNet = $vnetStaging
    Write-Host "Switched to Staging environment" -ForegroundColor Yellow
}

function Set-ProdEnvironment {
    $global:CurrentRG = $rgProd
    $global:CurrentVNet = $vnetProd
    Write-Host "Switched to Production environment" -ForegroundColor Red
}

# Use: Set-DevEnvironment
# Then: Get-AzVirtualNetwork -ResourceGroupName $CurrentRG -Name $CurrentVNet
```

## Logging

Deployment logs are stored in:
```
infrastructure/arm-templates/virtual-network/logs/
vnet-deployment_{env}_{timestamp}.log
```

View recent log:
```powershell
Get-Content ".\logs\vnet-deployment_dev_*.log" -Tail 50
```

## Additional Resources

- [Azure VNet Documentation](https://docs.microsoft.com/azure/virtual-network/)
- [NSG Best Practices](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Service Endpoints](https://docs.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview)
- [Network Architecture Guide](../../../docs/NETWORK-ARCHITECTURE.md)
- [Full README](./README.md)
