# Azure Resource Group Best Practices

## Overview

This document provides best practices for managing Azure Resource Groups in the KBudget GPT project. Following these guidelines ensures consistent resource organization, proper tagging, and effective lifecycle management.

**For standardized naming conventions, please refer to our [Azure Resource Group Naming Conventions](azure-resource-group-naming-conventions.md) document.**

## Resource Group Purpose

### What is a Resource Group?

A Resource Group is a logical container for Azure resources that share the same lifecycle, permissions, and policies. Resources in a group are typically:
- Deployed together
- Updated together
- Deleted together

### Resource Group Organization

#### By Environment
Organize resources by environment to enable clear separation and management:
- `kbudget-dev-rg` - Development environment resources
- `kbudget-staging-rg` - Staging/UAT environment resources
- `kbudget-prod-rg` - Production environment resources

#### By Application Component
For larger deployments, consider organizing by application tier or component:
- `kbudget-frontend-rg` - Frontend application resources
- `kbudget-backend-rg` - Backend API resources
- `kbudget-data-rg` - Database and storage resources
- `kbudget-shared-rg` - Shared services (networking, monitoring)

#### Best Practices for Organization
- **Single Lifecycle**: Group resources that share the same lifecycle
- **Same Region**: Keep resources in the same region within a resource group when possible
- **Access Control**: Align resource groups with RBAC (Role-Based Access Control) requirements
- **Billing**: Use resource groups to track costs by project, department, or environment
- **Resource Limits**: Be aware of Azure subscription limits (800 resource groups per subscription)

## Recommended Tagging Strategy

Tags are name-value pairs that enable you to categorize and view resources across resource groups and subscriptions.

### Required Tags

All resource groups should include the following tags:

| Tag Name | Description | Example |
|----------|-------------|---------|
| `Environment` | Deployment environment | `Development`, `Staging`, `Production` |
| `Project` | Project identifier | `KBudget-GPT` |
| `Owner` | Team or person responsible | `DevOps-Team`, `john.doe@company.com` |
| `CostCenter` | Cost center for billing | `CC-12345` |
| `CreatedDate` | Resource group creation date | `2026-02-07` |

### Optional Tags

Consider adding these tags based on project needs:

| Tag Name | Description | Example |
|----------|-------------|---------|
| `Application` | Application name | `KBudget` |
| `BusinessUnit` | Business unit responsible | `Finance` |
| `Criticality` | Business criticality level | `High`, `Medium`, `Low` |
| `DataClassification` | Data sensitivity level | `Public`, `Internal`, `Confidential`, `Restricted` |
| `DisasterRecovery` | DR tier/requirement | `Mission-Critical`, `Important`, `Standard` |
| `MaintenanceWindow` | Allowed maintenance window | `Weekends`, `Tue-Thu-2AM-4AM` |
| `Compliance` | Compliance requirements | `HIPAA`, `PCI-DSS`, `GDPR` |

### Tagging Best Practices

1. **Consistency**: Use consistent tag names and values across all resources
2. **Automation**: Apply tags via Infrastructure as Code (IaC) tools like Terraform or Bicep
3. **Inheritance**: Configure Azure Policy to inherit tags from resource groups to resources
4. **Governance**: Enforce required tags using Azure Policy
5. **Case Sensitivity**: Remember that tag names are case-insensitive but values are case-sensitive
6. **Character Limits**: Tag names (512 chars for resources, 128 for storage), values (256 chars)
7. **Documentation**: Document your tagging strategy in this file

### Example Tagging Implementation

```bash
# Azure CLI example
az group create \
  --name kbudget-prod-rg \
  --location eastus \
  --tags \
    Environment=Production \
    Project=KBudget-GPT \
    Owner=DevOps-Team \
    CostCenter=CC-12345 \
    CreatedDate=2026-02-07 \
    Application=KBudget \
    Criticality=High
```

```hcl
# Terraform example
resource "azurerm_resource_group" "kbudget_prod" {
  name     = "kbudget-prod-rg"
  location = "East US"
  
  tags = {
    Environment        = "Production"
    Project           = "KBudget-GPT"
    Owner             = "DevOps-Team"
    CostCenter        = "CC-12345"
    CreatedDate       = "2026-02-07"
    Application       = "KBudget"
    Criticality       = "High"
  }
}
```

## Lifecycle Management

### Creation

#### Planning Phase
Before creating a resource group, consider:
1. **Naming Convention**: Follow the standard naming pattern defined in [Azure Resource Group Naming Conventions](azure-resource-group-naming-conventions.md) (e.g., `<app>-<env>-rg`)
2. **Location**: Choose the Azure region closest to your users or data
3. **Subscription**: Determine the appropriate subscription based on billing and governance
4. **Tags**: Prepare all required tags before creation
5. **Access Control**: Plan RBAC assignments

#### Creation Methods

**Azure CLI:**
```bash
az group create \
  --name kbudget-dev-rg \
  --location eastus \
  --tags Environment=Development Project=KBudget-GPT Owner=DevOps-Team
```

**PowerShell:**
```powershell
New-AzResourceGroup `
  -Name kbudget-dev-rg `
  -Location eastus `
  -Tag @{Environment="Development"; Project="KBudget-GPT"; Owner="DevOps-Team"}
```

**Infrastructure as Code (Recommended):**
- Use Terraform, Bicep, or ARM templates for repeatability and version control
- Store IaC files in source control
- Use CI/CD pipelines for deployment

#### Post-Creation Tasks
1. Apply RBAC permissions
2. Configure locks (CanNotDelete or ReadOnly) for production environments
3. Set up Azure Policy assignments
4. Configure diagnostic settings
5. Document in your inventory

### Modification

#### Updating Tags
```bash
# Add or update a tag
az group update \
  --name kbudget-prod-rg \
  --set tags.LastModified=2026-02-07

# Remove a tag
az group update \
  --name kbudget-prod-rg \
  --remove tags.OldTag
```

#### Moving Resources
When moving resources between resource groups:
1. Verify that the resource type supports moving
2. Check for dependencies and linked resources
3. Plan for downtime if required
4. Update tags and documentation
5. Test thoroughly in non-production first

```bash
# Move resources to another resource group
az resource move \
  --destination-group kbudget-new-rg \
  --ids <resource-id-1> <resource-id-2>
```

#### Modifying Locks
```bash
# Add a lock to prevent deletion
az lock create \
  --name prevent-delete-lock \
  --resource-group kbudget-prod-rg \
  --lock-type CanNotDelete \
  --notes "Prevent accidental deletion of production resources"

# Remove a lock
az lock delete \
  --name prevent-delete-lock \
  --resource-group kbudget-prod-rg
```

### Deletion

#### Pre-Deletion Checklist
Before deleting a resource group, ensure:
- [ ] Backup all critical data
- [ ] Export any configurations needed for future reference
- [ ] Verify no production workloads depend on the resources
- [ ] Get approval from stakeholders
- [ ] Remove any locks
- [ ] Check for dependencies in other resource groups
- [ ] Update documentation and inventory

#### Deletion Methods

**Azure CLI:**
```bash
# Delete without confirmation prompt
az group delete \
  --name kbudget-dev-rg \
  --yes \
  --no-wait

# Delete and wait for completion
az group delete \
  --name kbudget-dev-rg \
  --yes
```

**PowerShell:**
```powershell
Remove-AzResourceGroup `
  -Name kbudget-dev-rg `
  -Force
```

#### Important Considerations
1. **Irreversible**: Resource group deletion cannot be undone
2. **All Resources**: Deleting a resource group deletes ALL resources within it
3. **Soft Delete**: Some resources (Key Vault, etc.) may have soft-delete enabled
4. **Locks**: Remove locks before deletion
5. **Time**: Large resource groups may take significant time to delete
6. **Audit**: Deletion is logged in Activity Logs for audit purposes

### Cleanup and Maintenance

#### Regular Maintenance Tasks
1. **Monthly Review**: Review resource groups for unused or orphaned resources
2. **Cost Analysis**: Analyze costs by resource group and optimize
3. **Tag Audit**: Ensure all resource groups have required tags
4. **Access Review**: Review and update RBAC assignments
5. **Policy Compliance**: Check Azure Policy compliance status
6. **Lock Verification**: Verify locks are in place for critical environments

#### Automation Recommendations
- Set up Azure Automation runbooks for regular cleanup
- Use Azure Resource Graph queries to find untagged resources
- Implement cost alerts for resource groups exceeding budgets
- Create dashboards for monitoring resource group health

## Additional Resources

### Azure Documentation
- [Azure Resource Manager Overview](https://docs.microsoft.com/azure/azure-resource-manager/management/overview)
- [Resource Group Best Practices](https://docs.microsoft.com/azure/azure-resource-manager/management/resource-group-overview)
- [Azure Naming Conventions](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Azure Tagging Strategy](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)

### Tools
- [Azure Resource Manager Tools VS Code Extension](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools)
- [Azure CLI](https://docs.microsoft.com/cli/azure/)
- [Azure PowerShell](https://docs.microsoft.com/powershell/azure/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-02-07 | Initial documentation | DevOps Team |
