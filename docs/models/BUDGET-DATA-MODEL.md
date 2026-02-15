# Budget Data Model Documentation

**Version:** 1.0  
**Last Updated:** 2026-02-15  
**Status:** Active

## Overview

The Budget data model represents budget periods and overall budget configuration for users in the KBudget envelope budgeting system. Each budget represents a specific time period (e.g., monthly, bi-weekly) during which users allocate income to envelopes and track expenses. Budgets serve as the container for financial planning within defined time boundaries and enable users to manage their finances across multiple periods.

## Table of Contents

- [Schema Definition](#schema-definition)
- [Field Specifications](#field-specifications)
- [Budget Lifecycle States](#budget-lifecycle-states)
- [Validation Rules](#validation-rules)
- [Default Values](#default-values)
- [Indexing Strategy](#indexing-strategy)
- [Common Query Patterns](#common-query-patterns)
- [Sample Documents](#sample-documents)
- [Schema Evolution](#schema-evolution)
- [Business Logic](#business-logic)

## Schema Definition

### Document Structure

```json
{
  "id": "string (GUID)",
  "userId": "string (GUID)",
  "type": "budget",
  "name": "string",
  "description": "string?",
  "budgetPeriodType": "string",
  "startDate": "string (ISO 8601 date)",
  "endDate": "string (ISO 8601 date)",
  "fiscalYear": "number",
  "fiscalMonth": "number",
  "status": "string",
  "isCurrent": "boolean",
  "totalIncome": "number",
  "totalAllocated": "number",
  "totalSpent": "number",
  "totalRemaining": "number",
  "currency": "string",
  "allowRollover": "boolean",
  "previousBudgetId": "string? (GUID)",
  "rolloverAmount": "number",
  "savingsGoal": "number",
  "savingsActual": "number",
  "spendingLimit": "number?",
  "createdAt": "string (ISO 8601)",
  "createdBy": "string (GUID)",
  "updatedAt": "string (ISO 8601)",
  "updatedBy": "string (GUID)",
  "isActive": "boolean",
  "isArchived": "boolean",
  "version": "string"
}
```

## Field Specifications

### Identity Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (GUID) | Yes | Unique budget identifier. Primary key in Cosmos DB. |
| `userId` | string (GUID) | Yes | User who owns this budget. Partition key for user isolation. |
| `type` | string | Yes | Document type discriminator. Always set to "budget". |

### Budget Information

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Budget name for easy identification (e.g., "February 2026 Budget"). |
| `description` | string | No | Optional description providing additional context. |
| `budgetPeriodType` | string | Yes | Period type: "monthly", "biweekly", "weekly", or "custom". |
| `startDate` | string (ISO 8601) | Yes | Budget period start date. Must be before endDate. |
| `endDate` | string (ISO 8601) | Yes | Budget period end date. Must be after startDate. |
| `fiscalYear` | number | Yes | Fiscal year this budget belongs to (e.g., 2026). Range: 2000-2100. |
| `fiscalMonth` | number | Yes | Fiscal month number (1-12). Adjusted for fiscal year start. |

### Budget Status

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `status` | string | Yes | "draft" | Current status: "draft", "active", "closed", or "archived". |
| `isCurrent` | boolean | Yes | false | Indicates if this is the current active budget. Only one per user. |
| `totalIncome` | number | Yes | 0 | Total income allocated for this period. |
| `totalAllocated` | number | Yes | 0 | Total amount allocated to envelopes. |
| `totalSpent` | number | Yes | 0 | Total amount spent from all envelopes. Calculated from transactions. |
| `totalRemaining` | number | Yes | 0 | Unallocated funds (totalIncome - totalAllocated). |
| `currency` | string | Yes | "USD" | ISO 4217 currency code. Must match user's preference. |

### Rollover Configuration

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `allowRollover` | boolean | Yes | true | Allow envelope balances to roll over from previous budget. |
| `previousBudgetId` | string (GUID) | No | null | Reference to previous budget for rollover and linking. |
| `rolloverAmount` | number | Yes | 0 | Total amount rolled over from previous budget period. |

### Goals and Targets

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `savingsGoal` | number | Yes | 0 | Target savings amount for this period. |
| `savingsActual` | number | Yes | 0 | Actual savings achieved. Calculated from income - expenses. |
| `spendingLimit` | number | No | null | Maximum spending limit for the period (optional). |

### Metadata

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `createdAt` | string (ISO 8601) | Yes | Timestamp when record was created. |
| `createdBy` | string (GUID) | Yes | User ID who created the record. |
| `updatedAt` | string (ISO 8601) | Yes | Timestamp when record was last updated. |
| `updatedBy` | string (GUID) | Yes | User ID who last updated the record. |
| `isActive` | boolean | Yes | Soft delete flag (true = active, false = deleted). |
| `isArchived` | boolean | Yes | Archive flag for old budgets. Recommended after 2 years. |
| `version` | string | Yes | Schema version number (e.g., "1.0"). |

## Budget Lifecycle States

### State Definitions

1. **Draft**
   - Budget is being set up and configured
   - Not yet active or in use
   - Can be edited freely without affecting financial tracking
   - Transition: User activates the budget → moves to Active

2. **Active**
   - Budget is current and in use
   - Users can allocate funds to envelopes
   - Transactions are tracked against this budget
   - Only one budget can be active (`isCurrent = true`) per user at a time
   - Transition: Budget period ends → moves to Closed

3. **Closed**
   - Budget period has ended
   - No new allocations or transactions allowed
   - Still accessible for reporting and analysis
   - Balances can roll over to next budget if enabled
   - Transition: After 2 years → moves to Archived

4. **Archived**
   - Old budget moved to long-term storage
   - Read-only access for historical records
   - Optimizes query performance for active budgets
   - Typically archived after 2 years

### State Transition Rules

```
Draft → Active: User manually activates the budget
Active → Closed: Budget period end date passes
Closed → Archived: Automated after 2 years or manual archive
Active → Draft: Only if no transactions exist (rollback)
```

### Automatic State Management

- When a budget is activated (`status = "active"`), set `isCurrent = true`
- Automatically set previous active budget's `isCurrent = false`
- When budget end date passes, automatically transition to "closed" status
- Archive budgets older than 2 years via scheduled job

## Validation Rules

### Date Validations

- `startDate` must be before `endDate`
- Budget period dates cannot overlap with other budgets for the same user
- Dates must be valid ISO 8601 format
- `fiscalYear` must be within reasonable range (2000-2100)
- `fiscalMonth` must be 1-12

### Status and Current Budget

- Only one budget can have `isCurrent = true` per user at any time
- Status must be one of: "draft", "active", "closed", "archived"
- Status transitions must follow lifecycle: draft → active → closed → archived
- Cannot activate a budget with overlapping dates with another active budget

### Financial Validations

- `totalIncome` must be >= 0
- `totalAllocated` must be >= 0
- `totalSpent` must be >= 0
- `totalAllocated` should not exceed `totalIncome` (warning, not error)
- `totalRemaining` should equal `totalIncome - totalAllocated`
- `rolloverAmount` must be >= 0
- `savingsGoal` must be >= 0
- `spendingLimit` must be > 0 if provided

### Currency and Period Type

- `currency` must be valid ISO 4217 currency code (3 uppercase letters)
- `currency` must match user's default currency preference
- `budgetPeriodType` must be one of: "monthly", "biweekly", "weekly", "custom"

### Rollover Configuration

- If `previousBudgetId` is set, the referenced budget must exist
- Previous budget should be in "closed" or "archived" status
- `rolloverAmount` should match sum of envelope balances from previous budget

## Default Values

The following fields have default values when creating a new budget:

| Field | Default Value | Notes |
|-------|---------------|-------|
| `type` | "budget" | Always set to this value |
| `status` | "draft" | New budgets start in draft state |
| `isCurrent` | false | Must be explicitly activated |
| `budgetPeriodType` | "monthly" | Inherited from user preference |
| `totalIncome` | 0 | Set during budget setup |
| `totalAllocated` | 0 | Calculated from envelope allocations |
| `totalSpent` | 0 | Calculated from transactions |
| `totalRemaining` | 0 | Calculated as totalIncome - totalAllocated |
| `currency` | "USD" | Inherited from user preference |
| `allowRollover` | true | Inherited from user preference |
| `rolloverAmount` | 0 | Calculated from previous budget |
| `savingsGoal` | 0 | User can set optional goal |
| `savingsActual` | 0 | Calculated from income - expenses |
| `isActive` | true | Active by default |
| `isArchived` | false | Not archived by default |
| `version` | "1.0" | Current schema version |
| `createdAt` | DateTime.UtcNow | Set to current UTC time |
| `updatedAt` | DateTime.UtcNow | Set to current UTC time |

## Indexing Strategy

### Cosmos DB Container Configuration

**Container Name:** `Budgets`  
**Partition Key:** `/userId`  
**Throughput:** 400 RU/s (can scale as needed)

### Index Policy

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {
      "path": "/*"
    }
  ],
  "excludedPaths": [
    {
      "path": "/description/?"
    }
  ],
  "compositeIndexes": [
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/startDate",
        "order": "descending"
      }
    ],
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/isCurrent",
        "order": "descending"
      }
    ],
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/fiscalYear",
        "order": "descending"
      },
      {
        "path": "/fiscalMonth",
        "order": "descending"
      }
    ],
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/status",
        "order": "ascending"
      },
      {
        "path": "/startDate",
        "order": "descending"
      }
    ],
    [
      {
        "path": "/isActive",
        "order": "descending"
      },
      {
        "path": "/isArchived",
        "order": "ascending"
      }
    ]
  ]
}
```

### Index Rationale

1. **Primary Index on `id`**: Automatic in Cosmos DB for point reads
2. **Composite Index on `userId` + `startDate`**: Supports chronological budget queries
3. **Composite Index on `userId` + `isCurrent`**: Fast lookup of current active budget
4. **Composite Index on `userId` + `fiscalYear` + `fiscalMonth`**: Supports fiscal reporting
5. **Composite Index on `userId` + `status` + `startDate`**: Filter budgets by status and date
6. **Composite Index on `isActive` + `isArchived`**: Supports archival queries
7. **Excluded Path for `description`**: Descriptions are rarely queried, exclude to reduce index size

## Common Query Patterns

### Get Current Budget for User

```sql
-- Most frequently used query
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.isCurrent = true 
  AND b.isActive = true
```

**Performance:** Single partition query with composite index support.

### Get All Budgets for User (Chronological)

```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.isActive = true
ORDER BY b.startDate DESC
```

**Use Case:** Display budget history in descending order.

### Get Budgets for Fiscal Year

```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.fiscalYear = @fiscalYear 
  AND b.isActive = true
ORDER BY b.startDate DESC
```

**Use Case:** Annual budget reporting and analysis.

### Get Budget History (Last 12 Months)

```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.startDate >= @startDate 
  AND b.isActive = true
ORDER BY b.startDate DESC
```

**Use Case:** Recent budget history for trends and comparisons.

### Get Budgets by Status

```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.status = @status 
  AND b.isActive = true
ORDER BY b.startDate DESC
```

**Use Case:** List all draft, active, closed, or archived budgets.

### Get Active Non-Archived Budgets

```sql
SELECT * FROM budgets b 
WHERE b.isActive = true 
  AND b.isArchived = false
```

**Use Case:** System-wide query for archival processes (cross-partition).

### Get Budget by ID

```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.id = @budgetId
```

**Use Case:** Point read for specific budget details.

### Find Overlapping Budgets

```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.status IN ("draft", "active")
  AND b.startDate <= @newEndDate
  AND b.endDate >= @newStartDate
  AND b.isActive = true
```

**Use Case:** Validate no date overlap when creating/updating budgets.

## Sample Documents

### Complete Budget (Active)

```json
{
  "id": "b12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "February 2026 Budget",
  "description": "Monthly budget for February 2026",
  "budgetPeriodType": "monthly",
  "startDate": "2026-02-01T00:00:00Z",
  "endDate": "2026-02-28T23:59:59Z",
  "fiscalYear": 2026,
  "fiscalMonth": 2,
  "status": "active",
  "isCurrent": true,
  "totalIncome": 5000.00,
  "totalAllocated": 4500.00,
  "totalSpent": 2300.00,
  "totalRemaining": 500.00,
  "currency": "USD",
  "allowRollover": true,
  "previousBudgetId": "b12e8400-e29b-41d4-a716-446655440000",
  "rolloverAmount": 150.00,
  "savingsGoal": 1000.00,
  "savingsActual": 700.00,
  "spendingLimit": 4000.00,
  "createdAt": "2026-01-28T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T15:30:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "isArchived": false,
  "version": "1.0"
}
```

### Minimal Budget (Draft)

```json
{
  "id": "b22e8400-e29b-41d4-a716-446655440002",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "March 2026 Budget",
  "budgetPeriodType": "monthly",
  "startDate": "2026-03-01T00:00:00Z",
  "endDate": "2026-03-31T23:59:59Z",
  "fiscalYear": 2026,
  "fiscalMonth": 3,
  "status": "draft",
  "isCurrent": false,
  "totalIncome": 0,
  "totalAllocated": 0,
  "totalSpent": 0,
  "totalRemaining": 0,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 0,
  "savingsGoal": 0,
  "savingsActual": 0,
  "createdAt": "2026-02-15T16:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T16:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "isArchived": false,
  "version": "1.0"
}
```

### Closed Budget with Rollover

```json
{
  "id": "b12e8400-e29b-41d4-a716-446655440000",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "January 2026 Budget",
  "description": "First budget of 2026",
  "budgetPeriodType": "monthly",
  "startDate": "2026-01-01T00:00:00Z",
  "endDate": "2026-01-31T23:59:59Z",
  "fiscalYear": 2026,
  "fiscalMonth": 1,
  "status": "closed",
  "isCurrent": false,
  "totalIncome": 5000.00,
  "totalAllocated": 4850.00,
  "totalSpent": 4700.00,
  "totalRemaining": 150.00,
  "currency": "USD",
  "allowRollover": true,
  "previousBudgetId": "a12e8400-e29b-41d4-a716-446655440099",
  "rolloverAmount": 100.00,
  "savingsGoal": 500.00,
  "savingsActual": 300.00,
  "spendingLimit": 4500.00,
  "createdAt": "2025-12-28T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-01T00:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "isArchived": false,
  "version": "1.0"
}
```

### Biweekly Budget

```json
{
  "id": "c12e8400-e29b-41d4-a716-446655440003",
  "userId": "660e8400-e29b-41d4-a716-446655440001",
  "type": "budget",
  "name": "Pay Period 2026-02-01",
  "description": "Biweekly budget for Feb 1-14",
  "budgetPeriodType": "biweekly",
  "startDate": "2026-02-01T00:00:00Z",
  "endDate": "2026-02-14T23:59:59Z",
  "fiscalYear": 2026,
  "fiscalMonth": 2,
  "status": "active",
  "isCurrent": true,
  "totalIncome": 2500.00,
  "totalAllocated": 2400.00,
  "totalSpent": 1800.00,
  "totalRemaining": 100.00,
  "currency": "USD",
  "allowRollover": false,
  "rolloverAmount": 0,
  "savingsGoal": 500.00,
  "savingsActual": 700.00,
  "createdAt": "2026-01-31T10:00:00Z",
  "createdBy": "660e8400-e29b-41d4-a716-446655440001",
  "updatedAt": "2026-02-10T14:30:00Z",
  "updatedBy": "660e8400-e29b-41d4-a716-446655440001",
  "isActive": true,
  "isArchived": false,
  "version": "1.0"
}
```

### Archived Budget

```json
{
  "id": "a12e8400-e29b-41d4-a716-446655440099",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "December 2023 Budget",
  "budgetPeriodType": "monthly",
  "startDate": "2023-12-01T00:00:00Z",
  "endDate": "2023-12-31T23:59:59Z",
  "fiscalYear": 2023,
  "fiscalMonth": 12,
  "status": "archived",
  "isCurrent": false,
  "totalIncome": 4800.00,
  "totalAllocated": 4800.00,
  "totalSpent": 4600.00,
  "totalRemaining": 0,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 0,
  "savingsGoal": 400.00,
  "savingsActual": 200.00,
  "createdAt": "2023-11-28T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-01-01T00:00:00Z",
  "updatedBy": "system",
  "isActive": true,
  "isArchived": true,
  "version": "1.0"
}
```

## Schema Evolution

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-15 | Initial schema design |

### Migration Strategy

When schema changes are required in future versions:

1. **Backward Compatibility**: Always maintain backward compatibility where possible
2. **Version Field**: Use the `version` field to identify schema version
3. **Migration Scripts**: Create migration scripts to update existing documents
4. **Gradual Rollout**: Deploy schema changes gradually with feature flags
5. **Validation**: Validate all documents after migration
6. **Testing**: Test migrations in development environment first

### Future Enhancements

Potential future additions to the schema:

- **Multi-Currency Support**: Support budgets in different currencies
- **Shared Budgets**: `sharedWith` array for household budget sharing
- **Budget Templates**: `templateId` for recurring budget setup
- **Auto-Creation**: `autoCreateNext` flag for automatic period budgets
- **Notifications**: `notificationPreferences` for budget-specific alerts
- **Categories**: `categoryId` for budget categorization
- **Tags**: `tags` array for flexible organization
- **Attachments**: `attachmentUrls` for supporting documents

## Business Logic

### Budget Creation Workflow

1. User initiates budget creation
2. System validates:
   - No overlapping date ranges with existing budgets
   - Currency matches user preference
   - Start date is before end date
3. Budget created in "draft" status
4. User configures income, allocations, goals
5. User activates budget:
   - System sets `status = "active"` and `isCurrent = true`
   - Previous active budget's `isCurrent` set to false
6. If rollover enabled:
   - Calculate rollover amounts from previous budget
   - Update `previousBudgetId` and `rolloverAmount`

### Budget Closure Workflow

1. Budget end date passes
2. Automated job or manual closure:
   - Set `status = "closed"`
   - Set `isCurrent = false`
   - Calculate final `savingsActual`
   - Freeze `totalSpent` and `totalAllocated`
3. If next budget exists with rollover:
   - Calculate envelope balances to roll forward
   - Update next budget's `rolloverAmount`

### Budget Archival Workflow

1. Budget is older than 2 years (configurable)
2. Automated archival job:
   - Set `status = "archived"`
   - Set `isArchived = true`
   - Move to archive container or separate partition (optional)
3. Budget remains accessible but excluded from active queries

### Calculation Rules

#### Total Remaining
```
totalRemaining = totalIncome - totalAllocated
```

#### Savings Actual
```
savingsActual = totalIncome - totalSpent
```

#### Rollover Amount
```
rolloverAmount = SUM(envelope.currentBalance) from previousBudget
```

### Automatic State Transitions

- **Draft to Active**: Manual user action
- **Active to Closed**: Automatic when `endDate` passes
- **Closed to Archived**: Automatic after 2 years or manual
- **Current Flag Management**: Automatic when new budget activated

### Validation Triggers

- **On Create**: Validate dates, currency, period type
- **On Update**: Validate state transitions, date changes
- **On Activate**: Ensure no overlapping active budgets
- **On Close**: Calculate final balances
- **On Delete (Soft)**: Set `isActive = false`, preserve data

## Related Documentation

- [User Data Model](./USER-DATA-MODEL.md)
- [Envelope Data Model](./ENVELOPE-DATA-MODEL.md)
- [Transaction Data Model](./TRANSACTION-DATA-MODEL.md) *(Coming Soon)*
- [Cosmos Container Architecture](../../issues/subtask-05-cosmos-container-architecture.md)
- [Azure Infrastructure Overview](../azure-infrastructure-overview.md)
- [RBAC Documentation](../RBAC-DOCUMENTATION.md)

## Change Log

| Date | Author | Changes |
|------|--------|---------|
| 2026-02-15 | System | Initial documentation creation |

---

**Document Owner:** Development Team  
**Review Cycle:** Quarterly  
**Next Review:** 2026-05-15
