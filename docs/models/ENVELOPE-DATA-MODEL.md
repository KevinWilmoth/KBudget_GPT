# Envelope Data Model Documentation

**Version:** 1.0  
**Last Updated:** 2026-02-15  
**Status:** Active

## Overview

The Envelope data model represents budget categories (envelopes) where users allocate funds and track spending in the KBudget envelope budgeting system. Each envelope represents a specific spending category with allocated amounts, current balances, and spending limits. Envelopes are the core mechanism for organizing and controlling spending within budget periods, enabling users to practice the envelope budgeting methodology digitally.

## Table of Contents

- [Schema Definition](#schema-definition)
- [Field Specifications](#field-specifications)
- [Envelope Categories](#envelope-categories)
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
  "type": "envelope",
  "budgetId": "string (GUID)",
  "name": "string",
  "description": "string?",
  "categoryType": "string",
  "icon": "string",
  "color": "string",
  "sortOrder": "number",
  "allocatedAmount": "number",
  "currentBalance": "number",
  "spentAmount": "number",
  "currency": "string",
  "allowRollover": "boolean",
  "rolloverAmount": "number",
  "previousEnvelopeId": "string? (GUID)",
  "targetAmount": "number?",
  "warningThreshold": "number",
  "isOverspendAllowed": "boolean",
  "maxOverspendAmount": "number?",
  "status": "string",
  "isPaused": "boolean",
  "pausedAt": "string? (ISO 8601)",
  "isRecurring": "boolean",
  "createdAt": "string (ISO 8601)",
  "createdBy": "string (GUID)",
  "updatedAt": "string (ISO 8601)",
  "updatedBy": "string (GUID)",
  "isActive": "boolean",
  "lastTransactionAt": "string? (ISO 8601)",
  "version": "string"
}
```

## Field Specifications

### Identity Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (GUID) | Yes | Unique envelope identifier. Primary key in Cosmos DB. |
| `userId` | string (GUID) | Yes | User who owns this envelope. Partition key for user isolation. |
| `type` | string | Yes | Document type discriminator. Always set to "envelope". |

### Envelope Information

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `budgetId` | string (GUID) | Yes | Reference to the budget this envelope belongs to. Must be active budget. |
| `name` | string | Yes | Envelope name (e.g., "Groceries", "Rent"). Must be unique within budget. |
| `description` | string | No | Optional description providing additional context about the envelope. |
| `categoryType` | string | Yes | Category classification: "essential", "discretionary", "savings", or "debt". |
| `icon` | string | Yes | Icon identifier for UI display (e.g., "shopping_cart", "home", "entertainment"). |
| `color` | string | Yes | Hex color code for UI display (e.g., "#4CAF50"). Must be valid hex format. |
| `sortOrder` | number | Yes | Display order within budget. Lower numbers display first. Must be unique within budget. |

### Budget Allocation

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `allocatedAmount` | number | Yes | 0 | Amount allocated for this budget period. Must be >= 0. |
| `currentBalance` | number | Yes | 0 | Current remaining balance. Calculated from allocatedAmount + rolloverAmount - spentAmount. |
| `spentAmount` | number | Yes | 0 | Total spent from this envelope. Updated with each transaction. |
| `currency` | string | Yes | "USD" | ISO 4217 currency code. Inherited from budget/user preference. |

### Rollover Settings

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `allowRollover` | boolean | Yes | true | Allow balance rollover to next period. |
| `rolloverAmount` | number | Yes | 0 | Amount rolled over from previous period. Must be >= 0. |
| `previousEnvelopeId` | string (GUID) | No | null | Reference to envelope from previous budget period for rollover tracking. |

### Goals and Limits

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `targetAmount` | number | No | null | Target/goal amount for this envelope. Optional savings or spending goal. |
| `warningThreshold` | number | Yes | 80 | Percentage to trigger low balance warning (0-100). Default 80%. |
| `isOverspendAllowed` | boolean | Yes | false | Allow negative balances for this envelope. |
| `maxOverspendAmount` | number | No | null | Maximum allowed negative balance. Only applicable if isOverspendAllowed = true. |

### Envelope State

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `status` | string | Yes | "active" | Status: "active", "paused", or "closed". |
| `isPaused` | boolean | Yes | false | Indicates if envelope is temporarily inactive. No transactions allowed when paused. |
| `pausedAt` | string (ISO 8601) | No | null | Timestamp when envelope was paused. Null if not paused. |
| `isRecurring` | boolean | Yes | true | Indicates if this envelope repeats in each budget period. Used for templates. |

### Metadata

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `createdAt` | string (ISO 8601) | Yes | Timestamp when record was created. |
| `createdBy` | string (GUID) | Yes | User ID who created the record. |
| `updatedAt` | string (ISO 8601) | Yes | Timestamp when record was last updated. |
| `updatedBy` | string (GUID) | Yes | User ID who last updated the record. |
| `isActive` | boolean | Yes | Soft delete flag (true = active, false = deleted). |
| `lastTransactionAt` | string (ISO 8601) | No | Timestamp of last transaction affecting this envelope. |
| `version` | string | Yes | Schema version number (e.g., "1.0"). |

## Envelope Categories

### Category Types

Standard category types for organizing envelopes:

#### Essential
Core living expenses that are necessary and recurring.
- **Examples**: Rent, Utilities, Insurance, Groceries, Transportation, Healthcare, Childcare, Debt Minimum Payments
- **Characteristics**: Usually recurring, high priority, fixed or semi-fixed amounts
- **Typical Behavior**: Rarely overspend, consistent month-to-month

#### Discretionary
Optional spending categories for lifestyle and enjoyment.
- **Examples**: Entertainment, Dining Out, Hobbies, Subscriptions, Shopping, Personal Care, Gifts
- **Characteristics**: Flexible amounts, can be reduced if needed, lifestyle choices
- **Typical Behavior**: May vary month-to-month, good candidates for budget cuts

#### Savings
Forward-looking categories for goals and future needs.
- **Examples**: Emergency Fund, Vacation, Down Payment, Retirement, Education, Home Repairs, Car Replacement
- **Characteristics**: Accumulate over time, target amounts, rollover encouraged
- **Typical Behavior**: Grow consistently, rarely spent from, long-term focus

#### Debt
Debt payment categories beyond minimum payments.
- **Examples**: Credit Card Payoff, Student Loan Extra, Car Loan Extra, Mortgage Extra
- **Characteristics**: Decrease total debt, target payoff dates, specific goals
- **Typical Behavior**: Consistent payments, track toward zero balance

### Icon Standards

Predefined icons for consistency and recognition:

| Category | Common Icons |
|----------|--------------|
| Essential | shopping_cart, home, local_hospital, directions_car, lightbulb, water_drop |
| Discretionary | restaurant, movie, sports, card_giftcard, spa, coffee |
| Savings | savings, flight_takeoff, school, emergency, build, directions_car |
| Debt | credit_card, account_balance, school, directions_car, home |

### Color Standards

Suggested color palette with hex codes:

| Category | Suggested Colors | Example Hex Codes |
|----------|------------------|-------------------|
| Essential | Greens | #4CAF50, #66BB6A, #81C784 |
| Discretionary | Blues/Purples | #2196F3, #42A5F5, #9C27B0, #AB47BC |
| Savings | Oranges/Ambers | #FF9800, #FFA726, #FFB74D |
| Debt | Reds/Deep Oranges | #F44336, #EF5350, #FF5722, #FF6F00 |

## Validation Rules

### Amount Validations

- `allocatedAmount` must be >= 0
- `spentAmount` must be >= 0
- `rolloverAmount` must be >= 0
- `currentBalance` must equal `allocatedAmount + rolloverAmount - spentAmount`
- If `isOverspendAllowed = false`, then `currentBalance` must be >= 0
- If `isOverspendAllowed = true` and `maxOverspendAmount` is set, then `currentBalance` must be >= `-maxOverspendAmount`
- `targetAmount` must be > 0 if provided
- `warningThreshold` must be between 0-100 (inclusive)

### Reference Validations

- `budgetId` must reference an existing, active budget for the user
- `previousEnvelopeId` must reference an existing envelope if provided
- Budget referenced by `budgetId` must belong to the user specified in `userId`
- Previous envelope referenced by `previousEnvelopeId` should belong to a previous budget period

### Uniqueness Validations

- Envelope `name` must be unique within a budget period (case-insensitive)
- `sortOrder` must be unique within a budget period
- `id` must be globally unique (GUID)

### Status and State Validations

- `status` must be one of: "active", "paused", "closed"
- `categoryType` must be one of: "essential", "discretionary", "savings", "debt"
- If `isPaused = true`, then `pausedAt` must be set
- If `isPaused = false`, then `pausedAt` must be null
- If `status = "paused"`, then `isPaused` must be true
- Cannot create transactions against paused or closed envelopes

### Format Validations

- `color` must be valid hex color code (e.g., "#4CAF50" or "#FFF")
- `currency` must be valid ISO 4217 currency code (3 uppercase letters)
- All timestamp fields must be valid ISO 8601 format
- All GUID fields must be valid GUID format

## Default Values

The following fields have default values when creating a new envelope:

| Field | Default Value | Notes |
|-------|---------------|-------|
| `type` | "envelope" | Always set to this value |
| `status` | "active" | New envelopes start active |
| `isPaused` | false | Not paused by default |
| `pausedAt` | null | No pause timestamp initially |
| `isRecurring` | true | Most envelopes recur each period |
| `allocatedAmount` | 0 | User sets during configuration |
| `currentBalance` | 0 | Calculated based on allocation |
| `spentAmount` | 0 | No spending initially |
| `rolloverAmount` | 0 | Calculated from previous period |
| `previousEnvelopeId` | null | Set during rollover process |
| `targetAmount` | null | Optional goal amount |
| `warningThreshold` | 80 | Alert at 80% spent |
| `isOverspendAllowed` | false | Prevent overspending by default |
| `maxOverspendAmount` | null | No overspend limit set |
| `currency` | "USD" | Inherited from budget/user |
| `allowRollover` | true | Enable rollover by default |
| `isActive` | true | Active by default |
| `lastTransactionAt` | null | No transactions initially |
| `version` | "1.0" | Current schema version |
| `createdAt` | DateTime.UtcNow | Set to current UTC time |
| `updatedAt` | DateTime.UtcNow | Set to current UTC time |

## Indexing Strategy

### Cosmos DB Container Configuration

**Container Name:** `Envelopes`  
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
    },
    {
      "path": "/icon/?"
    }
  ],
  "compositeIndexes": [
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/budgetId",
        "order": "ascending"
      },
      {
        "path": "/sortOrder",
        "order": "ascending"
      }
    ],
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/budgetId",
        "order": "ascending"
      },
      {
        "path": "/categoryType",
        "order": "ascending"
      }
    ],
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/budgetId",
        "order": "ascending"
      },
      {
        "path": "/isActive",
        "order": "descending"
      }
    ],
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/isRecurring",
        "order": "descending"
      },
      {
        "path": "/sortOrder",
        "order": "ascending"
      }
    ],
    [
      {
        "path": "/userId",
        "order": "ascending"
      },
      {
        "path": "/budgetId",
        "order": "ascending"
      },
      {
        "path": "/status",
        "order": "ascending"
      }
    ]
  ]
}
```

### Index Rationale

1. **Primary Index on `id`**: Automatic in Cosmos DB for point reads
2. **Composite Index on `userId` + `budgetId` + `sortOrder`**: Supports ordered envelope display in budget
3. **Composite Index on `userId` + `budgetId` + `categoryType`**: Enables filtering by category
4. **Composite Index on `userId` + `budgetId` + `isActive`**: Supports active envelope queries
5. **Composite Index on `userId` + `isRecurring` + `sortOrder`**: Supports recurring envelope template queries
6. **Composite Index on `userId` + `budgetId` + `status`**: Enables status-based filtering
7. **Excluded Paths for `description` and `icon`**: Rarely queried, reduce index size

## Common Query Patterns

### Get All Envelopes for Current Budget

```sql
-- Most frequently used query - display all envelopes in budget
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

**Performance:** Single partition query with composite index support.  
**Use Case:** Main budget dashboard displaying all envelopes.

### Get Envelopes by Category

```sql
-- Filter envelopes by category type
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.categoryType = @categoryType 
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

**Use Case:** Display only essential, discretionary, savings, or debt envelopes.

### Get Low Balance Envelopes (Under Threshold)

```sql
-- Find envelopes approaching their limit
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.currentBalance / e.allocatedAmount * 100 < e.warningThreshold
  AND e.isActive = true
  AND e.status = 'active'
ORDER BY e.currentBalance ASC
```

**Use Case:** Alert users to envelopes needing attention or nearing depletion.

### Get Recurring Envelopes (for template)

```sql
-- Get template envelopes for next budget period
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.isRecurring = true 
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

**Use Case:** Create new budget period using previous period's envelope structure.

### Get Envelope by ID

```sql
-- Point read for specific envelope
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.id = @envelopeId
```

**Use Case:** Retrieve specific envelope details for editing or transactions.

### Get Overdrawn Envelopes

```sql
-- Find envelopes with negative balances
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.currentBalance < 0
  AND e.isActive = true
ORDER BY e.currentBalance ASC
```

**Use Case:** Alert users to overspent envelopes requiring attention.

### Get Paused Envelopes

```sql
-- Find temporarily inactive envelopes
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.isPaused = true
  AND e.isActive = true
ORDER BY e.pausedAt DESC
```

**Use Case:** Display paused envelopes for potential reactivation.

### Calculate Budget Totals

```sql
-- Aggregate envelope amounts for budget summary
SELECT 
  SUM(e.allocatedAmount) as totalAllocated,
  SUM(e.spentAmount) as totalSpent,
  SUM(e.currentBalance) as totalRemaining,
  COUNT(1) as envelopeCount
FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.isActive = true
  AND e.status = 'active'
```

**Use Case:** Calculate budget-level aggregations for reporting.

## Sample Documents

### Complete Envelope - Groceries (Essential)

```json
{
  "id": "e12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Groceries",
  "description": "Food and household items",
  "categoryType": "essential",
  "icon": "shopping_cart",
  "color": "#4CAF50",
  "sortOrder": 1,
  "allocatedAmount": 600.00,
  "currentBalance": 275.50,
  "spentAmount": 324.50,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 0.00,
  "previousEnvelopeId": "e12e8400-e29b-41d4-a716-446655440000",
  "targetAmount": 600.00,
  "warningThreshold": 80,
  "isOverspendAllowed": false,
  "maxOverspendAmount": 0.00,
  "status": "active",
  "isPaused": false,
  "pausedAt": null,
  "isRecurring": true,
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T15:30:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastTransactionAt": "2026-02-15T12:00:00Z",
  "version": "1.0"
}
```

### Entertainment (Discretionary)

```json
{
  "id": "e22e8400-e29b-41d4-a716-446655440002",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Entertainment",
  "description": "Movies, concerts, streaming services",
  "categoryType": "discretionary",
  "icon": "movie",
  "color": "#2196F3",
  "sortOrder": 5,
  "allocatedAmount": 150.00,
  "currentBalance": 75.00,
  "spentAmount": 75.00,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 0.00,
  "targetAmount": null,
  "warningThreshold": 80,
  "isOverspendAllowed": false,
  "status": "active",
  "isPaused": false,
  "pausedAt": null,
  "isRecurring": true,
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-10T18:30:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastTransactionAt": "2026-02-10T18:30:00Z",
  "version": "1.0"
}
```

### Emergency Fund (Savings)

```json
{
  "id": "e32e8400-e29b-41d4-a716-446655440003",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Emergency Fund",
  "description": "3-6 months expenses for emergencies",
  "categoryType": "savings",
  "icon": "savings",
  "color": "#FF9800",
  "sortOrder": 10,
  "allocatedAmount": 500.00,
  "currentBalance": 8650.00,
  "spentAmount": 0.00,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 8150.00,
  "previousEnvelopeId": "e32e8400-e29b-41d4-a716-446655440000",
  "targetAmount": 15000.00,
  "warningThreshold": 0,
  "isOverspendAllowed": false,
  "status": "active",
  "isPaused": false,
  "pausedAt": null,
  "isRecurring": true,
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-01T10:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastTransactionAt": null,
  "version": "1.0"
}
```

### Credit Card Payoff (Debt)

```json
{
  "id": "e42e8400-e29b-41d4-a716-446655440004",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Credit Card Payoff",
  "description": "Extra payment toward Visa balance",
  "categoryType": "debt",
  "icon": "credit_card",
  "color": "#F44336",
  "sortOrder": 15,
  "allocatedAmount": 300.00,
  "currentBalance": 0.00,
  "spentAmount": 300.00,
  "currency": "USD",
  "allowRollover": false,
  "rolloverAmount": 0.00,
  "targetAmount": 3000.00,
  "warningThreshold": 100,
  "isOverspendAllowed": false,
  "status": "active",
  "isPaused": false,
  "pausedAt": null,
  "isRecurring": true,
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-05T14:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastTransactionAt": "2026-02-05T14:00:00Z",
  "version": "1.0"
}
```

### Paused Envelope

```json
{
  "id": "e52e8400-e29b-41d4-a716-446655440005",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Gym Membership",
  "description": "Paused during injury recovery",
  "categoryType": "discretionary",
  "icon": "sports",
  "color": "#9C27B0",
  "sortOrder": 8,
  "allocatedAmount": 0.00,
  "currentBalance": 45.00,
  "spentAmount": 0.00,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 45.00,
  "previousEnvelopeId": "e52e8400-e29b-41d4-a716-446655440000",
  "targetAmount": null,
  "warningThreshold": 80,
  "isOverspendAllowed": false,
  "status": "paused",
  "isPaused": true,
  "pausedAt": "2026-02-08T10:00:00Z",
  "isRecurring": true,
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-08T10:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastTransactionAt": null,
  "version": "1.0"
}
```

### Minimal Envelope

```json
{
  "id": "e62e8400-e29b-41d4-a716-446655440006",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Miscellaneous",
  "categoryType": "discretionary",
  "icon": "category",
  "color": "#607D8B",
  "sortOrder": 20,
  "allocatedAmount": 100.00,
  "currentBalance": 100.00,
  "spentAmount": 0.00,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 0.00,
  "warningThreshold": 80,
  "isOverspendAllowed": false,
  "status": "active",
  "isPaused": false,
  "pausedAt": null,
  "isRecurring": true,
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-01T10:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastTransactionAt": null,
  "version": "1.0"
}
```

### Overspend Allowed Envelope

```json
{
  "id": "e72e8400-e29b-41d4-a716-446655440007",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Medical Expenses",
  "description": "Healthcare with overspend allowed for emergencies",
  "categoryType": "essential",
  "icon": "local_hospital",
  "color": "#66BB6A",
  "sortOrder": 4,
  "allocatedAmount": 200.00,
  "currentBalance": -50.00,
  "spentAmount": 250.00,
  "currency": "USD",
  "allowRollover": true,
  "rolloverAmount": 0.00,
  "targetAmount": null,
  "warningThreshold": 80,
  "isOverspendAllowed": true,
  "maxOverspendAmount": 500.00,
  "status": "active",
  "isPaused": false,
  "pausedAt": null,
  "isRecurring": true,
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-12T16:45:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastTransactionAt": "2026-02-12T16:45:00Z",
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

- **Envelope Groups**: `groupId` for organizing related envelopes
- **Sub-Envelopes**: `parentEnvelopeId` for hierarchical envelope structures
- **Percentage Allocation**: `allocationPercentage` for automatic income-based allocation
- **Funding Priority**: `fundingOrder` for prioritizing envelope allocations
- **Notes**: `notes` array for tracking envelope-specific notes or history
- **Shared Envelopes**: `sharedWith` array for household budget sharing
- **Tags**: `tags` array for flexible categorization
- **Attachments**: `attachmentUrls` for receipts or documentation

## Business Logic

### Balance Calculation Logic

The current balance is calculated using the following formula:

```javascript
currentBalance = allocatedAmount + rolloverAmount - spentAmount
```

**Example:**
- Allocated: $600
- Rollover: $0
- Spent: $324.50
- Balance: $600 + $0 - $324.50 = $275.50

### Transaction Impact

After each transaction affecting an envelope:

1. **Update Spent Amount**: Increase for expenses, decrease for refunds/credits
2. **Recalculate Balance**: Apply balance calculation formula
3. **Check Threshold**: Compare current balance to warning threshold
4. **Generate Alerts**: If balance percentage < warning threshold, notify user
5. **Update Timestamp**: Set `lastTransactionAt` to transaction timestamp
6. **Validate Overspend**: If `isOverspendAllowed = false`, prevent negative balance

### Envelope Creation Workflow

1. User creates new envelope in a budget
2. System validates:
   - Budget exists and is active
   - Name is unique within budget
   - Sort order is unique within budget
   - Category type is valid
   - Color is valid hex format
   - All amounts are non-negative
3. Envelope created with default values
4. User can configure allocation, rollover, and limits
5. Envelope becomes available for transactions

### Rollover Process

When creating a new budget period with rollover enabled:

1. Identify recurring envelopes from previous budget (`isRecurring = true`)
2. For each recurring envelope:
   - Create new envelope in new budget with same configuration
   - Copy `name`, `categoryType`, `icon`, `color`, `sortOrder`
   - Copy `allocatedAmount` (or allow user to adjust)
   - Set `previousEnvelopeId` to previous envelope's `id`
   - If `allowRollover = true`:
     - Calculate rollover: `previousEnvelope.currentBalance`
     - Set `rolloverAmount` to calculated value
     - Add rollover to `currentBalance`
   - Reset `spentAmount` to 0
   - Set `lastTransactionAt` to null
3. Adjust sort order if needed to maintain continuity
4. Validate no duplicate names or sort orders

### Envelope Pausing

When pausing an envelope:

1. User initiates pause action
2. System validates envelope is currently active
3. Set `status = "paused"` and `isPaused = true`
4. Set `pausedAt` to current timestamp
5. Preserve current balance and all allocations
6. Prevent new transactions:
   - Validate on transaction creation
   - Return error if envelope is paused
7. Display paused envelopes separately in UI

When resuming a paused envelope:

1. User initiates resume action
2. Set `status = "active"` and `isPaused = false`
3. Set `pausedAt = null`
4. Envelope becomes available for transactions
5. Balance and allocations remain unchanged

### Envelope Closure

When closing an envelope:

1. User initiates closure or budget period ends
2. Set `status = "closed"`
3. Preserve all data for historical records
4. Prevent new transactions
5. If next budget period has corresponding envelope with rollover:
   - Transfer `currentBalance` to next envelope's `rolloverAmount`
6. Envelope remains in database (soft delete only)

### Overspend Management

For envelopes with `isOverspendAllowed = false`:
- Transaction validation prevents creating expenses that would result in negative balance
- User must transfer funds from another envelope first
- Strict budget adherence enforced

For envelopes with `isOverspendAllowed = true`:
- Negative balances are permitted
- If `maxOverspendAmount` is set, balance cannot go below `-maxOverspendAmount`
- Useful for variable essential expenses (medical, car repairs)
- User should reconcile negative balances in next period

### Alert Triggers

System generates alerts when:

1. **Low Balance Warning**: `(currentBalance / allocatedAmount * 100) < warningThreshold`
2. **Overspent**: `currentBalance < 0` (if overspend allowed)
3. **Approaching Overspend Limit**: `currentBalance < (-maxOverspendAmount * 0.8)` (if limit set)
4. **No Allocation**: `allocatedAmount = 0` and envelope is active
5. **Stale Envelope**: No transactions in 60+ days for recurring envelope

## Related Documentation

- [User Data Model](./USER-DATA-MODEL.md)
- [Budget Data Model](./BUDGET-DATA-MODEL.md)
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
