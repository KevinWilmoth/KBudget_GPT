# Subtask 3: Design Envelope Data Model

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Design the Envelope data model to represent budget categories (envelopes) where users allocate funds and track spending. Each envelope represents a specific spending category with allocated amounts and current balances.

## Requirements

### Data Model Schema
Define the Envelope document structure with the following fields:

1. **Identity Fields**
   - `id`: Unique envelope identifier (GUID)
   - `userId`: User who owns this envelope (partition key)
   - `type`: Document type discriminator (value: "envelope")

2. **Envelope Information**
   - `budgetId`: Reference to the budget this envelope belongs to
   - `name`: Envelope name (e.g., "Groceries", "Rent", "Entertainment")
   - `description`: Optional description
   - `categoryType`: Category classification ("essential", "discretionary", "savings", "debt")
   - `icon`: Icon identifier for UI display (e.g., "grocery", "home", "entertainment")
   - `color`: Hex color code for UI display (e.g., "#4CAF50")
   - `sortOrder`: Display order (integer, lower numbers first)

3. **Budget Allocation**
   - `allocatedAmount`: Amount allocated for this budget period
   - `currentBalance`: Current remaining balance
   - `spentAmount`: Total spent from this envelope
   - `currency`: Currency code (inherited from budget/user)

4. **Rollover Settings**
   - `allowRollover`: Boolean to allow balance rollover to next period
   - `rolloverAmount`: Amount rolled over from previous period
   - `previousEnvelopeId`: Reference to envelope from previous budget period

5. **Goals and Limits**
   - `targetAmount`: Target/goal amount for this envelope (optional)
   - `warningThreshold`: Percentage to trigger warning (e.g., 80)
   - `isOverspendAllowed`: Boolean to allow negative balances
   - `maxOverspendAmount`: Maximum allowed negative balance (optional)

6. **Envelope State**
   - `status`: Status ("active", "paused", "closed")
   - `isPaused`: Boolean indicating if envelope is temporarily inactive
   - `pausedAt`: Timestamp when paused (if applicable)
   - `isRecurring`: Boolean indicating if this envelope repeats each period

7. **Metadata**
   - `createdAt`: Timestamp (ISO 8601)
   - `createdBy`: User ID who created the record
   - `updatedAt`: Timestamp (ISO 8601)
   - `updatedBy`: User ID who last updated the record
   - `isActive`: Boolean (for soft delete)
   - `lastTransactionAt`: Timestamp of last transaction
   - `version`: Schema version number (e.g., "1.0")

### Envelope Categories
Standard category types for organization:
- **Essential**: Rent, Utilities, Insurance, Groceries, Transportation, Healthcare
- **Discretionary**: Entertainment, Dining Out, Hobbies, Subscriptions, Shopping
- **Savings**: Emergency Fund, Vacation, Down Payment, Retirement, Education
- **Debt**: Credit Card, Student Loan, Car Loan, Mortgage

### Validation Rules
- Allocated amount must be >= 0
- Current balance = allocated amount + rollover - spent amount
- Warning threshold must be between 0-100
- Budget ID must reference an existing, active budget
- Envelope names must be unique within a budget period
- Category type must be one of the predefined types
- Color must be valid hex color code
- Sort order must be unique within a budget

### Indexing Strategy
- Primary index on `id` (automatic)
- Partition key on `userId` for user isolation
- Composite index on `userId` + `budgetId` for budget-specific queries
- Composite index on `userId` + `budgetId` + `sortOrder` for ordered display
- Index on `categoryType` for category-based filtering
- Index on `status` and `isActive` for active envelope queries
- Index on `isRecurring` for template operations

## Sample Document

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

## Common Query Patterns

### Get All Envelopes for Current Budget
```sql
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

### Get Envelopes by Category
```sql
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.categoryType = @categoryType 
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

### Get Low Balance Envelopes (Under Threshold)
```sql
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.budgetId = @budgetId 
  AND e.currentBalance / e.allocatedAmount * 100 < e.warningThreshold
  AND e.isActive = true
  AND e.status = 'active'
```

### Get Recurring Envelopes (for template)
```sql
SELECT * FROM envelopes e 
WHERE e.userId = @userId 
  AND e.isRecurring = true 
  AND e.isActive = true
ORDER BY e.sortOrder ASC
```

## Balance Calculation Logic
```javascript
currentBalance = allocatedAmount + rolloverAmount - spentAmount
```

After each transaction:
1. Update `spentAmount` (increase for expenses, decrease for refunds)
2. Recalculate `currentBalance`
3. Check against `warningThreshold` for alerts
4. Update `lastTransactionAt` timestamp

## Deliverables
- [ ] Envelope data model schema documented with all fields
- [ ] Sample JSON documents for different category types
- [ ] Category type classifications defined
- [ ] Validation rules defined
- [ ] Indexing strategy documented
- [ ] Common query patterns documented
- [ ] Balance calculation logic defined
- [ ] Icon and color standards documented
- [ ] Documentation added to repository

## Acceptance Criteria
- Envelope schema includes all identity, information, allocation, rollover, goals, and metadata fields
- Sample documents validate against schema for each category type
- Category types cover common budgeting needs
- Validation ensures data integrity
- Indexing strategy supports efficient queries for:
  - Displaying all envelopes in a budget
  - Filtering by category type
  - Finding low-balance envelopes
  - Recurring envelope templates
- Balance calculation logic is clearly defined
- Rollover mechanism is well-documented
- Support for envelope reordering (sortOrder)
- Icon and color system enables attractive UI

## Technical Notes
- Current balance should be calculated in real-time from transactions or cached and updated on each transaction
- Consider implementing optimistic concurrency control for balance updates
- The `isRecurring` flag enables envelope templates for next period creation
- Pausing an envelope prevents new transactions but preserves balance
- Soft delete preserves historical data for reporting
- Icons and colors should have predefined options for consistency
- Sort order enables drag-and-drop reordering in UI

## Business Rules
1. **Overspending**: By default, envelopes cannot go negative unless `isOverspendAllowed = true`
2. **Rollover**: If enabled, positive balances carry to next period's envelope
3. **Pausing**: Paused envelopes retain balance but don't accept new transactions
4. **Deletion**: Soft delete only; envelope remains for historical transaction integrity
5. **Recurring**: Recurring envelopes are automatically created in new budget periods

## Future Enhancements (Out of Scope)
- Envelope groups/sub-categories
- Percentage-based allocation (auto-calculate from income)
- Envelope transfer history
- Funding priority/order
- Shared envelopes for household budgets

## Dependencies
- User data model (Subtask 1)
- Budget data model (Subtask 2)
- Transaction data model (Subtask 4) - for balance calculations
- Cosmos DB Envelopes container (Subtask 8)

## Estimated Effort
- Schema design: 3 hours
- Category definitions: 1 hour
- Query pattern definition: 1 hour
- Documentation: 1 hour
- Review and validation: 1 hour
- **Total**: 7 hours
