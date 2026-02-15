# Subtask 2: Design Budget Data Model

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Design the Budget data model to represent budget periods and overall budget configuration for users. Each budget represents a specific time period (e.g., monthly, bi-weekly) during which users allocate income to envelopes and track expenses.

## Requirements

### Data Model Schema
Define the Budget document structure with the following fields:

1. **Identity Fields**
   - `id`: Unique budget identifier (GUID)
   - `userId`: User who owns this budget (partition key)
   - `type`: Document type discriminator (value: "budget")

2. **Budget Information**
   - `name`: Budget name (e.g., "February 2026 Budget", "Q1 2026")
   - `description`: Optional description
   - `budgetPeriodType`: Period type ("monthly", "biweekly", "weekly", "custom")
   - `startDate`: Budget period start date (ISO 8601 date)
   - `endDate`: Budget period end date (ISO 8601 date)
   - `fiscalYear`: Fiscal year this budget belongs to (e.g., 2026)
   - `fiscalMonth`: Fiscal month number (1-12)

3. **Budget Status**
   - `status`: Current status ("draft", "active", "closed", "archived")
   - `isCurrent`: Boolean indicating if this is the current active budget
   - `totalIncome`: Total income allocated for this period
   - `totalAllocated`: Total amount allocated to envelopes
   - `totalSpent`: Total amount spent from all envelopes
   - `totalRemaining`: Unallocated funds (totalIncome - totalAllocated)
   - `currency`: Currency code (inherited from user preferences)

4. **Rollover Configuration**
   - `allowRollover`: Boolean to allow envelope balances to roll over
   - `previousBudgetId`: Reference to previous budget (for rollover)
   - `rolloverAmount`: Total amount rolled over from previous budget

5. **Goals and Targets**
   - `savingsGoal`: Target savings amount for this period
   - `savingsActual`: Actual savings achieved
   - `spendingLimit`: Maximum spending limit for the period (optional)

6. **Metadata**
   - `createdAt`: Timestamp (ISO 8601)
   - `createdBy`: User ID who created the record
   - `updatedAt`: Timestamp (ISO 8601)
   - `updatedBy`: User ID who last updated the record
   - `isActive`: Boolean (for soft delete)
   - `isArchived`: Boolean (for archiving old budgets)
   - `version`: Schema version number (e.g., "1.0")

### Budget Lifecycle States
1. **Draft**: Budget is being set up, not yet active
2. **Active**: Budget is current and in use
3. **Closed**: Budget period ended, but still accessible
4. **Archived**: Old budget, moved to archive

### Validation Rules
- Start date must be before end date
- Only one budget can be marked as `isCurrent` per user
- Total allocated cannot exceed total income (warning, not error)
- Budget period dates cannot overlap for the same user
- Currency must match user's default currency
- Status transitions must follow the lifecycle (draft → active → closed → archived)

### Indexing Strategy
- Primary index on `id` (automatic)
- Partition key on `userId` for user isolation
- Composite index on `userId` + `startDate` for chronological queries
- Composite index on `userId` + `isCurrent` for finding active budget
- Index on `status` for filtering
- Index on `fiscalYear` and `fiscalMonth` for fiscal reporting

## Sample Document

```json
{
  "id": "b12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "February 2026 Budget",
  "description": "Monthly budget for February",
  "budgetPeriodType": "monthly",
  "startDate": "2026-02-01",
  "endDate": "2026-02-28",
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

## Common Query Patterns

### Get Current Budget for User
```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.isCurrent = true 
  AND b.isActive = true
```

### Get All Budgets for Fiscal Year
```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.fiscalYear = @fiscalYear 
  AND b.isActive = true
ORDER BY b.startDate DESC
```

### Get Budget History (Last 12 Months)
```sql
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.startDate >= @startDate 
  AND b.isActive = true
ORDER BY b.startDate DESC
```

## Deliverables
- [ ] Budget data model schema documented with all fields
- [ ] Sample JSON document created
- [ ] Budget lifecycle states defined
- [ ] Validation rules defined
- [ ] Indexing strategy documented
- [ ] Common query patterns documented
- [ ] Data types and constraints specified
- [ ] Default values identified
- [ ] Documentation added to repository

## Acceptance Criteria
- Budget schema includes all identity, budget information, status, rollover, and metadata fields
- Sample document validates against schema
- Lifecycle states are clearly defined
- Validation ensures data integrity (no overlapping periods, single current budget)
- Indexing strategy supports efficient queries for:
  - Finding current budget
  - Listing budget history
  - Fiscal year reporting
- Query patterns are optimized for partition key usage
- Rollover mechanism is well-defined
- Schema supports budget goals and tracking

## Technical Notes
- The `isCurrent` flag should be automatically managed when activating a new budget
- Budget balances (totalAllocated, totalSpent) should be calculated from envelope and transaction data
- Consider implementing automatic budget closure when period ends
- Previous/next budget linking enables trend analysis
- Currency field should always match user's preference
- Archive old budgets after 2 years to optimize query performance

## Future Enhancements (Out of Scope)
- Shared/household budgets with multiple users
- Budget templates for recurring budget setup
- Budget comparison and analytics
- Automatic budget creation for new periods
- Budget alerts and notifications

## Dependencies
- User data model (Subtask 1)
- Cosmos DB Budgets container (Subtask 7)
- Envelope data model (Subtask 3) - for allocation calculations

## Estimated Effort
- Schema design: 3 hours
- Query pattern definition: 1 hour
- Documentation: 1 hour
- Review and validation: 1 hour
- **Total**: 6 hours
