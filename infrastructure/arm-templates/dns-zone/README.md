# Azure DNS Zone

This directory contains ARM templates for managing Azure DNS zones and records for the KBudget application.

## Overview

Azure DNS provides:
- **Domain hosting** - Host your DNS zone in Azure
- **High availability** - Anycast network for fast, reliable DNS resolution
- **Integration** - Seamlessly integrate with other Azure services
- **Security** - RBAC and activity logs for DNS management
- **API support** - Manage DNS programmatically

## Resources Created

- **DNS Zone** - Azure-hosted DNS zone for your domain
- **A/CNAME Records** - DNS records pointing to Application Gateway (optional)

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| dnsZoneName | string | - | DNS zone name (e.g., example.com) |
| location | string | global | Location (always global for DNS) |
| applicationGatewayPublicIp | string | "" | App Gateway public IP (for A record) |
| applicationGatewayFqdn | string | "" | App Gateway FQDN (for CNAME record) |
| createAppGatewayRecord | bool | true | Create DNS record for App Gateway |
| appGatewayRecordName | string | www | DNS record name |
| recordType | string | A | Record type (A or CNAME) |
| tags | object | {} | Resource tags |

## Prerequisites

1. **Domain name** - You must own the domain you want to host
2. **Resource group** - DNS zone will be created in a resource group
3. **Application Gateway** (optional) - For automatic DNS record creation

## Deployment

### Step 1: Create DNS Zone

```powershell
# Deploy DNS zone for development
New-AzResourceGroupDeployment `
    -Name "dns-deployment" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TemplateFile "dns-zone.json" `
    -TemplateParameterFile "parameters.dev.json"
```

### Step 2: Update Domain Registrar

After deployment, update your domain registrar to use Azure DNS name servers:

```powershell
# Get name servers
$dnsZone = Get-AzDnsZone -ResourceGroupName "kbudget-dev-rg" -Name "kbudget-dev.example.com"
$dnsZone.NameServers

# Example output:
# ns1-01.azure-dns.com
# ns2-01.azure-dns.net
# ns3-01.azure-dns.org
# ns4-01.azure-dns.info
```

Go to your domain registrar (e.g., GoDaddy, Namecheap) and update the name servers to use the Azure DNS name servers.

### Step 3: Create DNS Records

#### Option A: Using Template Parameters

Update the parameter file with Application Gateway details:

```json
{
  "applicationGatewayPublicIp": {
    "value": "20.30.40.50"
  },
  "createAppGatewayRecord": {
    "value": true
  },
  "appGatewayRecordName": {
    "value": "www"
  },
  "recordType": {
    "value": "A"
  }
}
```

#### Option B: Using PowerShell

```powershell
# Create A record
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "www" `
    -RecordType A `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -IPv4Address "20.30.40.50")

# Create CNAME record
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "www" `
    -RecordType CNAME `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -Cname "kbudget-prod-appgw.eastus.cloudapp.azure.com")
```

## Common DNS Records

### Apex/Root Domain (@)

```powershell
# Point root domain to Application Gateway
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "@" `
    -RecordType A `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -IPv4Address "20.30.40.50")
```

### Subdomain (www, api, etc.)

```powershell
# www subdomain
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "www" `
    -RecordType CNAME `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -Cname "kbudget-prod-appgw.eastus.cloudapp.azure.com")

# api subdomain
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "api" `
    -RecordType CNAME `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -Cname "kbudget-prod-api.azurewebsites.net")
```

### TXT Records (for verification)

```powershell
# Create TXT record for domain verification
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "@" `
    -RecordType TXT `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -Value "v=spf1 include:_spf.google.com ~all")
```

## Environment Configuration

### Development
- **Domain**: kbudget-dev.example.com
- **Purpose**: Development testing with separate subdomain

### Staging
- **Domain**: kbudget-staging.example.com
- **Purpose**: Pre-production testing

### Production
- **Domain**: kbudget.example.com (or your actual domain)
- **Purpose**: Production workloads

## Integration with Application Gateway

After deploying both DNS Zone and Application Gateway:

1. **Get Application Gateway Public IP**:
```powershell
$pip = Get-AzPublicIpAddress -ResourceGroupName "kbudget-prod-rg" -Name "kbudget-prod-appgw-pip"
$pip.IpAddress
$pip.DnsSettings.Fqdn
```

2. **Create DNS Record**:
```powershell
# Using A record (recommended for apex domain)
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "@" `
    -RecordType A `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -IPv4Address $pip.IpAddress)

# Using CNAME (for subdomains)
New-AzDnsRecordSet `
    -ResourceGroupName "kbudget-prod-rg" `
    -ZoneName "kbudget.example.com" `
    -Name "www" `
    -RecordType CNAME `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -Cname $pip.DnsSettings.Fqdn)
```

## Monitoring

### View DNS Zone Details

```powershell
# Get DNS zone
Get-AzDnsZone -ResourceGroupName "kbudget-prod-rg" -Name "kbudget.example.com"

# List all record sets
Get-AzDnsRecordSet -ResourceGroupName "kbudget-prod-rg" -ZoneName "kbudget.example.com"
```

### Test DNS Resolution

```powershell
# Test DNS resolution
Resolve-DnsName kbudget.example.com -Server ns1-01.azure-dns.com

# Test from client
Resolve-DnsName www.kbudget.example.com
nslookup www.kbudget.example.com
```

### Query DNS Logs

Azure DNS queries can be logged to Log Analytics:

```powershell
# Enable diagnostic settings
$dnsZone = Get-AzDnsZone -ResourceGroupName "kbudget-prod-rg" -Name "kbudget.example.com"
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "kbudget-prod-rg"

Set-AzDiagnosticSetting `
    -ResourceId $dnsZone.Id `
    -Name "dns-diagnostics" `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category "QueryLog"
```

## Cost

### Azure DNS Pricing

**DNS Zones**:
- First 25 zones: $0.50 per zone per month
- Additional zones: $0.10 per zone per month

**DNS Queries**:
- First 1 billion queries/month: $0.40 per million queries
- Over 1 billion queries: $0.20 per million queries

**Example Monthly Cost**:
- 1 DNS zone: $0.50/month
- 10 million queries: $4.00/month
- **Total**: ~$4.50/month

## Security Best Practices

✅ **Use RBAC** - Limit who can modify DNS records  
✅ **Enable activity logs** - Monitor DNS changes  
✅ **Use CAA records** - Control certificate authority authorization  
✅ **Implement DNSSEC** - When available (currently in preview)  
✅ **Set appropriate TTLs** - Balance between caching and flexibility  
✅ **Use aliases** - For Azure resources when possible  
✅ **Monitor for unauthorized changes** - Set up alerts  
✅ **Document record purposes** - Use tags and naming conventions

## Troubleshooting

### DNS Not Resolving

1. **Check name servers**:
```powershell
$dnsZone = Get-AzDnsZone -ResourceGroupName "kbudget-prod-rg" -Name "kbudget.example.com"
$dnsZone.NameServers
```

2. **Verify domain registrar settings** - Ensure name servers match Azure DNS

3. **Test with Azure DNS servers directly**:
```powershell
nslookup www.kbudget.example.com ns1-01.azure-dns.com
```

### Record Not Working

1. **Check record exists**:
```powershell
Get-AzDnsRecordSet -ResourceGroupName "kbudget-prod-rg" -ZoneName "kbudget.example.com" -Name "www" -RecordType A
```

2. **Wait for DNS propagation** - Can take up to 48 hours globally (usually much faster)

3. **Clear DNS cache**:
```powershell
# Windows
ipconfig /flushdns

# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux (systemd-resolved)
sudo systemd-resolve --flush-caches

# Linux (nscd)
sudo /etc/init.d/nscd restart
```

### Zone Transfer Failed

Azure DNS doesn't support zone transfers (AXFR). Import records using:

```powershell
# Import zone file
Import-AzDnsZone -ResourceGroupName "kbudget-prod-rg" -Name "kbudget.example.com" -ZoneFile "zone.txt"
```

## Additional Resources

- [Azure DNS Documentation](https://docs.microsoft.com/azure/dns/)
- [DNS Zone Management](https://docs.microsoft.com/azure/dns/dns-operations-dnszones)
- [DNS Records Management](https://docs.microsoft.com/azure/dns/dns-operations-recordsets)
- [Azure DNS Best Practices](https://docs.microsoft.com/azure/dns/dns-best-practices)
