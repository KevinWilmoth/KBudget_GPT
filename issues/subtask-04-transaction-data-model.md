# Subtask 4: Design Transaction Data Model

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Design the Transaction data model to record all financial activities including income deposits, expense payments, and transfers between envelopes. This is the core operational data that drives envelope balances and budget tracking.

## Requirements

### Data Model Schema
Define the Transaction document structure with the following fields:

1. **Identity Fields**
   - `id`: Unique transaction identifier (GUID)
   - `userId`: User who owns this transaction (partition key)
   - `type`: Document type discriminator (value: "transaction")

2. **Transaction Classification**
   - `transactionType`: Type of transaction ("income", "expense", "transfer")
   - `budgetId`: Reference to the budget this transaction belongs to
   - `envelopeId`: Reference to the envelope (null for income before allocation)
   - `fromEnvelopeId`: Source envelope for transfers (null for non-transfers)
   - `toEnvelopeId`: Destination envelope for transfers (null for non-transfers)

3. **Transaction Details**
   - `amount`: Transaction amount (always positive)
   - `currency`: Currency code (inherited from budget/user)
   - `description`: Transaction description/memo
   - `notes`: Additional notes (optional)
   - `merchantName`: Merchant/payee name (optional)
   - `category`: Transaction category/tag (optional, for reporting)

4. **Timing Information**
   - `transactionDate`: Date when transaction occurred (ISO 8601 date)
   - `transactionTime`: Time when transaction occurred (ISO 8601 datetime)
   - `postedDate`: Date when transaction was recorded in system
   - `clearedDate`: Date when transaction cleared (optional)
   - `isCleared`: Boolean indicating if transaction is cleared/settled

5. **Payment Information**
   - `paymentMethod`: Method of payment ("cash", "debit", "credit", "check", "transfer", "other")
   - `accountLast4`: Last 4 digits of account/card (optional)
   - `checkNumber`: Check number if applicable (optional)
   - `confirmationNumber`: Payment confirmation/reference number (optional)

6. **Recurring Transaction**
   - `isRecurring`: Boolean indicating if part of recurring series
   - `recurringSeriesId`: ID of recurring series (if applicable)
   - `recurringFrequency`: Frequency ("daily", "weekly", "biweekly", "monthly", "quarterly", "yearly")
   - `nextOccurrenceDate`: Next scheduled date (if recurring)

7. **Receipt and Attachments**
   - `hasReceipt`: Boolean indicating if receipt exists
   - `receiptUrl`: URL to receipt image in blob storage (optional)
   - `attachmentUrls`: Array of URLs to additional attachments (optional)

8. **Transaction State**
   - `status`: Transaction status ("pending", "cleared", "reconciled", "void")
   - `isVoid`: Boolean indicating if transaction is voided
   - `voidedAt`: Timestamp when voided (if applicable)
   - `voidedBy`: User ID who voided the transaction
   - `voidReason`: Reason for voiding (optional)

9. **Metadata**
   - `createdAt`: Timestamp (ISO 8601)
   - `createdBy`: User ID who created the record
   - `updatedAt`: Timestamp (ISO 8601)
   - `updatedBy`: User ID who last updated the record
   - `isActive`: Boolean (for soft delete)
   - `version`: Schema version number (e.g., "1.0")

### Transaction Types Explained

#### Income Transaction
- Money coming into the budget
- Posted to budget, then allocated to envelopes
- `transactionType` = "income"
- `envelopeId` can be null (unallocated income)

#### Expense Transaction
- Money spent from an envelope
- Reduces envelope balance
- `transactionType` = "expense"
- `envelopeId` is required

#### Transfer Transaction
- Money moved between envelopes
- Reduces source envelope, increases destination
- `transactionType` = "transfer"
- Both `fromEnvelopeId` and `toEnvelopeId` are required

### Validation Rules
- Amount must be > 0
- Transaction date cannot be in the future
- Transaction type must be valid ("income", "expense", "transfer")
- Expense must have valid `envelopeId`
- Transfer must have both `fromEnvelopeId` and `toEnvelopeId`
- Transfer cannot have same source and destination
- Status must follow lifecycle (pending → cleared → reconciled)
- Voided transactions cannot be modified
- Budget ID must reference an existing budget
- Currency must match budget currency

### Indexing Strategy
- Primary index on `id` (automatic)
- Partition key on `userId` for user isolation
- Composite index on `userId` + `budgetId` + `transactionDate` (DESC) for chronological queries
- Composite index on `userId` + `envelopeId` + `transactionDate` (DESC) for envelope history
- Index on `transactionType` for filtering by type
- Index on `status` for filtering cleared/pending
- Index on `merchantName` for merchant-based queries
- Index on `isRecurring` for recurring transaction management
- Index on `transactionDate` for date range queries

## Sample Documents

### Income Transaction
```json
{
  "id": "t12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "transaction",
  "transactionType": "income",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "envelopeId": "e12e8400-e29b-41d4-a716-446655440001",
  "fromEnvelopeId": null,
  "toEnvelopeId": null,
  "amount": 3000.00,
  "currency": "USD",
  "description": "Monthly Salary",
  "notes": "Paycheck from employer",
  "merchantName": "Acme Corp",
  "category": "salary",
  "transactionDate": "2026-02-01",
  "transactionTime": "2026-02-01T08:00:00Z",
  "postedDate": "2026-02-01T08:00:00Z",
  "clearedDate": "2026-02-01T08:00:00Z",
  "isCleared": true,
  "paymentMethod": "transfer",
  "accountLast4": "1234",
  "checkNumber": null,
  "confirmationNumber": "ACH20260201-001",
  "isRecurring": true,
  "recurringSeriesId": "rs12e8400-e29b-41d4-a716-446655440001",
  "recurringFrequency": "monthly",
  "nextOccurrenceDate": "2026-03-01",
  "hasReceipt": false,
  "receiptUrl": null,
  "attachmentUrls": [],
  "status": "cleared",
  "isVoid": false,
  "voidedAt": null,
  "voidedBy": null,
  "voidReason": null,
  "createdAt": "2026-02-01T08:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-01T08:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "version": "1.0"
}
```

### Expense Transaction
```json
{
  "id": "t12e8400-e29b-41d4-a716-446655440002",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "transaction",
  "transactionType": "expense",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "envelopeId": "e12e8400-e29b-41d4-a716-446655440001",
  "fromEnvelopeId": null,
  "toEnvelopeId": null,
  "amount": 127.43,
  "currency": "USD",
  "description": "Grocery shopping",
  "notes": "Weekly groceries at Whole Foods",
  "merchantName": "Whole Foods Market",
  "category": "groceries",
  "transactionDate": "2026-02-14",
  "transactionTime": "2026-02-14T18:30:00Z",
  "postedDate": "2026-02-14T18:30:00Z",
  "clearedDate": "2026-02-15T02:00:00Z",
  "isCleared": true,
  "paymentMethod": "debit",
  "accountLast4": "5678",
  "checkNumber": null,
  "confirmationNumber": "TXN20260214-12345",
  "isRecurring": false,
  "recurringSeriesId": null,
  "recurringFrequency": null,
  "nextOccurrenceDate": null,
  "hasReceipt": true,
  "receiptUrl": "https://storage.example.com/receipts/receipt-20260214-001.jpg",
  "attachmentUrls": [],
  "status": "cleared",
  "isVoid": false,
  "voidedAt": null,
  "voidedBy": null,
  "voidReason": null,
  "createdAt": "2026-02-14T18:30:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T02:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "version": "1.0"
}
```

### Transfer Transaction
```json
{
  "id": "t12e8400-e29b-41d4-a716-446655440003",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "transaction",
  "transactionType": "transfer",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "envelopeId": null,
  "fromEnvelopeId": "e12e8400-e29b-41d4-a716-446655440002",
  "toEnvelopeId": "e12e8400-e29b-41d4-a716-446655440003",
  "amount": 100.00,
  "currency": "USD",
  "description": "Transfer to savings envelope",
  "notes": "Moving excess from dining to savings",
  "merchantName": null,
  "category": "transfer",
  "transactionDate": "2026-02-15",
  "transactionTime": "2026-02-15T12:00:00Z",
  "postedDate": "2026-02-15T12:00:00Z",
  "clearedDate": "2026-02-15T12:00:00Z",
  "isCleared": true,
  "paymentMethod": "transfer",
  "accountLast4": null,
  "checkNumber": null,
  "confirmationNumber": null,
  "isRecurring": false,
  "recurringSeriesId": null,
  "recurringFrequency": null,
  "nextOccurrenceDate": null,
  "hasReceipt": false,
  "receiptUrl": null,
  "attachmentUrls": [],
  "status": "cleared",
  "isVoid": false,
  "voidedAt": null,
  "voidedBy": null,
  "voidReason": null,
  "createdAt": "2026-02-15T12:00:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T12:00:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "version": "1.0"
}
```

## Common Query Patterns

### Get Recent Transactions for Budget
```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND t.budgetId = @budgetId 
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC, t.transactionTime DESC
OFFSET 0 LIMIT 50
```

### Get Transactions for Specific Envelope
```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND t.envelopeId = @envelopeId 
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
```

### Get Transactions by Date Range
```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND t.budgetId = @budgetId 
  AND t.transactionDate >= @startDate 
  AND t.transactionDate <= @endDate 
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
```

### Get Pending Transactions
```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND t.budgetId = @budgetId 
  AND t.status = 'pending' 
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
```

### Get Transactions by Merchant
```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND CONTAINS(t.merchantName, @searchTerm, true)
  AND t.isActive = true
ORDER BY t.transactionDate DESC
```

### Calculate Envelope Balance
```sql
SELECT 
  SUM(CASE WHEN t.transactionType = 'expense' THEN -t.amount ELSE 0 END) as totalExpenses,
  SUM(CASE WHEN t.transactionType = 'transfer' AND t.fromEnvelopeId = @envelopeId THEN -t.amount ELSE 0 END) as transfersOut,
  SUM(CASE WHEN t.transactionType = 'transfer' AND t.toEnvelopeId = @envelopeId THEN t.amount ELSE 0 END) as transfersIn
FROM transactions t 
WHERE t.userId = @userId 
  AND (t.envelopeId = @envelopeId OR t.fromEnvelopeId = @envelopeId OR t.toEnvelopeId = @envelopeId)
  AND t.isActive = true
  AND t.isVoid = false
```

## Deliverables
- [ ] Transaction data model schema documented with all fields
- [ ] Sample JSON documents for each transaction type
- [ ] Transaction type definitions and rules
- [ ] Validation rules defined
- [ ] Indexing strategy documented
- [ ] Common query patterns documented
- [ ] Balance calculation queries defined
- [ ] Status lifecycle documented
- [ ] Documentation added to repository

## Acceptance Criteria
- Transaction schema includes all identity, classification, details, timing, payment, recurring, and metadata fields
- Sample documents validate against schema for all transaction types
- Transaction types (income, expense, transfer) are clearly defined
- Validation ensures data integrity for each transaction type
- Indexing strategy supports efficient queries for:
  - Recent transactions
  - Envelope transaction history
  - Date range queries
  - Merchant searches
  - Pending transactions
- Balance calculation logic is well-defined
- Receipt attachment mechanism is documented
- Recurring transaction support is defined
- Void/delete workflow preserves data integrity

## Technical Notes
- Transactions are immutable once cleared - use void for corrections
- Receipt URLs reference Azure Blob Storage with SAS tokens
- Recurring transactions create new transaction records (not references)
- Consider implementing idempotency for transaction creation
- Amount is always stored as positive; transaction type determines debit/credit
- Cleared date enables bank reconciliation
- Soft delete preserves data for auditing and reporting

## Business Rules
1. **Voiding**: Voided transactions remain in database but don't affect balances
2. **Editing**: Cleared transactions cannot be edited, only voided
3. **Transfers**: Atomic operation affecting two envelopes
4. **Income Allocation**: Income can be posted as unallocated (envelopeId = null)
5. **Reconciliation**: Cleared status enables bank reconciliation workflow

## Future Enhancements (Out of Scope)
- Automatic transaction import from banks
- Transaction categorization with machine learning
- Split transactions (single transaction across multiple envelopes)
- Scheduled future transactions
- Transaction templates
- Bulk operations

## Dependencies
- User data model (Subtask 1)
- Budget data model (Subtask 2)
- Envelope data model (Subtask 3)
- Cosmos DB Transactions container (Subtask 9)
- Azure Blob Storage for receipts

## Estimated Effort
- Schema design: 4 hours
- Sample documents: 1 hour
- Query pattern definition: 2 hours
- Documentation: 1 hour
- Review and validation: 1 hour
- **Total**: 9 hours
