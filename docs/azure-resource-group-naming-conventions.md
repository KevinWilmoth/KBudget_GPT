# Azure Resource Group Naming Conventions

## Document Information

| Property | Value |
|----------|-------|
| Document Version | 1.0 |
| Last Updated | 2026-02-07 |
| Status | Approved |
| Owner | DevOps Team |
| Stakeholders | Business Analysts, DevOps Engineers, Development Team |

## Purpose

This document defines the standard naming conventions for Azure Resource Groups in the KBudget GPT project. Consistent naming ensures that all environments are easily identifiable, manageable, and aligned with organizational governance policies.

## Naming Convention Standard

### Pattern

All Azure Resource Groups must follow this standardized naming pattern:

```
<application>-<environment>-<region>-<instance>-rg
```

### Pattern Components

| Component | Description | Required | Format | Examples |
|-----------|-------------|----------|--------|----------|
| `application` | Application or workload identifier | Yes | Lowercase, alphanumeric, hyphens allowed | `kbudget`, `kbudget-api`, `kbudget-web` |
| `environment` | Deployment environment | Yes | Lowercase, standardized values | `dev`, `staging`, `prod` |
| `region` | Azure region abbreviation | Optional | Lowercase, 2-4 chars | `eus` (East US), `wus` (West US), `neu` (North Europe) |
| `instance` | Instance number for multiple deployments | Optional | Numeric, 2 digits | `01`, `02`, `03` |
| `rg` | Resource Group suffix | Yes | Literal `rg` | `rg` |

### Simplified Pattern (Primary Use)

For most use cases, use the simplified pattern without region and instance:

```
<application>-<environment>-rg
```

## Environment Identifiers

The following standardized environment identifiers must be used:

| Environment | Identifier | Description | Use Case |
|-------------|------------|-------------|----------|
| Development | `dev` | Development and feature testing | Individual developer work, feature branches |
| Staging | `staging` | Pre-production testing and UAT | User acceptance testing, integration testing |
| Production | `prod` | Live production environment | End-user facing production workload |
| Quality Assurance | `qa` | QA and testing | Dedicated QA team testing |
| Demo | `demo` | Demonstration and training | Customer demos, training sessions |
| Sandbox | `sandbox` | Experimental and learning | POCs, learning, experiments |

## Application Component Identifiers

For larger deployments requiring component separation:

| Component | Identifier | Description |
|-----------|------------|-------------|
| Frontend | `kbudget-web` | Web application frontend |
| Backend API | `kbudget-api` | Backend API services |
| Database | `kbudget-data` | Database and storage resources |
| Shared Services | `kbudget-shared` | Networking, monitoring, shared utilities |
| Security | `kbudget-security` | Security-related resources (Key Vault, etc.) |

## Examples

### Standard Environment Resource Groups

| Resource Group Name | Purpose |
|---------------------|---------|
| `kbudget-dev-rg` | Development environment for KBudget application |
| `kbudget-staging-rg` | Staging/UAT environment for KBudget application |
| `kbudget-prod-rg` | Production environment for KBudget application |
| `kbudget-qa-rg` | QA testing environment |
| `kbudget-demo-rg` | Demo environment for stakeholder presentations |
| `kbudget-sandbox-rg` | Experimental/learning environment |

### Component-Based Resource Groups

| Resource Group Name | Purpose |
|---------------------|---------|
| `kbudget-web-prod-rg` | Production frontend application resources |
| `kbudget-api-prod-rg` | Production backend API resources |
| `kbudget-data-prod-rg` | Production database and storage |
| `kbudget-shared-prod-rg` | Production shared services |
| `kbudget-security-prod-rg` | Production security resources |

### Regional Deployments

For multi-region deployments:

| Resource Group Name | Purpose |
|---------------------|---------|
| `kbudget-prod-eus-rg` | Production resources in East US |
| `kbudget-prod-wus-rg` | Production resources in West US |
| `kbudget-prod-neu-rg` | Production resources in North Europe |

### Multiple Instances

For multiple instances of the same environment:

| Resource Group Name | Purpose |
|---------------------|---------|
| `kbudget-dev-01-rg` | Development environment instance 1 |
| `kbudget-dev-02-rg` | Development environment instance 2 |
| `kbudget-staging-01-rg` | Staging environment instance 1 |

## Validation Rules

### Character Constraints

- **Allowed Characters**: Lowercase letters (a-z), numbers (0-9), hyphens (-)
- **Maximum Length**: 90 characters (Azure limit)
- **Minimum Length**: 1 character
- **Case**: Use lowercase only for consistency
- **Start/End**: Must start with a letter or number; must end with a letter or number
- **Hyphens**: Cannot have consecutive hyphens

### Naming Rules

1. **Use Lowercase**: All resource group names must use lowercase letters
2. **No Spaces**: Spaces are not allowed; use hyphens instead
3. **No Special Characters**: Only alphanumeric and hyphens allowed
4. **Descriptive**: Names should be self-documenting and meaningful
5. **Consistent**: Follow the standard pattern consistently across all resources
6. **Unique**: Resource group names must be unique within the subscription

### Validation Examples

✅ **Valid Names:**
- `kbudget-dev-rg`
- `kbudget-prod-eus-rg`
- `kbudget-api-staging-rg`
- `kbudget-shared-prod-01-rg`

❌ **Invalid Names:**
- `KBudget-Dev-RG` (uppercase not allowed)
- `kbudget_dev_rg` (underscores not allowed)
- `kbudget-dev` (missing `-rg` suffix)
- `kbudget--dev-rg` (consecutive hyphens)
- `-kbudget-dev-rg` (starts with hyphen)
- `kbudget-dev-rg-` (ends with hyphen)

## Implementation Guidelines

### Creating New Resource Groups

1. **Verify Naming**: Ensure the proposed name follows the convention
2. **Check Uniqueness**: Confirm the name is not already in use
3. **Apply Tags**: Include all required tags (see tagging section)
4. **Document**: Update resource inventory documentation
5. **Review**: Have naming reviewed by team lead or DevOps team

### Infrastructure as Code (IaC)

When using IaC tools, enforce naming conventions programmatically:

#### Terraform Example

```hcl
variable "application" {
  description = "Application name"
  type        = string
  default     = "kbudget"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod", "qa", "demo", "sandbox"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, qa, demo, sandbox"
  }
}

locals {
  resource_group_name = "${var.application}-${var.environment}-rg"
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  
  tags = {
    Environment = var.environment
    Application = var.application
    Project     = "KBudget-GPT"
  }
}
```

#### Azure CLI Validation

```bash
#!/bin/bash

# Function to validate resource group name
validate_rg_name() {
  local name=$1
  
  # Check if name ends with -rg
  if [[ ! $name =~ -rg$ ]]; then
    echo "Error: Resource group name must end with '-rg'"
    return 1
  fi
  
  # Check for uppercase letters
  if [[ $name =~ [A-Z] ]]; then
    echo "Error: Resource group name must be lowercase"
    return 1
  fi
  
  # Check for invalid characters
  if [[ ! $name =~ ^[a-z0-9-]+$ ]]; then
    echo "Error: Only lowercase letters, numbers, and hyphens allowed"
    return 1
  fi
  
  # Check for consecutive hyphens
  if [[ $name =~ -- ]]; then
    echo "Error: Consecutive hyphens not allowed"
    return 1
  fi
  
  # Check start/end characters
  if [[ $name =~ ^- ]] || [[ $name =~ -$ ]]; then
    echo "Error: Cannot start or end with a hyphen"
    return 1
  fi
  
  echo "Valid resource group name: $name"
  return 0
}

# Example usage
validate_rg_name "kbudget-dev-rg"
```

## Tagging Requirements

All resource groups must include the following tags (see [Azure Resource Group Best Practices](azure-resource-group-best-practices.md) for details):

### Required Tags

| Tag Name | Description | Example |
|----------|-------------|---------|
| `Environment` | Deployment environment | `Development`, `Staging`, `Production` |
| `Project` | Project identifier | `KBudget-GPT` |
| `Owner` | Team or person responsible | `DevOps-Team` |
| `CostCenter` | Cost center for billing | `CC-12345` |
| `CreatedDate` | Resource group creation date | `2026-02-07` |

## Exceptions and Special Cases

### Exception Process

If a resource group name must deviate from the standard convention:

1. **Document Reason**: Clearly document why the exception is necessary
2. **Approval Required**: Obtain approval from DevOps Team Lead
3. **Update Registry**: Add to exception registry in this document
4. **Minimize Deviations**: Exceptions should be rare and well-justified

### Exception Registry

| Resource Group Name | Reason for Exception | Approved By | Date |
|---------------------|----------------------|-------------|------|
| *(No exceptions currently documented)* | | | |

## Migration and Transition

### Existing Resource Groups

For resource groups that don't follow this naming convention:

1. **Audit**: Identify all non-compliant resource groups
2. **Prioritize**: Focus on production and critical environments first
3. **Plan**: Schedule migration during maintenance windows
4. **Communicate**: Notify all stakeholders of upcoming changes
5. **Update**: Update all documentation, automation, and references
6. **Migrate**: Rename or recreate resource groups as appropriate

**Note**: Resource groups cannot be renamed in Azure. Migration requires creating a new resource group and moving resources.

### Migration Timeline

| Phase | Timeline | Description |
|-------|----------|-------------|
| Phase 1 | Immediate | All new resource groups use new convention |
| Phase 2 | Month 1 | Migrate development and sandbox environments |
| Phase 3 | Month 2 | Migrate staging and QA environments |
| Phase 4 | Month 3 | Migrate production environments (planned maintenance) |

## Related Documentation

- [Azure Resource Group Best Practices](azure-resource-group-best-practices.md) - Comprehensive guide for resource group management
- [Azure Naming Conventions (Microsoft)](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging) - Official Microsoft guidance
- [Azure Resource Naming Restrictions](https://docs.microsoft.com/azure/azure-resource-manager/management/resource-name-rules) - Azure naming rules and restrictions

## Approval and Review

### Review Schedule

This document should be reviewed and updated:
- **Quarterly**: Regular review for updates and improvements
- **As Needed**: When new requirements or environments are added
- **Annually**: Comprehensive review and stakeholder approval

### Stakeholder Approval

| Role | Name | Approval Date | Signature |
|------|------|---------------|-----------|
| Business Analyst | *Pending* | 2026-02-07 | *Digital Approval* |
| DevOps Team Lead | *Pending* | 2026-02-07 | *Digital Approval* |
| Development Manager | *Pending* | 2026-02-07 | *Digital Approval* |
| IT Operations | *Pending* | 2026-02-07 | *Digital Approval* |

## Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-07 | DevOps Team | Initial document creation with standard naming conventions |

## Contact

For questions or clarification regarding these naming conventions, contact:

- **DevOps Team**: devops-team@company.com
- **Document Owner**: Kevin Wilmoth

---

**Document Status**: ✅ Approved for Implementation  
**Effective Date**: 2026-02-07
