# Data Models Documentation

This directory contains comprehensive documentation for all data models in the KBudget envelope budgeting system.

## Overview

The KBudget application uses Azure Cosmos DB to store data across multiple containers, each optimized for specific query patterns and data isolation requirements.

## Data Model Architecture

### Core Entities

1. **[User](USER-DATA-MODEL.md)** - User profiles, preferences, and settings
2. **Budget** - Budget definitions and periods (coming soon)
3. **Envelope** - Spending categories and allocations (coming soon)
4. **Transaction** - Financial transactions and transfers (coming soon)

### Entity Relationships

```
User (1) ──── (many) Budgets
Budget (1) ──── (many) Envelopes
Envelope (1) ──── (many) Transactions
```

## Available Documentation

### User Data Model
- **File:** [USER-DATA-MODEL.md](USER-DATA-MODEL.md)
- **Status:** ✅ Complete
- **Container:** `users`
- **Partition Key:** `/userId`
- **Description:** Stores user profile information, preferences, settings, and metadata

### Budget Data Model
- **File:** BUDGET-DATA-MODEL.md
- **Status:** 🚧 Coming Soon
- **Container:** `budgets`
- **Partition Key:** `/userId`
- **Description:** Defines budget periods, allocations, and tracking

### Envelope Data Model
- **File:** ENVELOPE-DATA-MODEL.md
- **Status:** 🚧 Coming Soon
- **Container:** `envelopes`
- **Partition Key:** `/userId`
- **Description:** Categories for spending with allocated amounts and balances

### Transaction Data Model
- **File:** TRANSACTION-DATA-MODEL.md
- **Status:** 🚧 Coming Soon
- **Container:** `transactions`
- **Partition Key:** `/userId`
- **Description:** Financial transactions including income, expenses, and transfers

## Documentation Structure

Each data model document includes:

1. **Overview** - Purpose and business context
2. **Container Information** - Cosmos DB container and partition strategy
3. **Schema Definition** - Complete field definitions with types and constraints
4. **Sample Document** - Example JSON document
5. **Validation Rules** - Data validation requirements
6. **Indexing Strategy** - Index definitions and query optimization
7. **Default Values** - Default values for optional fields
8. **Common Query Patterns** - SQL queries with RU estimates
9. **Business Logic** - Workflows and processing rules
10. **Schema Evolution Strategy** - Versioning and migration approach
11. **GDPR Compliance** - Data privacy and user rights
12. **Security Considerations** - Access control and data protection
13. **Performance Optimization** - Caching and query optimization

## Using This Documentation

### For Developers
- Review schema definitions before implementing data access code
- Use sample documents for testing
- Follow query patterns for efficient data access
- Implement validation rules in application code

### For Database Administrators
- Use indexing strategy to configure Cosmos DB containers
- Monitor RU consumption against estimates
- Plan capacity based on query patterns

### For Architects
- Understand partition strategy and scalability implications
- Review entity relationships and data isolation
- Plan schema evolution and migration strategies

## Schema Validation

All data models include JSON Schema definitions in the `/schemas` directory:

- `user-schema.json` - JSON Schema for User entity
- `user-sample.json` - Valid sample User document

See [schemas/README.md](../../schemas/README.md) for validation instructions.

## Query Performance

Estimated Request Unit (RU) consumption for common operations:

| Operation | Entity | RU Estimate | Notes |
|-----------|--------|-------------|-------|
| Read by ID | User | 1 RU | Single partition read |
| Read by Email | User | 2-3 RU | Indexed query |
| Update User | User | 5-10 RU | Replace operation |
| List Active Users | User | Varies | Cross-partition query |

## Best Practices

### Partition Key Design
- All containers use `/userId` as partition key for data isolation
- Ensures all user data is in a single partition
- Enables efficient queries for single-user operations
- Supports multi-tenant architecture

### Query Optimization
- Always include partition key in queries when possible
- Use projection to select only required fields
- Leverage composite indexes for complex queries
- Use continuation tokens for pagination

### Data Integrity
- Validate all data against JSON Schema before writing
- Use soft deletes (`isActive` flag) instead of hard deletes
- Maintain audit trail with `createdAt`, `createdBy`, `updatedAt`, `updatedBy`
- Include schema version field for migration support

### GDPR Compliance
- Support right to erasure (soft delete + permanent delete)
- Enable data export in portable format
- Log all access to personal data
- Implement data retention policies

## Related Documentation

### Infrastructure
- [Cosmos DB ARM Templates](../../infrastructure/arm-templates/cosmos-database/README.md)
- [Container Architecture](../../infrastructure/arm-templates/cosmos-database/CONTAINERS-REFERENCE.md) (coming soon)

### Application Documentation
- [Azure Infrastructure Overview](../azure-infrastructure-overview.md)
- [Azure AD Authentication](../AAD-AUTHENTICATION-SETUP-GUIDE.md)
- [Monitoring and Observability](../MONITORING-OBSERVABILITY.md)

### Issue Tracking
- [EPIC: Envelope-Based Budgeting Data Model](../../issues/EPIC-envelope-budgeting-data-model.md)
- [Subtask 1: User Data Model](../../issues/subtask-01-user-data-model.md)

## Contributing

When adding or updating data models:

1. Update the JSON Schema in `/schemas`
2. Update the documentation in this directory
3. Validate sample documents against schema
4. Update related ARM templates if needed
5. Update this README with new entity information

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-15 | Initial documentation with User data model |

---

**Status:** 🚧 In Progress  
**Last Updated:** 2026-02-15
