# Transaction Data Model Documentation

**Version:** 1.0  
**Last Updated:** 2026-02-15  
**Status:** Active

## Overview

The Transaction data model records all financial activities in the KBudget envelope budgeting system. It captures income deposits, expense payments, and transfers between envelopes. Transactions are the core operational data that drives envelope balances and budget tracking, enabling users to monitor their actual spending against budgeted amounts.

## Table of Contents

- [Schema Definition](#schema-definition)
- [Field Specifications](#field-specifications)
- [Transaction Types](#transaction-types)
- [Validation Rules](#validation-rules)
- [Default Values](#default-values)
- [Indexing Strategy](#indexing-strategy)
- [Common Query Patterns](#common-query-patterns)
- [Balance Calculations](#balance-calculations)
- [Sample Documents](#sample-documents)
- [Schema Evolution](#schema-evolution)
- [Business Logic](#business-logic)

## Schema Definition

### Document Structure

```json
{
  "id": "string (GUID)",
  "userId": "string (GUID)",
  "type": "transaction",
  "transactionType": "string",
  "budgetId": "string (GUID)",
  "envelopeId": "string? (GUID)",
  "fromEnvelopeId": "string? (GUID)",
  "toEnvelopeId": "string? (GUID)",
  "amount": "number",
  "currency": "string",
  "description": "string",
  "notes": "string?",
  "merchantName": "string?",
  "category": "string?",
  "transactionDate": "string (ISO 8601 date)",
  "transactionTime": "string (ISO 8601 datetime)",
  "postedDate": "string (ISO 8601 datetime)",
  "clearedDate": "string? (ISO 8601 datetime)",
  "isCleared": "boolean",
  "paymentMethod": "string",
  "accountLast4": "string?",
  "checkNumber": "string?",
  "confirmationNumber": "string?",
  "isRecurring": "boolean",
  "recurringSeriesId": "string? (GUID)",
  "recurringFrequency": "string?",
  "nextOccurrenceDate": "string? (ISO 8601 date)",
  "hasReceipt": "boolean",
  "receiptUrl": "string? (URL)",
  "attachmentUrls": "string[]",
  "status": "string",
  "isVoid": "boolean",
  "voidedAt": "string? (ISO 8601 datetime)",
  "voidedBy": "string? (GUID)",
  "voidReason": "string?",
  "createdAt": "string (ISO 8601 datetime)",
  "createdBy": "string (GUID)",
  "updatedAt": "string (ISO 8601 datetime)",
  "updatedBy": "string (GUID)",
  "isActive": "boolean",
  "version": "string"
}
```

## Field Specifications

### Identity Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (GUID) | Yes | Unique transaction identifier. Primary key in Cosmos DB. |
| `userId` | string (GUID) | Yes | User who owns this transaction. Partition key for user isolation. |
| `type` | string | Yes | Document type discriminator. Always set to "transaction". |

### Transaction Classification

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `transactionType` | string | Yes | Type of transaction: "income", "expense", or "transfer". |
| `budgetId` | string (GUID) | Yes | Reference to the budget this transaction belongs to. Must reference an existing active budget. |
| `envelopeId` | string (GUID) | Conditional | Reference to the envelope. Required for expenses, optional for income (can be null for unallocated income), null for transfers. |
| `fromEnvelopeId` | string (GUID) | Conditional | Source envelope for transfers. Required when `transactionType` is "transfer", null otherwise. |
| `toEnvelopeId` | string (GUID) | Conditional | Destination envelope for transfers. Required when `transactionType` is "transfer", null otherwise. |

### Transaction Details

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `amount` | number | Yes | - | Transaction amount. Always stored as positive value; transaction type determines debit/credit. Must be > 0. |
| `currency` | string | Yes | "USD" | ISO 4217 currency code (e.g., "USD", "EUR", "GBP"). Inherited from budget/user preference. |
| `description` | string | Yes | - | Transaction description/memo. Brief explanation of the transaction. |
| `notes` | string | No | null | Additional notes providing more context. Optional detailed information. |
| `merchantName` | string | No | null | Merchant or payee name (e.g., "Whole Foods Market", "Acme Corp"). |
| `category` | string | No | null | Transaction category or tag for reporting (e.g., "groceries", "salary", "entertainment"). |

### Timing Information

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `transactionDate` | string (ISO 8601 date) | Yes | - | Date when transaction occurred (YYYY-MM-DD format). Cannot be in the future. |
| `transactionTime` | string (ISO 8601 datetime) | Yes | - | Date and time when transaction occurred. Full timestamp with timezone. |
| `postedDate` | string (ISO 8601 datetime) | Yes | - | Date and time when transaction was recorded in the system. |
| `clearedDate` | string (ISO 8601 datetime) | No | null | Date and time when transaction cleared/settled. Used for bank reconciliation. |
| `isCleared` | boolean | Yes | false | Indicates if transaction is cleared/settled. |

### Payment Information

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `paymentMethod` | string | Yes | "other" | Method of payment: "cash", "debit", "credit", "check", "transfer", or "other". |
| `accountLast4` | string | No | null | Last 4 digits of account or card number for reference. |
| `checkNumber` | string | No | null | Check number if payment method is "check". |
| `confirmationNumber` | string | No | null | Payment confirmation or reference number (e.g., ACH confirmation, transaction ID). |

### Recurring Transaction

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `isRecurring` | boolean | Yes | false | Indicates if transaction is part of a recurring series. |
| `recurringSeriesId` | string (GUID) | No | null | ID of the recurring series this transaction belongs to. Required if `isRecurring` is true. |
| `recurringFrequency` | string | No | null | Frequency of recurrence: "daily", "weekly", "biweekly", "monthly", "quarterly", or "yearly". Required if `isRecurring` is true. |
| `nextOccurrenceDate` | string (ISO 8601 date) | No | null | Next scheduled date for recurring transaction. Applicable for recurring series. |

### Receipt and Attachments

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `hasReceipt` | boolean | Yes | false | Indicates if a receipt exists for this transaction. |
| `receiptUrl` | string (URL) | No | null | URL to receipt image in Azure Blob Storage. Uses SAS tokens for secure access. |
| `attachmentUrls` | array of strings | Yes | [] | Array of URLs to additional attachments in Azure Blob Storage. |

### Transaction State

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `status` | string | Yes | "pending" | Transaction status: "pending", "cleared", "reconciled", or "void". Follows lifecycle progression. |
| `isVoid` | boolean | Yes | false | Indicates if transaction has been voided. Voided transactions don't affect balances but remain for audit trail. |
| `voidedAt` | string (ISO 8601 datetime) | No | null | Timestamp when transaction was voided. Required if `isVoid` is true. |
| `voidedBy` | string (GUID) | No | null | User ID who voided the transaction. Required if `isVoid` is true. |
| `voidReason` | string | No | null | Reason for voiding the transaction. Optional explanation for audit purposes. |

### Metadata

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `createdAt` | string (ISO 8601 datetime) | Yes | - | Timestamp when transaction was created. System-generated. |
| `createdBy` | string (GUID) | Yes | - | User ID who created the transaction. |
| `updatedAt` | string (ISO 8601 datetime) | Yes | - | Timestamp when transaction was last updated. System-maintained. |
| `updatedBy` | string (GUID) | Yes | - | User ID who last updated the transaction. |
| `isActive` | boolean | Yes | true | Soft delete flag. False indicates the transaction is deleted but preserved for audit. |
| `version` | string | Yes | "1.0" | Schema version number for future migrations. |

## Transaction Types

### Income Transaction

Income transactions represent money coming into the budget from external sources (salary, freelance income, gifts, etc.).

**Characteristics:**
- `transactionType` = "income"
- `envelopeId` can be null (for unallocated income) or reference a specific envelope (for directly allocated income)
- `fromEnvelopeId` and `toEnvelopeId` are null
- Amount is added to the budget's available funds
- If `envelopeId` is provided, the amount is directly allocated to that envelope
- If `envelopeId` is null, the income is unallocated and can be distributed to envelopes later

**Use Cases:**
- Monthly salary deposits
- Freelance income
- Tax refunds
- Gifts or bonuses

### Expense Transaction

Expense transactions represent money spent from an envelope for goods or services.

**Characteristics:**
- `transactionType` = "expense"
- `envelopeId` is required (must reference a valid envelope)
- `fromEnvelopeId` and `toEnvelopeId` are null
- Amount is deducted from the envelope's balance
- Reduces available funds in the specified envelope
- Includes merchant and payment details

**Use Cases:**
- Grocery purchases
- Bill payments
- Entertainment spending
- Any purchase from a budget category

### Transfer Transaction

Transfer transactions move funds between envelopes within the same budget.

**Characteristics:**
- `transactionType` = "transfer"
- `envelopeId` is null
- Both `fromEnvelopeId` and `toEnvelopeId` are required
- `fromEnvelopeId` and `toEnvelopeId` must be different
- Amount is deducted from source envelope and added to destination envelope
- Operation must be atomic (both updates succeed or both fail)

**Use Cases:**
- Moving excess funds from dining to savings
- Reallocating budget between categories
- Consolidating funds for a large purchase

## Validation Rules

### General Validation

1. **Amount Validation**
   - Amount must be > 0
   - Amount must be a valid number with at most 2 decimal places
   - Amount cannot be negative

2. **Date Validation**
   - Transaction date cannot be in the future
   - Transaction date must be a valid ISO 8601 date
   - Transaction time must be a valid ISO 8601 datetime
   - If provided, cleared date must be >= posted date

3. **Transaction Type Validation**
   - Transaction type must be one of: "income", "expense", "transfer"
   - Transaction type is immutable once created

4. **Currency Validation**
   - Currency must be a valid ISO 4217 code
   - Currency must match the budget's currency

### Type-Specific Validation

#### Income Transactions
- `envelopeId` is optional
- If `envelopeId` is provided, it must reference an existing active envelope
- `fromEnvelopeId` and `toEnvelopeId` must be null

#### Expense Transactions
- `envelopeId` is required
- `envelopeId` must reference an existing active envelope
- Envelope must have sufficient balance (unless overspend is allowed)
- `fromEnvelopeId` and `toEnvelopeId` must be null

#### Transfer Transactions
- Both `fromEnvelopeId` and `toEnvelopeId` are required
- Both must reference existing active envelopes
- `fromEnvelopeId` and `toEnvelopeId` cannot be the same
- Source envelope must have sufficient balance
- `envelopeId` must be null

### Status Lifecycle Validation

1. **Status Transitions**
   - Pending → Cleared → Reconciled (allowed)
   - Any status → Void (allowed)
   - Cannot transition from Void to any other status
   - Cannot transition backward (e.g., Cleared → Pending)

2. **Edit Restrictions**
   - Cleared transactions cannot be edited (only voided)
   - Reconciled transactions cannot be edited (only voided)
   - Voided transactions cannot be modified at all

### Recurring Transaction Validation
- If `isRecurring` is true, `recurringSeriesId` is required
- If `isRecurring` is true, `recurringFrequency` is required
- `recurringFrequency` must be one of: "daily", "weekly", "biweekly", "monthly", "quarterly", "yearly"

### Reference Integrity
- `budgetId` must reference an existing active budget
- Budget must belong to the user specified in `userId`
- All envelope references must belong to the same budget

## Default Values

| Field | Default Value | Notes |
|-------|---------------|-------|
| `currency` | "USD" | Inherited from budget/user preference |
| `notes` | null | Optional field |
| `merchantName` | null | Optional field |
| `category` | null | Optional field |
| `isCleared` | false | Set to true when transaction clears |
| `clearedDate` | null | Set when transaction clears |
| `paymentMethod` | "other" | Should be specified for better tracking |
| `accountLast4` | null | Optional for privacy |
| `checkNumber` | null | Only applicable for checks |
| `confirmationNumber` | null | Optional reference |
| `isRecurring` | false | Most transactions are one-time |
| `recurringSeriesId` | null | Only for recurring transactions |
| `recurringFrequency` | null | Only for recurring transactions |
| `nextOccurrenceDate` | null | Only for recurring transactions |
| `hasReceipt` | false | Set to true when receipt is attached |
| `receiptUrl` | null | Set when receipt is uploaded |
| `attachmentUrls` | [] | Empty array by default |
| `status` | "pending" | Initial status for new transactions |
| `isVoid` | false | Transactions start as non-voided |
| `voidedAt` | null | Only set when voided |
| `voidedBy` | null | Only set when voided |
| `voidReason` | null | Optional explanation |
| `isActive` | true | Active by default |
| `version` | "1.0" | Current schema version |

## Indexing Strategy

### Primary Indexes

1. **Primary Index**
   - Field: `id`
   - Type: Unique
   - Purpose: Primary key lookup
   - Auto-created by Cosmos DB

2. **Partition Key**
   - Field: `userId`
   - Purpose: User isolation and query performance
   - All queries should include userId for optimal performance

### Composite Indexes

1. **Budget Timeline Query**
   ```json
   {
     "path": "/userId",
     "path": "/budgetId",
     "path": "/transactionDate DESC"
   }
   ```
   - Purpose: Retrieve transactions for a budget in chronological order
   - Supports: Budget transaction history, date range queries

2. **Envelope History Query**
   ```json
   {
     "path": "/userId",
     "path": "/envelopeId",
     "path": "/transactionDate DESC"
   }
   ```
   - Purpose: Retrieve transactions for a specific envelope
   - Supports: Envelope transaction history, balance calculations

3. **Transfer Tracking**
   ```json
   {
     "path": "/userId",
     "path": "/fromEnvelopeId",
     "path": "/transactionDate DESC"
   }
   ```
   ```json
   {
     "path": "/userId",
     "path": "/toEnvelopeId",
     "path": "/transactionDate DESC"
   }
   ```
   - Purpose: Track transfers in and out of envelopes
   - Supports: Transfer history, balance calculations

### Single-Field Indexes

1. **Transaction Type Filter**
   - Field: `transactionType`
   - Purpose: Filter by transaction type (income, expense, transfer)

2. **Status Filter**
   - Field: `status`
   - Purpose: Filter by transaction status (pending, cleared, reconciled, void)

3. **Merchant Search**
   - Field: `merchantName`
   - Purpose: Search transactions by merchant name
   - Consider case-insensitive search

4. **Recurring Management**
   - Field: `isRecurring`
   - Purpose: Filter recurring transactions

5. **Date Range Queries**
   - Field: `transactionDate`
   - Purpose: Support date range filtering

6. **Active Records**
   - Field: `isActive`
   - Purpose: Filter out soft-deleted transactions

### Index Policy Recommendations

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
      "path": "/notes/?",
      "path": "/voidReason/?",
      "path": "/attachmentUrls/*"
    }
  ],
  "compositeIndexes": [
    [
      { "path": "/userId", "order": "ascending" },
      { "path": "/budgetId", "order": "ascending" },
      { "path": "/transactionDate", "order": "descending" }
    ],
    [
      { "path": "/userId", "order": "ascending" },
      { "path": "/envelopeId", "order": "ascending" },
      { "path": "/transactionDate", "order": "descending" }
    ],
    [
      { "path": "/userId", "order": "ascending" },
      { "path": "/fromEnvelopeId", "order": "ascending" },
      { "path": "/transactionDate", "order": "descending" }
    ],
    [
      { "path": "/userId", "order": "ascending" },
      { "path": "/toEnvelopeId", "order": "ascending" },
      { "path": "/transactionDate", "order": "descending" }
    ]
  ]
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

**Use Case:** Display recent activity in budget dashboard

**Performance:** Optimized by composite index on userId + budgetId + transactionDate

### Get Transactions for Specific Envelope

```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND t.envelopeId = @envelopeId 
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
```

**Use Case:** Show spending history for an envelope

**Performance:** Optimized by composite index on userId + envelopeId + transactionDate

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

**Use Case:** Generate reports for specific time periods

**Performance:** Uses composite index with additional date filter

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

**Use Case:** Show uncleared transactions for reconciliation

**Performance:** Uses composite index with status filter

### Get Transactions by Merchant

```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND CONTAINS(t.merchantName, @searchTerm, true)
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
```

**Use Case:** Find all transactions with a specific merchant

**Performance:** Uses merchantName index with text search

### Get Recurring Transactions

```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND t.isRecurring = true
  AND t.recurringSeriesId = @seriesId
  AND t.isActive = true
ORDER BY t.transactionDate DESC
```

**Use Case:** View all transactions in a recurring series

**Performance:** Uses isRecurring and recurringSeriesId indexes

### Get Transfers Between Envelopes

```sql
SELECT * FROM transactions t 
WHERE t.userId = @userId 
  AND t.transactionType = 'transfer'
  AND (t.fromEnvelopeId = @envelopeId OR t.toEnvelopeId = @envelopeId)
  AND t.isActive = true
  AND t.isVoid = false
ORDER BY t.transactionDate DESC
```

**Use Case:** Track fund movements for an envelope

**Performance:** Uses composite indexes on fromEnvelopeId and toEnvelopeId

## Balance Calculations

### Envelope Balance Calculation

To calculate the current balance of an envelope, consider all transactions that affect it:

```sql
SELECT 
  SUM(CASE 
    WHEN t.transactionType = 'income' AND t.envelopeId = @envelopeId 
    THEN t.amount 
    ELSE 0 
  END) as totalIncome,
  SUM(CASE 
    WHEN t.transactionType = 'expense' AND t.envelopeId = @envelopeId 
    THEN t.amount 
    ELSE 0 
  END) as totalExpenses,
  SUM(CASE 
    WHEN t.transactionType = 'transfer' AND t.fromEnvelopeId = @envelopeId 
    THEN t.amount 
    ELSE 0 
  END) as transfersOut,
  SUM(CASE 
    WHEN t.transactionType = 'transfer' AND t.toEnvelopeId = @envelopeId 
    THEN t.amount 
    ELSE 0 
  END) as transfersIn
FROM transactions t 
WHERE t.userId = @userId 
  AND (
    t.envelopeId = @envelopeId 
    OR t.fromEnvelopeId = @envelopeId 
    OR t.toEnvelopeId = @envelopeId
  )
  AND t.isActive = true
  AND t.isVoid = false
```

**Balance Formula:**
```
Current Balance = Allocated Amount + Rollover Amount + Total Income - Total Expenses - Transfers Out + Transfers In
```

### Budget Available Funds Calculation

Calculate total available funds across all envelopes:

```sql
SELECT 
  SUM(CASE 
    WHEN t.transactionType = 'income' 
    THEN t.amount 
    ELSE 0 
  END) as totalIncome,
  SUM(CASE 
    WHEN t.transactionType = 'expense' 
    THEN t.amount 
    ELSE 0 
  END) as totalExpenses
FROM transactions t 
WHERE t.userId = @userId 
  AND t.budgetId = @budgetId
  AND t.isActive = true
  AND t.isVoid = false
```

**Note:** Transfers don't affect total budget balance (they move money within the budget).

### Spending by Category

Analyze spending patterns by category:

```sql
SELECT 
  t.category,
  COUNT(*) as transactionCount,
  SUM(t.amount) as totalSpent
FROM transactions t 
WHERE t.userId = @userId 
  AND t.budgetId = @budgetId
  AND t.transactionType = 'expense'
  AND t.transactionDate >= @startDate 
  AND t.transactionDate <= @endDate
  AND t.isActive = true
  AND t.isVoid = false
GROUP BY t.category
ORDER BY totalSpent DESC
```

## Sample Documents

### Income Transaction (Monthly Salary)

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

### Expense Transaction (Grocery Shopping)

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

### Transfer Transaction (Between Envelopes)

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

See the [samples](./samples/) directory for additional transaction examples.

## Schema Evolution

### Version 1.0 (Current)

**Released:** 2026-02-15

**Features:**
- Complete transaction tracking for income, expenses, and transfers
- Support for recurring transactions
- Receipt and attachment management
- Transaction status lifecycle (pending, cleared, reconciled, void)
- Comprehensive metadata for audit trails

### Future Enhancements

**Planned for Version 1.1:**
- Split transactions (single transaction across multiple envelopes)
- Scheduled future transactions
- Transaction templates
- Enhanced categorization with tags
- Support for foreign exchange transactions

**Migration Strategy:**
- Version field tracks schema version
- New fields are optional with default values
- Backward compatibility maintained for existing documents
- Migration scripts for breaking changes

## Business Logic

### Transaction Immutability

**Rule:** Once a transaction is cleared or reconciled, it cannot be edited - only voided.

**Rationale:** 
- Maintains audit trail integrity
- Prevents accidental or fraudulent modifications
- Supports bank reconciliation processes

**Implementation:**
- Check `status` before allowing edits
- If status is "cleared" or "reconciled", reject edit requests
- Provide void operation as alternative

### Voiding Transactions

**Process:**
1. Set `isVoid` to true
2. Set `voidedAt` to current timestamp
3. Set `voidedBy` to current user ID
4. Optionally set `voidReason`
5. Update `status` to "void"
6. Recalculate affected envelope balances

**Effect:**
- Transaction remains in database for audit
- Does not affect envelope balances
- Cannot be un-voided (create new transaction instead)

### Income Allocation

**Unallocated Income:**
- Set `envelopeId` to null
- Income is posted to budget but not assigned to envelope
- User can allocate to envelopes later

**Direct Allocation:**
- Set `envelopeId` to target envelope
- Income immediately increases envelope balance
- Common for predictable income sources

### Transfer Atomicity

**Requirement:** Transfer operations must be atomic - both source and destination updates succeed or both fail.

**Implementation:**
- Use transaction or compensating logic
- If source debit fails, don't credit destination
- If destination credit fails, roll back source debit
- Log all transfer operations for troubleshooting

### Envelope Balance Validation

**Before Expense/Transfer Out:**
1. Calculate current envelope balance
2. Check if balance >= transaction amount
3. If insufficient:
   - Check if envelope allows overspend
   - If overspend allowed, check against max overspend limit
   - If not allowed or limit exceeded, reject transaction

### Recurring Transaction Creation

**Process:**
1. Create transaction record with `isRecurring` = true
2. Set `recurringSeriesId` to group related transactions
3. Set `recurringFrequency` to define recurrence pattern
4. Calculate and set `nextOccurrenceDate`
5. Automated job creates next instance on due date

**Note:** Each occurrence is a separate transaction document (not a reference).

### Bank Reconciliation

**Workflow:**
1. Transactions start as "pending" when created
2. User marks transactions as "cleared" when they appear on bank statement
3. Set `clearedDate` when clearing
4. Set `isCleared` to true
5. After reconciliation period, can mark as "reconciled"

**Status Progression:**
- Pending → Cleared → Reconciled
- Voided transactions skip this flow

### Soft Delete

**Purpose:** Preserve data for audit and reporting while hiding from normal views.

**Implementation:**
- Set `isActive` to false instead of deleting document
- All queries filter by `isActive = true`
- Deleted transactions remain queryable for reports/audit
- Consider cleanup policy for very old soft-deleted records

### Receipt Management

**Upload Process:**
1. Upload image to Azure Blob Storage
2. Generate SAS token with appropriate expiration
3. Store URL with SAS token in `receiptUrl`
4. Set `hasReceipt` to true

**Security:**
- Use time-limited SAS tokens
- Store receipts in user-specific blob containers
- Implement access validation before returning URLs

### Data Retention

**Active Transactions:**
- Retained indefinitely while `isActive` = true
- Support historical reporting and analysis

**Soft-Deleted Transactions:**
- Retained for audit purposes
- Consider archival after 7 years (compliance requirement)

**Voided Transactions:**
- Never physically deleted
- Required for audit trail

---

**Maintained By:** Development Team  
**Document Owner:** Data Architecture Team  
**Last Reviewed:** 2026-02-15
