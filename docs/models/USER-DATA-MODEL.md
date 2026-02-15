# User Data Model Documentation

**Version:** 1.0  
**Last Updated:** 2026-02-15  
**Status:** Active

## Overview

The User data model represents user profiles in the KBudget envelope budgeting system. It stores user identity information, preferences, notification settings, and metadata to support multi-user scenarios where each user has their own isolated budgets and envelopes.

## Table of Contents

- [Schema Definition](#schema-definition)
- [Field Specifications](#field-specifications)
- [Validation Rules](#validation-rules)
- [Default Values](#default-values)
- [Indexing Strategy](#indexing-strategy)
- [Sample Documents](#sample-documents)
- [Schema Evolution](#schema-evolution)
- [GDPR Compliance](#gdpr-compliance)

## Schema Definition

### Document Structure

```json
{
  "id": "string (GUID)",
  "userId": "string (GUID)",
  "type": "user",
  "email": "string",
  "displayName": "string",
  "firstName": "string?",
  "lastName": "string?",
  "profilePictureUrl": "string?",
  "currency": "string",
  "locale": "string",
  "timezone": "string",
  "defaultBudgetPeriod": "string",
  "startOfWeek": "number",
  "fiscalYearStart": "number",
  "enableEmailNotifications": "boolean",
  "enablePushNotifications": "boolean",
  "enableBudgetAlerts": "boolean",
  "budgetAlertThreshold": "number",
  "enableRollover": "boolean",
  "createdAt": "string (ISO 8601)",
  "createdBy": "string (GUID)",
  "updatedAt": "string (ISO 8601)",
  "updatedBy": "string (GUID)",
  "isActive": "boolean",
  "lastLoginAt": "string? (ISO 8601)",
  "version": "string"
}
```

## Field Specifications

### Identity Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (GUID) | Yes | Unique user identifier matching Azure AD user ID. Primary key in Cosmos DB. |
| `userId` | string (GUID) | Yes | Duplicate of `id` field for partition key consistency across containers. |
| `type` | string | Yes | Document type discriminator. Always set to "user". |

### Profile Information

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | User email address from Azure AD. Must be unique and valid. |
| `displayName` | string | Yes | User's display name from Azure AD or user preference. |
| `firstName` | string | No | User's first name. |
| `lastName` | string | No | User's last name. |
| `profilePictureUrl` | string (URL) | No | URL to profile picture in Azure Blob Storage. |

### Preferences

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `currency` | string | Yes | "USD" | ISO 4217 currency code (e.g., "USD", "EUR", "GBP"). |
| `locale` | string | Yes | "en-US" | Locale for date/number formatting (e.g., "en-US", "fr-FR"). |
| `timezone` | string | Yes | "America/New_York" | IANA timezone database name. |
| `defaultBudgetPeriod` | string | Yes | "monthly" | Default budget period: "monthly", "biweekly", or "weekly". |
| `startOfWeek` | number | Yes | 0 | Day of week for budget periods (0-6, Sunday=0). |
| `fiscalYearStart` | number | Yes | 1 | Month fiscal year starts (1-12, January=1). |

### Settings

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `enableEmailNotifications` | boolean | Yes | true | Enable email notifications for alerts/updates. |
| `enablePushNotifications` | boolean | Yes | false | Enable push notifications for mobile devices. |
| `enableBudgetAlerts` | boolean | Yes | true | Enable budget threshold alerts. |
| `budgetAlertThreshold` | number | Yes | 80 | Alert threshold percentage (0-100). |
| `enableRollover` | boolean | Yes | true | Enable envelope balance rollover to next period. |

### Metadata

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `createdAt` | string (ISO 8601) | Yes | Timestamp when record was created. |
| `createdBy` | string (GUID) | Yes | User ID who created the record. |
| `updatedAt` | string (ISO 8601) | Yes | Timestamp when record was last updated. |
| `updatedBy` | string (GUID) | Yes | User ID who last updated the record. |
| `isActive` | boolean | Yes | Soft delete flag (true = active, false = deleted). |
| `lastLoginAt` | string (ISO 8601) | No | Timestamp of last user login. |
| `version` | string | Yes | Schema version number (e.g., "1.0"). |

## Validation Rules

### Email Validation
- Must be a valid email address format
- Must be unique across all users
- Populated from Azure AD on first login
- Cannot be changed after account creation

### Currency Validation
- Must be a valid ISO 4217 currency code
- Must be exactly 3 uppercase letters
- Examples: USD, EUR, GBP, CAD, JPY, AUD

### Locale Validation
- Must be a valid locale identifier
- Format: language code + optional country code (e.g., "en-US", "fr-FR")
- Used for formatting dates, numbers, and currency displays

### Timezone Validation
- Must be a valid IANA timezone database name
- Examples: "America/New_York", "Europe/London", "Asia/Tokyo"
- Used for accurate date/time handling across regions

### Budget Period Validation
- Must be one of: "monthly", "biweekly", "weekly"
- Case-sensitive lowercase values

### Numeric Range Validations
- `startOfWeek`: 0-6 (Sunday=0, Saturday=6)
- `fiscalYearStart`: 1-12 (January=1, December=12)
- `budgetAlertThreshold`: 0-100 (percentage)

### Required Field Validation
All fields marked as "Required" must be present and non-null/non-empty when creating or updating a user record.

## Default Values

The following fields have default values when creating a new user:

| Field | Default Value | Notes |
|-------|---------------|-------|
| `type` | "user" | Always set to this value |
| `currency` | "USD" | Can be overridden during creation |
| `locale` | "en-US" | Can be overridden during creation |
| `timezone` | "America/New_York" | Should be set based on user location |
| `defaultBudgetPeriod` | "monthly" | Most common budget period |
| `startOfWeek` | 0 | Sunday start (US convention) |
| `fiscalYearStart` | 1 | January start (calendar year) |
| `enableEmailNotifications` | true | Opt-in by default |
| `enablePushNotifications` | false | Opt-in required |
| `enableBudgetAlerts` | true | Help users stay on track |
| `budgetAlertThreshold` | 80 | Alert at 80% of allocation |
| `enableRollover` | true | Common user preference |
| `isActive` | true | Active by default |
| `version` | "1.0" | Current schema version |
| `createdAt` | DateTime.UtcNow | Set to current UTC time |
| `updatedAt` | DateTime.UtcNow | Set to current UTC time |

## Indexing Strategy

### Cosmos DB Container Configuration

**Container Name:** `Users`  
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
      "path": "/profilePictureUrl/?"
    }
  ],
  "compositeIndexes": [
    [
      {
        "path": "/email",
        "order": "ascending"
      }
    ],
    [
      {
        "path": "/isActive",
        "order": "descending"
      },
      {
        "path": "/createdAt",
        "order": "descending"
      }
    ],
    [
      {
        "path": "/isActive",
        "order": "descending"
      },
      {
        "path": "/lastLoginAt",
        "order": "descending"
      }
    ]
  ]
}
```

### Index Rationale

1. **Primary Index on `id`**: Automatic in Cosmos DB for point reads
2. **Composite Index on `email`**: Enables fast lookup by email address for authentication and uniqueness checks
3. **Composite Index on `isActive` + `createdAt`**: Supports queries for active users sorted by creation date
4. **Composite Index on `isActive` + `lastLoginAt`**: Supports queries for active users sorted by login activity
5. **Excluded Path for `profilePictureUrl`**: Profile picture URLs are rarely queried, exclude to reduce index size

### Common Query Patterns

```sql
-- Find user by email
SELECT * FROM c WHERE c.email = "user@example.com"

-- Get all active users
SELECT * FROM c WHERE c.isActive = true

-- Get active users sorted by creation date
SELECT * FROM c 
WHERE c.isActive = true 
ORDER BY c.createdAt DESC

-- Get recently active users
SELECT * FROM c 
WHERE c.isActive = true 
ORDER BY c.lastLoginAt DESC

-- Get user by ID (partition key + id)
SELECT * FROM c 
WHERE c.userId = "550e8400-e29b-41d4-a716-446655440000" 
AND c.id = "550e8400-e29b-41d4-a716-446655440000"
```

## Sample Documents

### Minimal User (New Registration)

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
  "defaultBudgetPeriod": "monthly",
  "startOfWeek": 0,
  "fiscalYearStart": 1,
  "enableEmailNotifications": true,
  "enablePushNotifications": false,
  "enableBudgetAlerts": true,
  "budgetAlertThreshold": 80,
  "enableRollover": true,
  "createdAt": "2026-02-15T10:30:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T10:30:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastLoginAt": "2026-02-15T10:30:00Z",
  "version": "1.0"
}
```

### Complete User Profile

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "user",
  "email": "john.doe@example.com",
  "displayName": "John Doe",
  "firstName": "John",
  "lastName": "Doe",
  "profilePictureUrl": "https://kbudgetstorage.blob.core.windows.net/profiles/550e8400.jpg",
  "currency": "USD",
  "locale": "en-US",
  "timezone": "America/New_York",
  "defaultBudgetPeriod": "monthly",
  "startOfWeek": 0,
  "fiscalYearStart": 1,
  "enableEmailNotifications": true,
  "enablePushNotifications": false,
  "enableBudgetAlerts": true,
  "budgetAlertThreshold": 80,
  "enableRollover": true,
  "createdAt": "2026-02-15T10:30:00Z",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedAt": "2026-02-15T14:25:00Z",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "isActive": true,
  "lastLoginAt": "2026-02-15T14:25:00Z",
  "version": "1.0"
}
```

### International User (UK)

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "userId": "660e8400-e29b-41d4-a716-446655440001",
  "type": "user",
  "email": "jane.smith@example.co.uk",
  "displayName": "Jane Smith",
  "firstName": "Jane",
  "lastName": "Smith",
  "currency": "GBP",
  "locale": "en-GB",
  "timezone": "Europe/London",
  "defaultBudgetPeriod": "monthly",
  "startOfWeek": 1,
  "fiscalYearStart": 4,
  "enableEmailNotifications": true,
  "enablePushNotifications": true,
  "enableBudgetAlerts": true,
  "budgetAlertThreshold": 90,
  "enableRollover": false,
  "createdAt": "2026-02-14T08:15:00Z",
  "createdBy": "660e8400-e29b-41d4-a716-446655440001",
  "updatedAt": "2026-02-15T09:30:00Z",
  "updatedBy": "660e8400-e29b-41d4-a716-446655440001",
  "isActive": true,
  "lastLoginAt": "2026-02-15T09:30:00Z",
  "version": "1.0"
}
```

### Soft-Deleted User

```json
{
  "id": "770e8400-e29b-41d4-a716-446655440002",
  "userId": "770e8400-e29b-41d4-a716-446655440002",
  "type": "user",
  "email": "deleted.user@example.com",
  "displayName": "Deleted User",
  "currency": "USD",
  "locale": "en-US",
  "timezone": "America/New_York",
  "defaultBudgetPeriod": "monthly",
  "startOfWeek": 0,
  "fiscalYearStart": 1,
  "enableEmailNotifications": false,
  "enablePushNotifications": false,
  "enableBudgetAlerts": false,
  "budgetAlertThreshold": 80,
  "enableRollover": true,
  "createdAt": "2025-01-10T12:00:00Z",
  "createdBy": "770e8400-e29b-41d4-a716-446655440002",
  "updatedAt": "2026-02-01T16:45:00Z",
  "updatedBy": "770e8400-e29b-41d4-a716-446655440002",
  "isActive": false,
  "lastLoginAt": "2026-01-28T10:00:00Z",
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

### Future Enhancements

Potential future additions to the schema:

- **Multi-factor Authentication**: `mfaEnabled`, `mfaMethod` fields
- **Subscription Information**: `subscriptionTier`, `subscriptionExpiry` fields
- **Privacy Settings**: `shareUsageData`, `allowMarketing` fields
- **Accessibility**: `highContrastMode`, `screenReaderEnabled` fields
- **Communication**: `phoneNumber`, `preferredContactMethod` fields
- **Social Features**: `publicProfile`, `allowBudgetSharing` fields

## GDPR Compliance

### Data Privacy Considerations

The User data model is designed with GDPR compliance in mind:

1. **Right to Access**: Users can retrieve all their personal data via API
2. **Right to Rectification**: Users can update their profile information at any time
3. **Right to Erasure**: Soft delete with `isActive = false` maintains referential integrity
4. **Right to Portability**: User data can be exported in JSON format
5. **Data Minimization**: Only necessary fields are collected and stored
6. **Purpose Limitation**: Data is used only for envelope budgeting functionality

### Sensitive Data

The following fields contain personally identifiable information (PII):

- `email`: Email address
- `displayName`: User's name
- `firstName`: First name
- `lastName`: Last name
- `profilePictureUrl`: Profile picture

### Data Retention

- **Active Users**: Retained indefinitely while account is active
- **Soft-Deleted Users**: Retained for 90 days before hard deletion
- **Audit Logs**: Maintain `createdAt`, `createdBy`, `updatedAt`, `updatedBy` for compliance

### Data Export Format

Users can request a complete export of their data in JSON format, including:
- User profile and preferences
- All budgets and envelopes
- Transaction history
- Settings and metadata

## Azure AD Integration

### Authentication Flow

1. User authenticates with Azure AD
2. Application receives Azure AD token with user claims
3. Extract `id` (object ID), `email`, and `displayName` from token
4. Check if user exists in Cosmos DB by `email`
5. If new user, create User document with Azure AD data
6. If existing user, update `lastLoginAt` timestamp

### Required Azure AD Claims

- `oid`: Object ID (mapped to `id` and `userId`)
- `email`: Email address (mapped to `email`)
- `name`: Display name (mapped to `displayName`)

### Profile Picture Integration

Profile pictures are stored in Azure Blob Storage:
- Container: `profiles`
- Naming: `{userId}.jpg`
- URL pattern: `https://{storage-account}.blob.core.windows.net/profiles/{userId}.jpg`

## Related Documentation

- [Budget Data Model](./BUDGET-DATA-MODEL.md)
- [Envelope Data Model](./ENVELOPE-DATA-MODEL.md)
- [Transaction Data Model](./TRANSACTION-DATA-MODEL.md)
- [Cosmos Container Architecture](../infrastructure/COSMOS-CONTAINER-ARCHITECTURE.md)
- [Azure AD Authentication Guide](../AAD-AUTHENTICATION-SETUP-GUIDE.md)
- [RBAC Documentation](../RBAC-DOCUMENTATION.md)

## Change Log

| Date | Author | Changes |
|------|--------|---------|
| 2026-02-15 | System | Initial documentation creation |

---

**Document Owner:** Development Team  
**Review Cycle:** Quarterly  
**Next Review:** 2026-05-15
