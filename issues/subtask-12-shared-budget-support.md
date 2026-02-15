# Subtask 12: Design Shared Budget Support (Enhancement)

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Design and implement support for shared budgets where multiple users can collaborate on the same budget (e.g., household budgets, roommates, couples). This enhancement extends the base data model to support multi-user budget access while maintaining data isolation and security.

## Requirements

### Shared Budget Concept

A shared budget allows multiple users to:
- View the same budget, envelopes, and transactions
- Add transactions to shared envelopes
- Manage envelope allocations
- Track household spending together

**Key Principle**: Simple access model - all users with access have equal permissions (no owner/contributor/viewer roles as per requirement clarification).

### Data Model Enhancements

#### 1. Budget Entity Updates

Add shared budget fields to the Budget model:

```json
{
  "id": "budget-guid",
  "userId": "primary-owner-guid",
  "type": "budget",
  
  // NEW: Shared budget fields
  "isShared": false,
  "sharedWith": ["user-guid-2", "user-guid-3"],
  "createdByUserId": "primary-owner-guid",
  "sharedAt": "2026-02-15T10:00:00Z",
  
  // Rest of existing fields...
}
```

**New Fields:**
- `isShared` (boolean): Indicates if budget is shared with other users
- `sharedWith` (array of strings): List of user IDs who have access to this budget
- `createdByUserId` (string): Original creator of the budget (for reference)
- `sharedAt` (timestamp): When the budget was first shared

#### 2. Envelope Entity - No Changes Needed

Envelopes remain linked to `budgetId`. Since they inherit budget access, no changes needed:
- If budget is shared, all envelopes are automatically shared
- All users can view and modify envelope allocations

#### 3. Transaction Entity - Track Creator

Enhance Transaction model to track who created each transaction:

```json
{
  "id": "transaction-guid",
  "userId": "budget-owner-guid",  // Keep for partition key consistency
  "type": "transaction",
  
  // NEW: Track transaction creator
  "createdByUserId": "actual-user-who-created-guid",
  "createdByDisplayName": "John Doe",
  
  // Rest of existing fields...
}
```

**Rationale:**
- `userId` remains the budget owner for partition key consistency
- `createdByUserId` tracks who actually created the transaction
- `createdByDisplayName` avoids extra lookups for display purposes

### Query Patterns for Shared Budgets

#### Get All Budgets for a User (Personal + Shared)

```sql
-- Personal budgets
SELECT * FROM budgets b 
WHERE b.userId = @userId 
  AND b.isActive = true

UNION

-- Shared budgets where user is a participant
SELECT * FROM budgets b 
WHERE ARRAY_CONTAINS(b.sharedWith, @userId)
  AND b.isActive = true
ORDER BY b.startDate DESC
```

**Note:** This is a cross-partition query. Consider caching or denormalizing for performance.

#### Alternative: Denormalized Approach (Recommended)

Create a `BudgetAccess` document for each user that has access to a budget:

```json
{
  "id": "access-guid",
  "userId": "user-guid",
  "type": "budgetAccess",
  "budgetId": "budget-guid",
  "budgetOwnerId": "owner-guid",
  "isOwner": false,
  "accessType": "shared",
  "grantedAt": "2026-02-15T10:00:00Z",
  "grantedBy": "owner-guid"
}
```

Store these in the **Budgets** container with `userId` as partition key.

**Benefits:**
- Single partition query to get all budgets for a user
- Efficient lookups
- Easy to revoke access (delete document)

#### Get All Participants for a Shared Budget

```sql
SELECT VALUE b.sharedWith
FROM budgets b 
WHERE b.id = @budgetId 
  AND b.userId = @budgetOwnerId
```

Or if using denormalized approach:

```sql
SELECT * FROM budgets b 
WHERE b.budgetId = @budgetId 
  AND b.type = "budgetAccess"
```

**Note:** With optimized partition keys (Subtask 13), Budgets container uses `/id` as partition key, so access checking becomes:

```sql
SELECT * FROM budgets b 
WHERE b.id = @budgetId 
  AND (b.userId = @requestingUserId OR ARRAY_CONTAINS(b.sharedWith, @requestingUserId))
```

#### Check User Access to Budget

```sql
SELECT * FROM budgets b 
WHERE b.id = @budgetId 
  AND (b.userId = @userId OR ARRAY_CONTAINS(b.sharedWith, @userId))
```

### Implementation Approaches

Two approaches to consider:

#### Approach 1: Embedded Array (Simpler)
- Store `sharedWith` array directly in Budget document
- Pros: Simpler, fewer queries, atomic updates
- Cons: Cross-partition queries for "get all budgets", array size limits (100 users max)

#### Approach 2: Denormalized Access Documents (Scalable)
- Create separate `budgetAccess` documents
- Pros: Efficient single-partition queries, unlimited participants
- Cons: More documents, eventual consistency issues, more complex

**Recommendation**: Use **Approach 1 (Embedded Array)** for initial implementation:
- Simpler to implement
- Sufficient for typical household budgets (2-10 users)
- Can migrate to Approach 2 later if needed

### Sharing Workflow

#### Share a Budget
1. Budget owner initiates share
2. Add user IDs to `sharedWith` array
3. Set `isShared = true`
4. Update `sharedAt` timestamp
5. Optionally send notification to invited users

```javascript
// Pseudo-code
async function shareBudget(budgetId, userIdsToShare) {
  const budget = await getBudgetById(budgetId);
  
  budget.isShared = true;
  budget.sharedWith = [...new Set([...budget.sharedWith, ...userIdsToShare])];
  budget.sharedAt = budget.sharedAt || new Date().toISOString();
  
  await updateBudget(budget);
}
```

#### Unshare / Remove Access
1. Remove user ID from `sharedWith` array
2. If array becomes empty, set `isShared = false`

```javascript
async function removeAccess(budgetId, userIdToRemove) {
  const budget = await getBudgetById(budgetId);
  
  budget.sharedWith = budget.sharedWith.filter(id => id !== userIdToRemove);
  budget.isShared = budget.sharedWith.length > 0;
  
  await updateBudget(budget);
}
```

### Security Considerations

#### Access Control
- Always validate user has access before returning budget data
- Check both `userId` (owner) and `sharedWith` array
- Apply same access control to envelopes and transactions

#### Data Isolation
- Personal budgets remain isolated (only owner can see)
- Shared budgets visible only to owner and `sharedWith` users
- Partition key remains `/userId` for performance

#### API Authorization
```javascript
async function checkBudgetAccess(budgetId, requestingUserId) {
  const budget = await getBudgetById(budgetId);
  
  if (!budget) {
    throw new Error('Budget not found');
  }
  
  const hasAccess = 
    budget.userId === requestingUserId || 
    (budget.sharedWith && budget.sharedWith.includes(requestingUserId));
  
  if (!hasAccess) {
    throw new Error('Access denied');
  }
  
  return budget;
}
```

### Indexing Updates

No indexing changes needed for Budgets container if using embedded array approach. The existing indexes will work fine.

If using denormalized approach, add composite index:

```json
{
  "compositeIndexes": [
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/type", "order": "ascending"},
      {"path": "/budgetId", "order": "ascending"}
    ]
  ]
}
```

### Migration Strategy

For existing budgets:
1. Add new fields with default values:
   - `isShared = false`
   - `sharedWith = []`
   - `createdByUserId = userId`
   
2. No data migration needed for existing records (fields can be null/undefined)

3. Application code should handle missing fields gracefully:
```javascript
const isShared = budget.isShared || false;
const sharedWith = budget.sharedWith || [];
```

### User Experience Scenarios

#### Scenario 1: Couple Sharing Household Budget
- User A creates "February Household Budget"
- User A shares with User B
- Both can add expenses, view envelopes, transfer funds
- Both see all transactions with creator name

#### Scenario 2: Roommates Splitting Expenses
- User A creates "Apartment Expenses"
- User A shares with Users B, C, D (4 roommates)
- All can track shared expenses (utilities, groceries, rent)
- Each can see who added which transaction

#### Scenario 3: Personal + Shared Budgets
- User A has personal budget "My Budget"
- User A also participates in shared "Household Budget" (owner: User B)
- Dashboard shows both budgets
- Clear indication which budgets are shared

### UI/UX Considerations

#### Budget List Display
```
My Budgets:
  📊 February 2026 Personal Budget
  🏠 Household Budget (Shared with Jane)
  
Shared With Me:
  🏠 Family Budget (Owner: John)
```

#### Transaction Display
```
Groceries - $127.43
  Added by: Jane Doe
  Date: Feb 14, 2026
```

#### Sharing Interface
```
Share Budget
  Enter email: ________________
  [Invite]
  
Currently shared with:
  ✉️ john@example.com [Remove]
  ✉️ jane@example.com [Remove]
```

## Deliverables
- [ ] Shared budget data model enhancement designed
- [ ] Budget entity schema updated with shared fields
- [ ] Transaction entity schema updated to track creator
- [ ] Query patterns documented for shared budgets
- [ ] Access control logic defined
- [ ] Sharing workflow documented
- [ ] Security considerations documented
- [ ] Migration strategy defined
- [ ] User scenarios documented
- [ ] UI/UX guidelines provided
- [ ] Sample code examples created
- [ ] Documentation added to main data model docs

## Sample Document: Shared Budget

```json
{
  "id": "b12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "Household Budget - February 2026",
  "description": "Shared household expenses",
  "budgetPeriodType": "monthly",
  "startDate": "2026-02-01",
  "endDate": "2026-02-28",
  "fiscalYear": 2026,
  "fiscalMonth": 2,
  "status": "active",
  "isCurrent": true,
  
  // Shared budget specific fields
  "isShared": true,
  "sharedWith": [
    "660e8400-e29b-41d4-a716-446655440001",
    "770e8400-e29b-41d4-a716-446655440002"
  ],
  "createdByUserId": "550e8400-e29b-41d4-a716-446655440000",
  "sharedAt": "2026-02-01T10:00:00Z",
  
  "totalIncome": 8000.00,
  "totalAllocated": 7500.00,
  "totalSpent": 3200.00,
  "totalRemaining": 500.00,
  "currency": "USD",
  "allowRollover": true,
  
  "createdAt": "2026-02-01T10:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T15:30:00Z",
  "updatedBy": "660e8400-e29b-41d4-a716-446655440001",
  "isActive": true,
  "version": "1.0"
}
```

## Sample Document: Transaction in Shared Budget

```json
{
  "id": "t12e8400-e29b-41d4-a716-446655440002",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "transaction",
  "transactionType": "expense",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "envelopeId": "e12e8400-e29b-41d4-a716-446655440001",
  
  // Tracks who created this transaction
  "createdByUserId": "660e8400-e29b-41d4-a716-446655440001",
  "createdByDisplayName": "Jane Doe",
  
  "amount": 127.43,
  "currency": "USD",
  "description": "Grocery shopping",
  "merchantName": "Whole Foods Market",
  "transactionDate": "2026-02-14",
  "status": "cleared",
  
  "createdAt": "2026-02-14T18:30:00Z",
  "createdBy": "660e8400-e29b-41d4-a716-446655440001",
  "isActive": true,
  "version": "1.0"
}
```

## Acceptance Criteria
- Shared budget data model supports multiple users accessing same budget
- Access control logic is well-defined and secure
- Query patterns efficiently retrieve shared budgets
- Transaction creator tracking works correctly
- Sharing workflow is documented with examples
- Security considerations are thoroughly documented
- Migration strategy allows smooth upgrade from non-shared to shared budgets
- User scenarios cover common use cases
- Documentation is clear and comprehensive
- Sample code examples work correctly
- No breaking changes to existing data model (backward compatible)

## Testing Checklist
- [ ] Can create a shared budget
- [ ] Can add users to `sharedWith` array
- [ ] Can remove users from shared budget
- [ ] Query returns all budgets (personal + shared) for a user
- [ ] Access control prevents unauthorized access
- [ ] Transaction creator information stored correctly
- [ ] Envelopes automatically shared with budget
- [ ] Can have both personal and shared budgets simultaneously
- [ ] Partition key strategy still works with shared budgets
- [ ] No performance degradation with shared budgets
- [ ] Migration from non-shared to shared works
- [ ] Unsharing budget works correctly

## Technical Notes
- Shared budgets still use original owner's `userId` as partition key
- This means all queries for a shared budget go to one partition
- For very large shared budgets (e.g., organization-wide), consider different strategy
- Array size limit in Cosmos DB is 2MB, supports hundreds of user IDs
- Consider caching "budgets for user" query result
- Use change feed to invalidate cache when budget sharing changes

## Performance Implications

### Positive
- Shared budgets in same partition as budget (efficient queries using `/id` partition key)
- No additional containers needed
- Simple access control (array membership check)

### Negative
- "Get all budgets for user" requires cross-partition query (mitigate with caching)
- Consider denormalization if performance becomes issue
- Cache aggressively to minimize queries

**Note:** With the optimized partition key strategy (Subtask 13), Budgets container uses `/id` as partition key, not `/userId`. This means the budget document is in its own partition, making point reads by budgetId extremely efficient (1 RU).

### Optimization
- Cache user's budget list (invalidate on share/unshare)
- Use change feed to track budget sharing changes
- Consider materialized view for "budgets per user"

## Future Enhancements (Out of Scope)
- Invite via email with acceptance workflow
- Audit log of who made which changes
- Granular permissions (view-only, edit-only)
- Budget activity feed
- Notifications for budget changes
- Conflict resolution for simultaneous edits

## Dependencies
- Subtask 2: Budget Data Model (update)
- Subtask 4: Transaction Data Model (update)
- Subtask 7: Budgets Container Infrastructure
- Subtask 11: Data Model Documentation (update)

## Related Files
- `issues/subtask-02-budget-data-model.md` (update)
- `issues/subtask-04-transaction-data-model.md` (update)
- `docs/SHARED-BUDGET-GUIDE.md` (new, from Subtask 11)
- `docs/DATA-MODEL-DOCUMENTATION.md` (update)

## Estimated Effort
- Shared budget model design: 3 hours
- Query pattern design: 2 hours
- Access control logic: 2 hours
- Documentation: 2 hours
- Code examples: 1 hour
- Review and validation: 1 hour
- **Total**: 11 hours
