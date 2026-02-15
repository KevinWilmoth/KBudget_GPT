# Subtask 5: Define Cosmos DB Container Architecture

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Define the Cosmos DB container architecture, partition key strategy, and indexing policies for the envelope budgeting system. This includes determining the optimal container structure and configuration for performance, scalability, and cost-efficiency.

## Requirements

### Container Strategy

After analyzing the data models and query patterns, we will implement a **multiple container strategy** with the following containers:

1. **Users** - User profiles and settings
2. **Budgets** - Budget periods and configurations
3. **Envelopes** - Envelope categories and allocations
4. **Transactions** - Financial transactions

### Partition Key Strategy

The partition key is the most critical design decision in Cosmos DB. It affects:
- Query performance
- Storage distribution
- Scalability
- Cross-partition query costs

#### Recommended Partition Keys (Initial Strategy)

**Note:** This represents the initial partition key analysis. See **Subtask 13: Optimize Partition Key Strategy** for the final optimized approach that uses `/id` for Users/Budgets and `/budgetId` for Envelopes/Transactions to maximize point read performance.

| Container | Initial Partition Key | Rationale |
|-----------|---------------|-----------|
| Users | `/userId` | Natural isolation by user; users don't query across users |
| Budgets | `/userId` | Users query their own budgets; enables efficient user-scoped queries |
| Envelopes | `/userId` | Most queries are user-scoped; enables efficient filtering |
| Transactions | `/userId` | Most queries are user-scoped; best distribution for multi-tenant scenario |

**Key Considerations:**
- All containers initially use `userId` as partition key for consistent isolation
- This enables efficient single-partition queries for user-specific data
- Supports potential future sharding if a single user's data exceeds partition limits
- **See Subtask 13 for optimized partition key strategy based on point read optimization**

#### Alternative Considered: Composite Partition Keys

**Not chosen for this implementation**, but documented for future reference:

- **Budgets**: `/userId` + `/fiscalYear` - Could help if users have many years of data
- **Envelopes**: `/userId` + `/budgetId` - Could help distribute very active budgets
- **Transactions**: `/userId` + `/budgetId` - Could reduce hot partitions for high-volume users

**Decision**: Start with simple `/userId` partition key and monitor. Migrate to composite keys only if needed.

### Indexing Policies

#### Users Container
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {"path": "/*"}
  ],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"}
  ],
  "compositeIndexes": [
    [
      {"path": "/userId", "order": "ascending"},
      {"path": "/email", "order": "ascending"}
    ]
  ]
}
```

**Rationale**: 
- Default indexing for all paths (schema is small)
- Composite index on userId + email for user lookups

#### Budgets Container
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {"path": "/*"}
  ],
  "excludedPaths": [
    {"path": "/\"_etag\"/?"}
  ],
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

**Rationale**:
- Composite index for finding current budget (common query)
- Composite index for chronological budget listing
- Composite index for fiscal year reporting

#### Envelopes Container
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
    {"path": "/notes/?"}
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
      {"path": "/isRecurring", "order": "ascending"}
    ]
  ]
}
```

**Rationale**:
- Exclude large text fields (description, notes) from indexing to reduce costs
- Composite index for displaying ordered envelopes
- Composite index for category filtering
- Composite index for recurring envelope templates

#### Transactions Container
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
    {"path": "/notes/?"}
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
- Exclude large text fields to reduce index size and costs
- Composite index for chronological transaction listing by budget
- Composite index for envelope transaction history
- Composite index for filtering by transaction type
- Composite index for merchant lookups

### Throughput Configuration

#### Development Environment
- **Mode**: Serverless (pay per request)
- **Free Tier**: Enabled (1000 RU/s and 25 GB free)
- **Cost**: ~$0-5/month per container
- **Total**: ~$0-20/month

#### Staging Environment
- **Mode**: Provisioned throughput
- **Database-level throughput**: 400 RU/s (shared across all containers)
- **Cost**: ~$24/month
- **Rationale**: Low testing volume, shared throughput is cost-effective

#### Production Environment
- **Mode**: Provisioned throughput
- **Strategy**: Database-level throughput initially, migrate to container-level if needed
- **Database-level throughput**: 1000 RU/s (shared)
- **Cost**: ~$58/month
- **Future**: Monitor and scale individual containers as needed

**Throughput Sharing Strategy**:
- Start with shared database-level throughput
- Monitor RU consumption per container
- If Transactions container becomes bottleneck, move to dedicated throughput
- Expected distribution: Transactions (60%), Envelopes (20%), Budgets (15%), Users (5%)

### Container Configuration Summary

| Container | Partition Key | Initial Throughput | Indexing | TTL |
|-----------|---------------|-------------------|----------|-----|
| Users | /userId | Shared | Custom composite | Disabled |
| Budgets | /userId | Shared | Custom composite | Disabled |
| Envelopes | /userId | Shared | Custom composite | Disabled |
| Transactions | /userId | Shared | Custom composite | Optional (7 years) |

### Time-to-Live (TTL) Strategy

- **Users**: No TTL (preserve indefinitely)
- **Budgets**: No TTL (historical data valuable)
- **Envelopes**: No TTL (needed for historical transaction context)
- **Transactions**: Optional TTL of 7 years for regulatory compliance
  - After 7 years, transactions can be archived to cold storage
  - Implement soft TTL (archive flag) instead of hard delete

### Consistency Level

**Recommendation**: Session consistency (default)

**Rationale**:
- Strong enough for read-your-own-writes guarantee
- Lower latency than Strong consistency
- Lower cost than Strong consistency
- Suitable for single-user budgeting scenarios
- Users don't need global strong consistency

### Multi-Region Configuration

#### Development
- Single region (lowest cost)
- No automatic failover

#### Staging
- Single region with automatic failover
- Test failover scenarios

#### Production
- Option 1: Single region (cost-effective)
- Option 2: Multi-region (high availability)
  - Primary: East US
  - Secondary: West US (read replica)
  - Automatic failover enabled

**Recommendation**: Start with single region, evaluate multi-region based on user geography and SLA requirements.

### Monitoring and Alerts

Key metrics to monitor:
1. **Request Units (RU) consumption** - Alert if > 80% of provisioned throughput
2. **Throttled requests (429 errors)** - Alert on any throttling
3. **Storage per partition** - Alert if approaching 50 GB limit
4. **Query latency** - Alert if P95 > 100ms
5. **Hot partitions** - Monitor partition key distribution

### Query Optimization Guidelines

1. **Always include partition key in queries** - Avoid cross-partition queries when possible
2. **Use composite indexes** - Design queries to leverage composite indexes
3. **Limit result sets** - Use OFFSET/LIMIT for pagination
4. **Project only needed fields** - Use SELECT with specific fields, not SELECT *
5. **Cache frequently accessed data** - Cache user preferences, current budget
6. **Batch operations** - Use batch APIs for multiple operations

### Sample Queries with RU Estimates

| Query | Partition Scope | Estimated RUs | Notes |
|-------|----------------|---------------|-------|
| Get user by ID | Single | 1-2 RU | Point read |
| Get current budget | Single | 2-3 RU | Single partition, simple filter |
| Get all envelopes for budget | Single | 3-5 RU | Single partition, ~20 items |
| Get recent transactions (50) | Single | 10-15 RU | Single partition, ordered |
| Get all users (admin) | Cross-partition | 50-100 RU | Across all partitions |
| Calculate total spending | Single | 20-30 RU | Aggregation, single partition |

## Deliverables
- [ ] Container architecture documented
- [ ] Partition key strategy defined and justified
- [ ] Indexing policies defined for all containers
- [ ] Throughput configuration specified per environment
- [ ] TTL strategy documented
- [ ] Consistency level selected and documented
- [ ] Multi-region strategy defined
- [ ] Monitoring and alert guidelines created
- [ ] Query optimization guidelines documented
- [ ] Sample queries with RU estimates provided
- [ ] Documentation added to repository

## Acceptance Criteria
- Container strategy (multiple containers) is justified
- Partition key selection rationale is documented for each container
- Indexing policies optimize for common query patterns
- Throughput configuration is cost-effective for each environment
- All critical design decisions are documented with rationale
- Monitoring strategy covers key health metrics
- Query patterns align with partition key and index design
- Documentation includes examples and best practices
- Architecture supports future scalability requirements
- Cost estimates are provided for each environment

## Technical Notes
- Partition key cannot be changed after container creation - choose carefully
- Maximum partition size is 50 GB - monitor growth
- Cross-partition queries cost more RUs - design to avoid when possible
- Composite indexes must match query ORDER BY clauses exactly
- Serverless mode has a maximum of 5,000 RU/s burst capacity
- Index updates consume RUs - balance query performance vs write cost

## Decision Log

| Decision | Options Considered | Choice | Rationale |
|----------|-------------------|--------|-----------|
| Container strategy | Single vs Multiple | Multiple | Better separation of concerns, independent scaling |
| Partition key | userId vs budgetId vs composite | userId | Natural user isolation, simplest approach |
| Indexing | Full vs Selective | Selective | Exclude large text fields to reduce costs |
| Throughput (prod) | Database vs Container | Database | Start simple, migrate to container-level if needed |
| Consistency | Session vs Strong | Session | Sufficient for use case, better performance |
| Multi-region (prod) | Single vs Multi | Single (initially) | Cost-effective, evaluate based on user geography |

## Future Considerations
- Implement composite partition keys if individual user data exceeds 50 GB
- Migrate to autoscale throughput for production if usage is variable
- Implement multi-region writes if international user base grows
- Consider analytical workloads with Azure Synapse Link
- Evaluate change feed for real-time aggregations and caching

## Dependencies
- User data model (Subtask 1)
- Budget data model (Subtask 2)
- Envelope data model (Subtask 3)
- Transaction data model (Subtask 4)
- Existing Cosmos DB account

## Estimated Effort
- Research and analysis: 4 hours
- Partition key strategy: 2 hours
- Indexing policy design: 3 hours
- Throughput planning: 1 hour
- Documentation: 2 hours
- Review and validation: 1 hour
- **Total**: 13 hours
