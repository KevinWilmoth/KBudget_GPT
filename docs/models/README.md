# Data Models Documentation

This directory contains comprehensive documentation for all data models used in the KBudget envelope budgeting application.

## Overview

The KBudget application uses Azure Cosmos DB (SQL API) to store data in a document-based format. Each data model is designed to support the envelope budgeting methodology, where users allocate income to different spending categories (envelopes) and track transactions against those allocations.

## Available Data Models

### Core Models

1. **[User Data Model](./USER-DATA-MODEL.md)**
   - User profiles and authentication
   - Preferences and settings
   - Notification configuration
   - Internationalization support

2. **[Budget Data Model](./BUDGET-DATA-MODEL.md)**
   - Budget periods and timeframes
   - Income tracking
   - Budget status and lifecycle
   - Rollover configuration
   - Savings goals and spending limits

3. **[Envelope Data Model](./ENVELOPE-DATA-MODEL.md)**
   - Spending categories (envelopes)
   - Allocation amounts
   - Balance tracking
   - Rollover configuration
   - Goals and overspend controls
   - Category types: essential, discretionary, savings, debt

4. **[Transaction Data Model](./TRANSACTION-DATA-MODEL.md)**
   - Income, expense, and transfer records
   - Transaction metadata and classifications
   - Receipt and attachment management
   - Recurring transaction support
   - Transaction status lifecycle
   - Payment method tracking
   - Balance calculation queries

## Data Model Principles

### Consistency

All data models follow a consistent structure:

```json
{
  "id": "unique-identifier",
  "userId": "partition-key",
  "type": "entity-type",
  "[model-specific-fields]": {},
  "createdAt": "timestamp",
  "createdBy": "user-id",
  "updatedAt": "timestamp", 
  "updatedBy": "user-id",
  "isActive": true,
  "version": "1.0"
}
```

### Key Design Patterns

- **Partition Key Strategy**: All documents are partitioned by `userId` for data isolation
- **Document Type Discriminator**: The `type` field identifies the document type
- **Soft Deletes**: The `isActive` flag supports soft deletion
- **Audit Trail**: `createdAt`, `createdBy`, `updatedAt`, `updatedBy` track changes
- **Schema Versioning**: The `version` field supports future migrations

### Data Integrity

- **Referential Integrity**: Foreign key relationships use GUID references
- **Validation**: All required fields are validated before persistence
- **Uniqueness**: Email addresses and other unique fields are enforced
- **Constraints**: Range validations prevent invalid data

### Performance Optimization

- **Indexing**: Strategic composite indexes for common query patterns
- **Denormalization**: Limited denormalization for read performance
- **Partition Strategy**: User-based partitioning for scalability
- **TTL Support**: Time-to-live policies for temporary data (future)

## C# Model Implementation

The data models are implemented as C# classes in the `KBudgetApp/Models` directory:

- `User.cs` - User data model
- `Budget.cs` - Budget data model
- Additional models will be added as needed

Each model class includes:
- XML documentation comments
- Data annotations for validation
- JSON serialization attributes
- Default values where appropriate

## Azure Cosmos DB Configuration

### Container Strategy

Each entity type has its own container:

| Container | Partition Key | Purpose |
|-----------|---------------|---------|
| Users | `/userId` | User profiles and settings |
| Budgets | `/userId` | Budget periods and allocations |
| Envelopes | `/userId` | Spending categories and balances |
| Transactions | `/userId` | Financial transactions |

### Provisioned Throughput

- **Development**: 400 RU/s per container (minimum)
- **Production**: Auto-scale based on usage patterns
- **Shared Database**: Containers share database throughput where appropriate

## Documentation Standards

Each data model document includes:

1. **Schema Definition**: Complete field specifications
2. **Field Specifications**: Detailed field documentation with types and constraints
3. **Validation Rules**: Business rules and data validation requirements
4. **Default Values**: Default values for all applicable fields
5. **Indexing Strategy**: Cosmos DB index policies and query patterns
6. **Sample Documents**: Example JSON documents for common scenarios
7. **Schema Evolution**: Version history and migration strategies
8. **Compliance Notes**: GDPR and other regulatory considerations

## Related Documentation

- [Cosmos Container Architecture](../../issues/subtask-05-cosmos-container-architecture.md)
- [Azure Infrastructure Overview](../azure-infrastructure-overview.md)
- [RBAC Documentation](../RBAC-DOCUMENTATION.md)
- [Deployment Guide](../POWERSHELL-DEPLOYMENT-GUIDE.md)

## Contributing

When adding or modifying data models:

1. Update the C# model class in `KBudgetApp/Models/`
2. Update or create the model documentation in this directory
3. Update this README with the new model information
4. Update relevant issue documentation in `/issues/`
5. Update indexing policies in ARM templates if needed
6. Update the EPIC document with any architectural changes

## Change Log

| Date | Model | Changes |
|------|-------|---------|
| 2026-02-15 | User | Initial schema design and documentation |
| 2026-02-15 | Budget | Initial schema design and documentation |
| 2026-02-15 | Envelope | Initial schema design and documentation |
| 2026-02-15 | Transaction | Initial schema design and documentation |

---

**Last Updated:** 2026-02-15  
**Maintained By:** Development Team
