# Subtask 13: Optimize Partition Key Strategy per Container

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Revise the partition key strategy for each Cosmos DB container to optimize for the most common access patterns, particularly point reads. This replaces the uniform `/userId` partition key strategy with container-specific optimizations.

## Requirements

### Revised Partition Key Strategy

Based on access pattern analysis and point read optimization:

| Container | Partition Key | Rationale |
|-----------|---------------|-----------|
| **Users** | `/id` | Point reads by userId; user only queries own data |
| **Budgets** | `/id` | Point reads by budgetId; enables efficient budget lookups |
| **Envelopes** | `/budgetId` | Most queries are "get all envelopes for this budget" |
| **Transactions** | `/budgetId` | Most queries are "get all transactions for this budget/envelope" |

### Detailed Analysis per Container

#### 1. Users Container - Partition Key: `/id`

**Primary Access Patterns:**
- Point read: Get user by userId (1 RU)
- Update user preferences (5-10 RUs)

**Query Examples:**
```sql
-- Point read (most efficient)
SELECT * FROM users u WHERE u.id = "user-guid"
```

**Optimization:**
- `/id` enables fastest possible point reads
- Since id = userId, partition key is intuitive
- No cross-partition queries needed (users only access their own data)

**Document Schema:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "user",
  "email": "john@example.com",
  ...
}
```

#### 2. Budgets Container - Partition Key: `/id`

**Primary Access Patterns:**
- Point read: Get budget by budgetId (1 RU)
- Get budgets for user (10-20 RUs, cross-partition)
- Get current budget for user (5-10 RUs, cross-partition)

**Query Examples:**
```sql
-- Point read (most efficient) - 1 RU
SELECT * FROM budgets b WHERE b.id = "budget-guid"

-- Get budgets for user (cross-partition) - 10-20 RUs
SELECT * FROM budgets b 
WHERE b.userId = "user-guid" 
  AND b.isActive = true
ORDER BY b.startDate DESC

-- Get current budget (cross-partition) - 5-10 RUs
SELECT * FROM budgets b 
WHERE b.userId = "user-guid" 
  AND b.isCurrent = true
```

**Optimization Rationale:**
- Most budget operations start with budgetId (from URL, navigation, cache)
- Point reads are extremely efficient (1 RU)
- "Get budgets for user" is done less frequently (dashboard load)
- Can cache user's budget list to minimize cross-partition queries
- Shared budgets benefit from budgetId-based lookups

**Tradeoff:**
- ✅ Faster point reads when budgetId is known
- ❌ "Get budgets for user" is cross-partition (mitigate with caching)

**Document Schema:**
```json
{
  "id": "b12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "February 2026 Budget",
  ...
}
```

#### 3. Envelopes Container - Partition Key: `/budgetId`

**Primary Access Patterns:**
- Get all envelopes for budget (3-5 RUs, single partition)
- Point read: Get envelope by id (requires budgetId, 1 RU)
- Update envelope balance (5-10 RUs)

**Query Examples:**
```sql
-- Get all envelopes for budget (single partition) - 3-5 RUs
SELECT * FROM envelopes e 
WHERE e.budgetId = "budget-guid" 
  AND e.isActive = true
ORDER BY e.sortOrder ASC

-- Point read (requires budgetId) - 1 RU
SELECT * FROM envelopes e 
WHERE e.budgetId = "budget-guid" 
  AND e.id = "envelope-guid"

-- Get envelopes by category (single partition) - 2-3 RUs
SELECT * FROM envelopes e 
WHERE e.budgetId = "budget-guid" 
  AND e.categoryType = "essential"
```

**Optimization Rationale:**
- Most common operation: "Show all envelopes for this budget"
- All envelopes in a budget are in same partition (very efficient)
- Budget page loads all envelopes at once (single partition query)
- Envelope updates are scoped to a budget

**Tradeoff:**
- ✅ Extremely efficient budget-scoped queries
- ✅ Single partition for entire budget's envelopes
- ⚠️ Point reads require knowing budgetId (easy to track in app state)

**Document Schema:**
```json
{
  "id": "e12e8400-e29b-41d4-a716-446655440001",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "name": "Groceries",
  ...
}
```

#### 4. Transactions Container - Partition Key: `/budgetId`

**Primary Access Patterns:**
- Get recent transactions for budget (10-15 RUs, single partition)
- Get transactions for envelope (5-10 RUs, single partition)
- Point read: Get transaction by id (requires budgetId, 1 RU)
- Get transactions by date range (15-25 RUs, single partition)

**Query Examples:**
```sql
-- Get recent transactions for budget (single partition) - 10-15 RUs
SELECT * FROM transactions t 
WHERE t.budgetId = "budget-guid" 
  AND t.isActive = true
ORDER BY t.transactionDate DESC, t.transactionTime DESC
OFFSET 0 LIMIT 50

-- Get transactions for envelope (single partition) - 5-10 RUs
SELECT * FROM transactions t 
WHERE t.budgetId = "budget-guid" 
  AND t.envelopeId = "envelope-guid"
ORDER BY t.transactionDate DESC

-- Point read (requires budgetId) - 1 RU
SELECT * FROM transactions t 
WHERE t.budgetId = "budget-guid" 
  AND t.id = "transaction-guid"

-- Get transactions by date range (single partition) - 15-25 RUs
SELECT * FROM transactions t 
WHERE t.budgetId = "budget-guid" 
  AND t.transactionDate >= "2026-02-01"
  AND t.transactionDate <= "2026-02-28"
ORDER BY t.transactionDate DESC
```

**Optimization Rationale:**
- Most transactions queries are budget-scoped
- All transactions for a budget period in same partition
- Envelope transaction history is single partition
- Date range queries are single partition
- Budget reports and analytics are very efficient

**Tradeoff:**
- ✅ Extremely efficient budget-scoped queries
- ✅ Single partition for all budget transactions
- ✅ Envelope queries are also single partition
- ⚠️ Point reads require knowing budgetId (track in app state)
- ❌ "Get all transactions for user" is cross-partition (rare query)

**Document Schema:**
```json
{
  "id": "t12e8400-e29b-41d4-a716-446655440002",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "transaction",
  "transactionType": "expense",
  ...
}
```

### Updated Indexing Policies

#### Users Container (Unchanged)
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [{"path": "/*"}],
  "excludedPaths": [{"path": "/\"_etag\"/?"}],
  "compositeIndexes": [
    [
      {"path": "/id", "order": "ascending"},
      {"path": "/email", "order": "ascending"}
    ]
  ]
}
```

#### Budgets Container (Updated)
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [{"path": "/*"}],
  "excludedPaths": [{"path": "/\"_etag\"/?"}],
  "compositeIndexes": [
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/isCurrent", "order": "ascending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/startDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/fiscalYear", "order": "descending"}
    ]
  ]
}
```
**Note:** Indexes on userId support cross-partition queries for "get budgets for user"

#### Envelopes Container (Updated)
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [{"path": "/*"}],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"},
    {"path": "/description/?"},
    {"path": "/notes/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/sortOrder", "order": "ascending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/categoryType", "order": "ascending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/isRecurring", "order": "ascending"}
    ]
  ]
}
```

#### Transactions Container (Updated)
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [{"path": "/*"}],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"},
    {"path": "/description/?"},
    {"path": "/notes/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/envelopeId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/transactionType", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/merchantName", "order": "ascending"}
    ]
  ]
}
```

### Caching Strategy

To mitigate cross-partition queries for Budgets:

#### Cache User's Budget List
```javascript
// Cache key: `budgets:${userId}`
// TTL: 5 minutes
// Invalidate on: Budget create/update/delete

async function getBudgetsForUser(userId) {
  const cacheKey = `budgets:${userId}`;
  let budgets = await cache.get(cacheKey);
  
  if (!budgets) {
    // Cross-partition query (expensive, but cached)
    budgets = await queryBudgetsByUserId(userId);
    await cache.set(cacheKey, budgets, 300); // 5 min TTL
  }
  
  return budgets;
}
```

#### Track Current Budget ID
```javascript
// Store in user session or local storage
const currentBudgetId = localStorage.getItem('currentBudgetId');

// All subsequent queries use budgetId (single partition)
const envelopes = await getEnvelopesForBudget(currentBudgetId);
const transactions = await getTransactionsForBudget(currentBudgetId);
```

### Application State Management

The app should maintain:
1. **Current User ID** - From auth token
2. **Current Budget ID** - Selected budget
3. **Budget List Cache** - User's budgets (refreshed periodically)

With this state, 90%+ of queries are single-partition point reads.

### Performance Comparison

#### Old Strategy (all `/userId`)
- Get budget by ID: 1 RU (need both budgetId and userId)
- Get envelopes for budget: 3-5 RUs (single partition if same userId)
- Get transactions for budget: 10-15 RUs (single partition if same userId)
- Get budgets for user: 10-20 RUs (single partition)

#### New Strategy (optimized per container)
- Get budget by ID: 1 RU ✅ (only need budgetId)
- Get envelopes for budget: 3-5 RUs ✅ (single partition, budgetId)
- Get transactions for budget: 10-15 RUs ✅ (single partition, budgetId)
- Get budgets for user: 10-20 RUs ⚠️ (cross-partition, but cache)

**Net Result:** Better point read performance, same overall query performance, with smart caching.

### Shared Budget Implications

With optimized partition keys:

1. **Budget Discovery** - "Get budgets for user" is cross-partition, but cached
2. **Budget Access** - Once budgetId is known, all queries are efficient
3. **Envelopes** - All envelopes in budget are in one partition (very fast)
4. **Transactions** - All transactions in budget are in one partition (very fast)

This actually **improves** shared budget performance since:
- Multiple users access same budget → same partition
- No hot partition issues (budget owns the partition, not user)
- Better distribution for high-volume budgets

### Migration Impact

Changes needed in:
- ✅ Subtask 5: Container Architecture (update partition keys)
- ✅ Subtask 6: Users Container (change partition key to `/id`)
- ✅ Subtask 7: Budgets Container (change partition key to `/id`)
- ✅ Subtask 8: Envelopes Container (change partition key to `/budgetId`)
- ✅ Subtask 9: Transactions Container (change partition key to `/budgetId`)
- ✅ Subtask 11: Documentation (update query patterns)
- ✅ Subtask 12: Shared Budget Support (update for new partition strategy)

## Deliverables
- [ ] Partition key strategy revised for each container
- [ ] Access pattern analysis documented
- [ ] Query examples updated with new partition keys
- [ ] Indexing policies updated
- [ ] Caching strategy documented
- [ ] Performance comparison documented
- [ ] Shared budget implications analyzed
- [ ] All related subtasks updated
- [ ] Documentation updated with new strategy

## Acceptance Criteria
- Each container has optimized partition key for its primary access patterns
- Point read performance is maximized for all containers
- Cross-partition queries are identified and caching strategy defined
- Indexing policies align with partition keys
- Shared budget support works efficiently with new partition strategy
- Performance benchmarks show improvement for common operations
- All subtasks updated to reflect new partition keys
- Documentation clearly explains rationale for each partition key choice

## Performance Benchmarks (Updated)

| Operation | Old RUs | New RUs | Improvement |
|-----------|---------|---------|-------------|
| Get user by ID | 1 | 1 | Same |
| Get budget by ID (only ID known) | N/A* | 1 | Much better |
| Get envelopes for budget | 3-5 | 3-5 | Same |
| Get transactions for budget | 10-15 | 10-15 | Same |
| Get budgets for user | 10-20 | 10-20 | Same (cache) |

*Old strategy required both budgetId and userId for point read

## Technical Notes
- Partition keys cannot be changed after container creation
- This update must be applied before container creation
- Application code must track budgetId for efficient queries
- Caching reduces impact of cross-partition queries
- Change feed can be used to invalidate budget caches

## Dependencies
- Subtask 5: Container Architecture (update)
- Subtask 6: Users Container Infrastructure (update partition key)
- Subtask 7: Budgets Container Infrastructure (update partition key)
- Subtask 8: Envelopes Container Infrastructure (update partition key)
- Subtask 9: Transactions Container Infrastructure (update partition key)
- Subtask 11: Documentation (update)
- Subtask 12: Shared Budget Support (update)

## Estimated Effort
- Analysis and design: 2 hours
- Update all subtask documents: 3 hours
- Update ARM templates: 2 hours
- Update documentation: 2 hours
- Review and validation: 1 hour
- **Total**: 10 hours
