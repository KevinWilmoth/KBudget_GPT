# Cosmos DB Container Architecture

**Version:** 1.0  
**Last Updated:** 2026-02-15  
**Status:** Active

## Overview

This document defines the Cosmos DB container architecture for the KBudget envelope budgeting system. It covers container strategy, partition key design, indexing policies, throughput configuration, and best practices for performance and cost optimization.

## Table of Contents

- [Container Strategy](#container-strategy)
- [Partition Key Strategy](#partition-key-strategy)
- [Container Specifications](#container-specifications)
- [Indexing Policies](#indexing-policies)
- [Throughput Configuration](#throughput-configuration)
- [Consistency and Replication](#consistency-and-replication)
- [Monitoring and Optimization](#monitoring-and-optimization)
- [Query Patterns and Performance](#query-patterns-and-performance)
- [Cost Optimization](#cost-optimization)
- [Future Considerations](#future-considerations)

## Container Strategy

### Multiple Container Approach

The KBudget system implements a **multiple container strategy** with four dedicated containers:

1. **Users** - User profiles and settings
2. **Budgets** - Budget periods and configurations
3. **Envelopes** - Envelope categories and allocations
4. **Transactions** - Financial transactions

### Rationale

**Why Multiple Containers?**

- **Separation of Concerns**: Each container has distinct data patterns and access requirements
- **Independent Scaling**: Containers can be scaled independently based on workload
- **Optimized Indexing**: Tailored index policies for each data type
- **Better Organization**: Clear data boundaries and easier maintenance
- **Flexible Throughput**: Ability to allocate RUs based on container-specific needs

**Alternative Considered: Single Container**

A single container approach was considered but rejected because:
- Mixed data types would require complex indexing strategies
- Difficult to optimize for diverse query patterns
- Limited flexibility in throughput allocation
- Harder to implement data lifecycle policies (TTL)

## Partition Key Strategy

### Overview

The partition key is the most critical design decision in Cosmos DB. It affects:
- **Query Performance**: Determines if queries are single-partition or cross-partition
- **Storage Distribution**: Controls how data is distributed across physical partitions
- **Scalability**: Enables horizontal scaling as data grows
- **Cost**: Cross-partition queries consume more RUs

### Initial Partition Key Strategy

**Note**: This represents the initial partition key analysis. See **Subtask 13: Optimize Partition Key Strategy** for the final optimized approach that uses `/id` for Users/Budgets and `/budgetId` for Envelopes/Transactions to maximize point read performance.

| Container | Initial Partition Key | Rationale |
|-----------|----------------------|-----------|
| Users | `/userId` | Natural isolation by user; users don't query across users |
| Budgets | `/userId` | Users query their own budgets; enables efficient user-scoped queries |
| Envelopes | `/userId` | Most queries are user-scoped; enables efficient filtering |
| Transactions | `/userId` | Most queries are user-scoped; best distribution for multi-tenant scenario |

### Partition Key Design Principles

1. **High Cardinality**: Choose keys with many unique values to distribute load
2. **Even Distribution**: Avoid hot partitions by ensuring balanced data distribution
3. **Query Alignment**: Most common queries should be single-partition
4. **Avoid Hot Keys**: Prevent excessive requests to a single partition
5. **Future-Proof**: Consider data growth and scaling needs

### User Isolation Benefits

Using `userId` as the partition key provides:
- **Data Isolation**: Each user's data is logically and physically separated
- **Query Efficiency**: Most queries filter by user, enabling single-partition access
- **Scalability**: As user base grows, partitions automatically distribute across nodes
- **Security**: Simplifies access control and data privacy
- **Performance**: Optimal for multi-tenant SaaS applications

### Partition Size Considerations

- **Maximum Partition Size**: 50 GB per logical partition
- **Monitoring**: Track partition sizes and alert if approaching limits
- **Migration Path**: If a single user exceeds 50 GB, consider composite partition keys

## Container Specifications

### Users Container

**Purpose**: Store user profiles, preferences, and settings

**Configuration**:
- **Container Name**: `Users`
- **Partition Key**: `/userId`
- **TTL**: Disabled (retain indefinitely)
- **Expected Size**: ~10 KB per document
- **Expected Volume**: Thousands of users
- **Access Pattern**: Low write, moderate read
- **RU Distribution**: ~5% of total

**Sample Document**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "user",
  "email": "john.doe@example.com",
  "displayName": "John Doe",
  "currency": "USD",
  "locale": "en-US",
  "timezone": "America/New_York",
  "createdAt": "2026-02-15T10:30:00Z",
  "isActive": true,
  "version": "1.0"
}
```

### Budgets Container

**Purpose**: Store budget periods and overall budget configuration

**Configuration**:
- **Container Name**: `Budgets`
- **Partition Key**: `/userId`
- **TTL**: Disabled (retain for historical analysis)
- **Expected Size**: ~5 KB per document
- **Expected Volume**: ~12-52 budgets per user per year
- **Access Pattern**: Moderate write, high read
- **RU Distribution**: ~15% of total

**Sample Document**:
```json
{
  "id": "b12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "budget",
  "name": "February 2026 Budget",
  "budgetPeriodType": "monthly",
  "startDate": "2026-02-01T00:00:00Z",
  "endDate": "2026-02-28T23:59:59Z",
  "status": "active",
  "isCurrent": true,
  "totalIncome": 5000.00,
  "currency": "USD",
  "version": "1.0"
}
```

### Envelopes Container

**Purpose**: Store envelope categories with allocations and balances

**Configuration**:
- **Container Name**: `Envelopes`
- **Partition Key**: `/userId`
- **TTL**: Disabled (needed for historical context)
- **Expected Size**: ~3 KB per document
- **Expected Volume**: ~10-30 envelopes per budget
- **Access Pattern**: Moderate write, very high read
- **RU Distribution**: ~20% of total

**Sample Document**:
```json
{
  "id": "e12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "name": "Groceries",
  "categoryType": "essential",
  "allocatedAmount": 600.00,
  "currentBalance": 275.50,
  "spentAmount": 324.50,
  "currency": "USD",
  "version": "1.0"
}
```

### Transactions Container

**Purpose**: Record all financial activities (income, expenses, transfers)

**Configuration**:
- **Container Name**: `Transactions`
- **Partition Key**: `/userId`
- **TTL**: Optional (7 years for regulatory compliance)
- **Expected Size**: ~2 KB per document
- **Expected Volume**: Hundreds to thousands per user per month
- **Access Pattern**: High write, very high read
- **RU Distribution**: ~60% of total

**Sample Document**:
```json
{
  "id": "t12e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "transaction",
  "transactionType": "expense",
  "budgetId": "b12e8400-e29b-41d4-a716-446655440001",
  "envelopeId": "e12e8400-e29b-41d4-a716-446655440001",
  "amount": 127.43,
  "description": "Grocery shopping",
  "transactionDate": "2026-02-14",
  "currency": "USD",
  "version": "1.0"
}
```

## Indexing Policies

### Users Container Indexing

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {"path": "/*"}
  ],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"},
    {"path": "/profilePictureUrl/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/email", "order": "ascending"}
    ],
    [
      {"path": "/isActive", "order": "descending"},
      {"path": "/createdAt", "order": "descending"}
    ],
    [
      {"path": "/isActive", "order": "descending"},
      {"path": "/lastLoginAt", "order": "descending"}
    }
  ]
}
```

**Rationale**:
- **Email Index**: Fast lookup for authentication and uniqueness checks
- **Active + Created**: Support queries for active users sorted by creation date
- **Active + LastLogin**: Support queries for active users sorted by login activity
- **Excluded profilePictureUrl**: URLs are rarely queried, reduce index size

**Common Queries**:
```sql
-- Find user by email
SELECT * FROM c WHERE c.email = "user@example.com"

-- Get active users sorted by creation
SELECT * FROM c WHERE c.isActive = true ORDER BY c.createdAt DESC

-- Get recently active users
SELECT * FROM c WHERE c.isActive = true ORDER BY c.lastLoginAt DESC
```

### Budgets Container Indexing

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {"path": "/*"}
  ],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"},
    {"path": "/description/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/startDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/isCurrent", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/fiscalYear", "order": "descending"},
      {"path": "/fiscalMonth", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/status", "order": "ascending"},
      {"path": "/startDate", "order": "descending"}
    ],
    [
      {"path": "/isActive", "order": "descending"},
      {"path": "/isArchived", "order": "ascending"}
    ]
  ]
}
```

**Rationale**:
- **userId + startDate**: Chronological budget listing
- **userId + isCurrent**: Fast lookup of current active budget (most common query)
- **userId + fiscalYear + fiscalMonth**: Fiscal reporting support
- **userId + status + startDate**: Filter budgets by status and date
- **isActive + isArchived**: Support archival queries
- **Excluded description**: Long text rarely queried

**Common Queries**:
```sql
-- Get current budget (most frequent)
SELECT * FROM b 
WHERE b.userId = @userId AND b.isCurrent = true AND b.isActive = true

-- Get budget history
SELECT * FROM b 
WHERE b.userId = @userId AND b.isActive = true
ORDER BY b.startDate DESC

-- Get budgets for fiscal year
SELECT * FROM b 
WHERE b.userId = @userId AND b.fiscalYear = 2026
ORDER BY b.startDate DESC
```

### Envelopes Container Indexing

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {"path": "/*"}
  ],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"},
    {"path": "/description/?"},
    {"path": "/icon/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/sortOrder", "order": "ascending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/categoryType", "order": "ascending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/isActive", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/isRecurring", "order": "descending"},
      {"path": "/sortOrder", "order": "ascending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/status", "order": "ascending"}
    ]
  ]
}
```

**Rationale**:
- **userId + budgetId + sortOrder**: Ordered envelope display (most common)
- **userId + budgetId + categoryType**: Category-based filtering
- **userId + budgetId + isActive**: Active envelope queries
- **userId + isRecurring + sortOrder**: Template queries for new budgets
- **userId + budgetId + status**: Status-based filtering
- **Excluded description and icon**: Reduce index size, rarely queried

**Common Queries**:
```sql
-- Get all envelopes for budget (most frequent)
SELECT * FROM e 
WHERE e.userId = @userId AND e.budgetId = @budgetId AND e.isActive = true
ORDER BY e.sortOrder ASC

-- Get envelopes by category
SELECT * FROM e 
WHERE e.userId = @userId AND e.budgetId = @budgetId 
  AND e.categoryType = "essential" AND e.isActive = true
ORDER BY e.sortOrder ASC

-- Get recurring envelope templates
SELECT * FROM e 
WHERE e.userId = @userId AND e.isRecurring = true AND e.isActive = true
ORDER BY e.sortOrder ASC
```

### Transactions Container Indexing

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {"path": "/*"}
  ],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"},
    {"path": "/description/?"},
    {"path": "/notes/?"},
    {"path": "/voidReason/?"},
    {"path": "/attachmentUrls/*"}
  ],
  "compositeIndexes": [
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/budgetId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/envelopeId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/fromEnvelopeId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/toEnvelopeId", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/transactionType", "order": "ascending"},
      {"path": "/transactionDate", "order": "descending"}
    ],
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/merchantName", "order": "ascending"}
    ]
  ]
}
```

**Rationale**:
- **userId + budgetId + transactionDate**: Chronological transaction listing
- **userId + envelopeId + transactionDate**: Envelope transaction history
- **userId + fromEnvelopeId + transactionDate**: Transfer tracking (outbound)
- **userId + toEnvelopeId + transactionDate**: Transfer tracking (inbound)
- **userId + transactionType + transactionDate**: Type-based filtering
- **userId + merchantName**: Merchant-based searches
- **Excluded text fields**: Reduce index size for description, notes, reasons, attachments

**Common Queries**:
```sql
-- Get recent transactions for budget (most frequent)
SELECT * FROM t 
WHERE t.userId = @userId AND t.budgetId = @budgetId 
  AND t.isActive = true AND t.isVoid = false
ORDER BY t.transactionDate DESC, t.transactionTime DESC
OFFSET 0 LIMIT 50

-- Get envelope transaction history
SELECT * FROM t 
WHERE t.userId = @userId AND t.envelopeId = @envelopeId 
  AND t.isActive = true AND t.isVoid = false
ORDER BY t.transactionDate DESC

-- Get transactions by type
SELECT * FROM t 
WHERE t.userId = @userId AND t.transactionType = "expense"
  AND t.isActive = true AND t.isVoid = false
ORDER BY t.transactionDate DESC
```

## Throughput Configuration

### Environment-Specific Strategy

| Environment | Mode | Throughput | Cost/Month | Notes |
|-------------|------|------------|------------|-------|
| Development | Serverless | Pay-per-request | $0-5 | Free tier enabled, 1000 RU/s + 25 GB free |
| Staging | Provisioned | 400 RU/s (shared) | ~$24 | Database-level throughput shared across containers |
| Production | Provisioned | 1000 RU/s (shared) | ~$58 | Database-level initially, migrate to container-level if needed |

### Throughput Distribution (Estimated)

Based on expected access patterns:

| Container | % of Total RUs | Dev (Serverless) | Staging (400 RU/s) | Production (1000 RU/s) |
|-----------|----------------|------------------|---------------------|------------------------|
| Users | 5% | Pay-per-request | ~20 RU/s | ~50 RU/s |
| Budgets | 15% | Pay-per-request | ~60 RU/s | ~150 RU/s |
| Envelopes | 20% | Pay-per-request | ~80 RU/s | ~200 RU/s |
| Transactions | 60% | Pay-per-request | ~240 RU/s | ~600 RU/s |

### Scaling Strategy

**Initial Approach**:
- Start with shared database-level throughput
- Monitor RU consumption per container
- Scale database throughput as needed

**When to Scale**:
- Alert when RU consumption exceeds 80% of provisioned throughput
- Monitor 429 (throttling) errors
- Track P95 latency and alert if > 100ms

**Migration Path**:
- If Transactions container becomes bottleneck, migrate to dedicated throughput
- Consider autoscale for variable workloads
- Evaluate serverless for production if usage patterns are unpredictable

### Autoscale vs Manual

**Autoscale Benefits**:
- Automatic scaling based on demand
- Pay for actual usage (within limits)
- Better for variable workloads

**Manual Provisioned Benefits**:
- Predictable costs
- Lower cost for steady workloads
- More control over performance

**Recommendation**: Start with manual provisioned, evaluate autoscale after 3 months of usage data.

## Consistency and Replication

### Consistency Level

**Selected**: Session Consistency (default)

**Rationale**:
- **Read-Your-Own-Writes**: Guarantees users see their own changes immediately
- **Lower Latency**: Better performance than Strong consistency
- **Lower Cost**: Less expensive than Strong consistency
- **Sufficient for Use Case**: Single-user budgeting doesn't require global strong consistency

**Alternative Levels**:
- **Strong**: Not needed; users don't share budgets across regions
- **Eventual**: Too weak; users expect to see their changes immediately
- **Bounded Staleness**: Unnecessary complexity for this use case

### Multi-Region Configuration

| Environment | Strategy | Regions | Failover |
|-------------|----------|---------|----------|
| Development | Single region | East US | No failover |
| Staging | Single region | East US | Automatic failover |
| Production | Single region (initially) | East US | Automatic failover |

**Future Consideration**: Implement multi-region for production if:
- International user base grows significantly
- SLA requirements demand higher availability
- Regional data residency requirements emerge

**Multi-Region Setup**:
```
Primary: East US (write region)
Secondary: West US (read replica)
Consistency: Session
Automatic Failover: Enabled
```

## Monitoring and Optimization

### Key Metrics to Monitor

1. **Request Units (RU) Consumption**
   - **Alert**: When > 80% of provisioned throughput
   - **Action**: Scale up throughput or optimize queries
   - **Frequency**: Every 5 minutes

2. **Throttled Requests (429 Errors)**
   - **Alert**: Any throttling detected
   - **Action**: Immediate investigation and scaling
   - **Frequency**: Real-time

3. **Storage Per Partition**
   - **Alert**: When approaching 40 GB (80% of 50 GB limit)
   - **Action**: Plan partition key strategy migration
   - **Frequency**: Daily

4. **Query Latency**
   - **Alert**: P95 latency > 100ms
   - **Action**: Review and optimize query patterns
   - **Frequency**: Every 15 minutes

5. **Hot Partitions**
   - **Alert**: Single partition consuming > 50% of total RUs
   - **Action**: Review partition key distribution
   - **Frequency**: Hourly

6. **Cross-Partition Queries**
   - **Monitor**: Percentage of cross-partition queries
   - **Goal**: Keep below 10% of total queries
   - **Action**: Optimize query patterns to include partition key

### Monitoring Tools

- **Azure Monitor**: Built-in metrics and alerts
- **Application Insights**: Query performance and usage patterns
- **Cosmos DB Insights**: Detailed container-level metrics
- **Custom Dashboards**: Create Power BI or Grafana dashboards

### Performance Optimization

**Query Optimization**:
1. Always include `userId` in WHERE clause (partition key)
2. Use composite indexes for ORDER BY queries
3. Limit result sets with OFFSET/LIMIT
4. Project only needed fields (avoid SELECT *)
5. Cache frequently accessed data (current budget, user preferences)

**Indexing Optimization**:
1. Exclude large text fields from indexing
2. Monitor index utilization metrics
3. Remove unused composite indexes
4. Balance index comprehensiveness vs write cost

**Application-Level Optimization**:
1. Use point reads when possible (provide both partition key and id)
2. Batch multiple operations
3. Implement caching layer (Redis/Azure Cache)
4. Use change feed for real-time updates
5. Implement retry logic for transient failures

## Query Patterns and Performance

### Sample Queries with RU Estimates

| Query | Partition Scope | Estimated RUs | Response Time | Notes |
|-------|----------------|---------------|---------------|-------|
| Get user by ID | Single | 1-2 RU | < 10ms | Point read with partition key |
| Get current budget | Single | 2-3 RU | < 20ms | Single partition, simple filter |
| Get all envelopes for budget | Single | 3-5 RU | < 30ms | Single partition, ~20 items |
| Get recent transactions (50) | Single | 10-15 RU | < 50ms | Single partition, ordered |
| Get all users (admin query) | Cross-partition | 50-100 RU | 100-500ms | Across all partitions, avoid if possible |
| Calculate total spending | Single | 20-30 RU | < 100ms | Aggregation, single partition |
| Search transactions by merchant | Single | 15-25 RU | < 75ms | Single partition with index |

### Query Best Practices

1. **Always Use Partition Key**: Include `userId` in all queries
2. **Limit Results**: Use pagination (OFFSET/LIMIT) for large result sets
3. **Avoid SELECT ***: Project only needed fields
4. **Use Composite Indexes**: Design queries to match composite index order
5. **Cache Results**: Cache frequently accessed, rarely changed data
6. **Batch Operations**: Use bulk APIs for multiple operations
7. **Monitor RU Consumption**: Track actual RU usage and optimize

### Anti-Patterns to Avoid

❌ **Cross-Partition Queries Without Filters**
```sql
-- BAD: Scans all partitions
SELECT * FROM c WHERE c.status = "active"
```

✅ **Include Partition Key**
```sql
-- GOOD: Single partition query
SELECT * FROM c WHERE c.userId = @userId AND c.status = "active"
```

❌ **SELECT * for Large Documents**
```sql
-- BAD: Returns all fields, high RU cost
SELECT * FROM c WHERE c.userId = @userId
```

✅ **Project Only Needed Fields**
```sql
-- GOOD: Returns only required fields
SELECT c.id, c.name, c.status FROM c WHERE c.userId = @userId
```

❌ **Unindexed ORDER BY**
```sql
-- BAD: No composite index support
SELECT * FROM c WHERE c.userId = @userId ORDER BY c.customField DESC
```

✅ **Use Indexed ORDER BY**
```sql
-- GOOD: Leverages composite index
SELECT * FROM c WHERE c.userId = @userId ORDER BY c.createdAt DESC
```

## Cost Optimization

### Cost Factors

1. **Provisioned Throughput**: Largest cost component (~$0.058 per RU/s per month)
2. **Storage**: ~$0.25 per GB per month
3. **Indexing**: Additional storage and write RU costs
4. **Cross-Region Replication**: Doubles storage and throughput costs

### Cost Optimization Strategies

1. **Right-Size Throughput**
   - Start conservative and scale up based on actual usage
   - Use metrics to identify optimal RU allocation
   - Consider autoscale for variable workloads

2. **Optimize Indexing**
   - Exclude large text fields (description, notes)
   - Remove unused composite indexes
   - Balance query performance vs index cost

3. **Optimize Queries**
   - Use partition keys to avoid cross-partition queries
   - Implement caching for frequently accessed data
   - Batch operations when possible

4. **Data Lifecycle Management**
   - Implement TTL for old transactions (7 years)
   - Archive historical data to cheaper storage
   - Soft delete instead of hard delete for audit trail

5. **Environment Strategy**
   - Use serverless for development (free tier)
   - Use shared throughput for staging (lower cost)
   - Monitor production closely and adjust as needed

### Estimated Monthly Costs

| Environment | Configuration | Estimated Cost |
|-------------|--------------|----------------|
| Development | Serverless, Free Tier | $0-5 |
| Staging | 400 RU/s Shared | $24 |
| Production | 1000 RU/s Shared | $58 |
| Production (Multi-Region) | 1000 RU/s, 2 Regions | $116 |

**Storage Estimates** (additional):
- Development: ~1-5 GB = $0.25-1.25/month
- Staging: ~10-25 GB = $2.50-6.25/month
- Production: ~100-500 GB = $25-125/month

## Future Considerations

### Scalability

1. **Composite Partition Keys**
   - Implement if individual user data exceeds 50 GB
   - Example: `/userId` + `/budgetId` for Envelopes
   - Requires container recreation or data migration

2. **Container-Level Throughput**
   - Migrate from database-level to container-level if Transactions container becomes bottleneck
   - Enables independent scaling per container
   - Higher cost but better control

3. **Autoscale Throughput**
   - Enable for production if usage is variable
   - Automatically scales between min and max RU/s
   - Pay for actual usage within range

### Advanced Features

1. **Change Feed**
   - Real-time data processing and event-driven architectures
   - Use cases: Real-time aggregations, caching updates, analytics
   - Enables reactive programming patterns

2. **Azure Synapse Link**
   - Enable analytical workloads without impacting transactional workloads
   - Near real-time analytics on Cosmos DB data
   - Use cases: Business intelligence, reporting, machine learning

3. **Multi-Region Writes**
   - Enable if international user base grows
   - Reduces latency for geographically distributed users
   - Requires conflict resolution strategy

4. **Point-in-Time Restore**
   - Enable continuous backup for disaster recovery
   - Restore to any point in time within retention period
   - Important for production environments

### Migration Paths

**Partition Key Optimization** (Subtask 13):
- Users: `/userId` → `/id` (point read optimization)
- Budgets: `/userId` → `/id` (point read optimization)
- Envelopes: `/userId` → `/budgetId` (query pattern optimization)
- Transactions: `/userId` → `/budgetId` (query pattern optimization)

**Throughput Evolution**:
1. Start: Shared database-level (400-1000 RU/s)
2. Growth: Migrate high-traffic containers to dedicated throughput
3. Scale: Enable autoscale for variable workloads
4. Optimize: Fine-tune based on actual usage patterns

## Related Documentation

- [User Data Model](./models/USER-DATA-MODEL.md)
- [Budget Data Model](./models/BUDGET-DATA-MODEL.md)
- [Envelope Data Model](./models/ENVELOPE-DATA-MODEL.md)
- [Transaction Data Model](./models/TRANSACTION-DATA-MODEL.md)
- [Azure Infrastructure Overview](./azure-infrastructure-overview.md)
- [Deployment Guide](../infrastructure/arm-templates/cosmos-database/README.md)

## References

- [Azure Cosmos DB Documentation](https://docs.microsoft.com/en-us/azure/cosmos-db/)
- [Partitioning and Horizontal Scaling](https://docs.microsoft.com/en-us/azure/cosmos-db/partitioning-overview)
- [Indexing Policies](https://docs.microsoft.com/en-us/azure/cosmos-db/index-policy)
- [Request Units](https://docs.microsoft.com/en-us/azure/cosmos-db/request-units)
- [Consistency Levels](https://docs.microsoft.com/en-us/azure/cosmos-db/consistency-levels)

## Change Log

| Date | Author | Changes |
|------|--------|---------|
| 2026-02-15 | Development Team | Initial container architecture documentation |

---

**Document Owner:** Data Architecture Team  
**Review Cycle:** Quarterly  
**Next Review:** 2026-05-15
