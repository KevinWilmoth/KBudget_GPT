# KBudget GPT

A budget management application built with GPT integration.

## Documentation

This repository contains documentation and issue tracking for the KBudget GPT project.

### Project Documentation

- [Azure Resource Group Naming Conventions](docs/azure-resource-group-naming-conventions.md) - Standard naming conventions for Azure Resource Groups across all environments
- [Azure Resource Group Best Practices](docs/azure-resource-group-best-practices.md) - Comprehensive guide for managing Azure Resource Groups, including resource organization, tagging strategies, and lifecycle management

## Repository Structure

```
.
├── docs/                      # Project documentation
│   ├── azure-resource-group-naming-conventions.md
│   └── azure-resource-group-best-practices.md
├── infrastructure/            # Infrastructure as Code
│   └── arm-templates/        # ARM templates
│       └── resource-groups/  # Resource group templates
│           ├── resource-group.json
│           ├── parameters.dev.json
│           ├── parameters.staging.json
│           ├── parameters.prod.json
│           ├── deploy-resource-groups.sh
│           └── README.md
├── issues/                    # Issue tracking
│   └── 12.md                 # Password security requirements
├── ISSUES_BACKLOG.md         # Issue templates and backlog
└── README.md                 # This file
```

## Getting Started

### Infrastructure Deployment

Deploy Azure Resource Groups for dev, staging, and prod environments:

```bash
# Navigate to the resource groups directory
cd infrastructure/arm-templates/resource-groups

# Deploy all environments
./deploy-resource-groups.sh all

# Or deploy individual environments
./deploy-resource-groups.sh dev
./deploy-resource-groups.sh staging
./deploy-resource-groups.sh prod
```

For detailed deployment instructions, see [Resource Groups README](infrastructure/arm-templates/resource-groups/README.md).

### Documentation

For DevOps and infrastructure management, please refer to our documentation:
- **[Azure Resource Group Naming Conventions](docs/azure-resource-group-naming-conventions.md)** - Start here for standard naming patterns for all environments
- **[Azure Resource Group Best Practices](docs/azure-resource-group-best-practices.md)** - Comprehensive guide covering:
  - How to organize and structure Azure resources
  - Recommended tagging strategies for cost management and governance
  - Best practices for resource group lifecycle management

## Contributing

When working with Azure resources for this project, please follow the guidelines outlined in our documentation to ensure consistency and maintainability.

## License

*License information to be added*
