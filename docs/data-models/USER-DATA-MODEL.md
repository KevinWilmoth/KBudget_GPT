# User Data Model

**Version:** 1.0  
**Last Updated:** 2026-02-15  
**Status:** Active

## Overview

The User data model stores user profile information, preferences, and settings for the envelope-based budgeting system. This model supports multi-user scenarios where each user has their own isolated budgets and envelopes, with potential for shared household budgets in the future.

## Purpose

- Store user profile information from Azure Active Directory (Azure AD)
- Maintain user preferences for currency, locale, and timezone
- Configure notification and alert settings
- Track user activity and login history
- Support soft deletes for GDPR compliance
- Enable schema versioning for future migrations

## Container Information

- **Container Name:** `users`
- **Partition Key:** `/userId`
- **Partition Key Rationale:** Ensures single-partition queries for all user operations and provides natural data isolation per user

## Schema Definition

### Identity Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `id` | string (GUID) | Yes | Unique user identifier matching Azure AD user ID | UUID format |
| `userId` | string (GUID) | Yes | Duplicate of `id` for partition key consistency | Must equal `id` |
| `type` | string | Yes | Document type discriminator | Must be "user" |

### Profile Information

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `email` | string | Yes | User email address from Azure AD | Valid email format, unique, max 255 chars |
| `displayName` | string | Yes | User's display name | 1-255 characters |
| `firstName` | string | No | User's first name | Max 100 characters |
| `lastName` | string | No | User's last name | Max 100 characters |
| `profilePictureUrl` | string | No | URL to profile picture in Azure Blob Storage | Valid URI, max 2048 chars |

### Preferences

| Field | Type | Required | Description | Constraints | Default |
|-------|------|----------|-------------|-------------|---------|
| `currency` | string | Yes | Default currency code | ISO 4217 (3 uppercase letters) | "USD" |
| `locale` | string | Yes | Locale for date/number formatting | Format: "xx-XX" (e.g., "en-US") | "en-US" |
| `timezone` | string | Yes | User timezone | IANA timezone identifier | "America/New_York" |
| `defaultBudgetPeriod` | string | Yes | Default budget period type | One of: "monthly", "biweekly", "weekly" | "monthly" |
| `startOfWeek` | integer | Yes | Day of week for budget periods | 0-6 (0=Sunday, 6=Saturday) | 0 |
| `fiscalYearStart` | integer | Yes | Month for fiscal year start | 1-12 (1=January, 12=December) | 1 |

### Settings

| Field | Type | Required | Description | Constraints | Default |
|-------|------|----------|-------------|-------------|---------|
| `enableEmailNotifications` | boolean | Yes | Enable email notifications | - | true |
| `enablePushNotifications` | boolean | Yes | Enable push notifications | - | false |
| `enableBudgetAlerts` | boolean | Yes | Enable budget threshold alerts | - | true |
| `budgetAlertThreshold` | integer | Yes | Percentage threshold for alerts | 0-100 | 80 |
| `enableRollover` | boolean | Yes | Enable envelope balance rollover | - | true |

### Metadata

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `createdAt` | string (datetime) | Yes | Record creation timestamp | ISO 8601 format |
| `createdBy` | string (GUID) | Yes | User ID who created the record | UUID format |
| `updatedAt` | string (datetime) | Yes | Last update timestamp | ISO 8601 format |
| `updatedBy` | string (GUID) | Yes | User ID who last updated | UUID format |
| `isActive` | boolean | Yes | Active status for soft delete | - |
| `lastLoginAt` | string (datetime) | No | Last login timestamp | ISO 8601 format |
| `version` | string | Yes | Schema version number | Format: "major.minor" |

## Sample Document

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "user",
  "email": "john.doe@example.com",
  "displayName": "John Doe",
  "firstName": "John",
  "lastName": "Doe",
  "profilePictureUrl": "https://storage.example.com/profiles/johndoe.jpg",
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
  "lastLoginAt": "2026-02-15T14:25:00Z",
  "version": "1.0"
}
```

## Validation Rules

### Email Validation
- **Format:** Must be a valid email address (RFC 5322)
- **Uniqueness:** Must be unique across all users
- **Source:** Populated from Azure AD on first login
- **Length:** Maximum 255 characters

### Currency Validation
- **Format:** Must be a valid ISO 4217 currency code (3 uppercase letters)
- **Examples:** USD, EUR, GBP, CAD, AUD, JPY, CHF
- **Validation:** Should validate against list of supported currencies

### Locale Validation
- **Format:** Language code (lowercase) hyphen Country code (uppercase)
- **Pattern:** `^[a-z]{2}-[A-Z]{2}$`
- **Examples:** en-US, en-GB, fr-FR, de-DE, es-ES, pt-BR

### Timezone Validation
- **Format:** IANA timezone identifier
- **Examples:** America/New_York, America/Los_Angeles, Europe/London, Europe/Paris, Asia/Tokyo
- **Validation:** Must be a valid IANA timezone from the tz database

### Budget Alert Threshold
- **Range:** 0-100 (percentage)
- **Validation:** Integer value representing percentage of budget spent before triggering alert
- **Default:** 80 (alert when 80% of budget is used)

### UUID Fields
- **Format:** 8-4-4-4-12 hexadecimal format
- **Pattern:** `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- **Case:** Lowercase preferred but uppercase accepted
- **Fields:** id, userId, createdBy, updatedBy

### DateTime Fields
- **Format:** ISO 8601 (UTC)
- **Pattern:** `YYYY-MM-DDTHH:mm:ssZ` or `YYYY-MM-DDTHH:mm:ss.sssZ`
- **Examples:** 2026-02-15T10:30:00Z, 2026-02-15T14:25:30.123Z
- **Fields:** createdAt, updatedAt, lastLoginAt

### Required Fields
All fields marked as "Required: Yes" must be present in the document. Optional fields can be omitted or set to `null`.

## Indexing Strategy

### Automatic Indexes
- **Primary Index:** `id` (automatic, unique)
- **Partition Key Index:** `userId` (automatic)

### Recommended Custom Indexes

#### Email Lookup Index
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {
      "path": "/email/?"
    }
  ]
}
```
- **Purpose:** Enable efficient user lookup by email address
- **Use Case:** Login, user search, email uniqueness validation
- **Query Pattern:** `SELECT * FROM c WHERE c.email = @email`

#### Active Users Index
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {
      "path": "/isActive/?"
    }
  ]
}
```
- **Purpose:** Filter active users (exclude soft-deleted users)
- **Use Case:** User listings, reports, administration
- **Query Pattern:** `SELECT * FROM c WHERE c.isActive = true`

#### Created Date Index
```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {
      "path": "/createdAt/?"
    }
  ]
}
```
- **Purpose:** Sort and filter users by creation date
- **Use Case:** User reports, analytics, registration trends
- **Query Pattern:** `SELECT * FROM c WHERE c.createdAt >= @startDate ORDER BY c.createdAt DESC`

#### Composite Index for Active Users by Date
```json
{
  "compositeIndexes": [
    [
      {
        "path": "/isActive",
        "order": "ascending"
      },
      {
        "path": "/createdAt",
        "order": "descending"
      }
    ]
  ]
}
```
- **Purpose:** Efficiently query active users sorted by creation date
- **Use Case:** Admin dashboards, user listings
- **Query Pattern:** `SELECT * FROM c WHERE c.isActive = true ORDER BY c.createdAt DESC`

### Excluded Paths
Consider excluding large or rarely queried fields from indexing to reduce RU consumption and storage costs:

```json
{
  "excludedPaths": [
    {
      "path": "/profilePictureUrl/*"
    }
  ]
}
```

## Default Values

When creating a new user document, the following default values should be applied:

| Field | Default Value | Notes |
|-------|---------------|-------|
| `currency` | "USD" | Can be overridden based on user location |
| `locale` | "en-US" | Can be detected from browser or Azure AD |
| `timezone` | "America/New_York" | Should be detected from user location or browser |
| `defaultBudgetPeriod` | "monthly" | Most common budget period |
| `startOfWeek` | 0 | Sunday (ISO standard) |
| `fiscalYearStart` | 1 | January (calendar year default) |
| `enableEmailNotifications` | true | Opt-out model for important notifications |
| `enablePushNotifications` | false | Opt-in model for mobile notifications |
| `enableBudgetAlerts` | true | Enabled by default for better budget management |
| `budgetAlertThreshold` | 80 | Alert at 80% of budget spent |
| `enableRollover` | true | Envelope balances carry forward by default |
| `isActive` | true | User active by default |
| `version` | "1.0" | Current schema version |

## Common Query Patterns

### Get User by ID
```sql
SELECT * FROM c 
WHERE c.id = @userId
```
**RU Estimate:** 1 RU (single partition read)

### Get User by Email
```sql
SELECT * FROM c 
WHERE c.email = @email
```
**RU Estimate:** 2-3 RU (indexed query)

### Get All Active Users
```sql
SELECT * FROM c 
WHERE c.isActive = true
```
**RU Estimate:** Varies by user count (cross-partition query)

### Get Recently Created Users
```sql
SELECT * FROM c 
WHERE c.isActive = true 
  AND c.createdAt >= @startDate 
ORDER BY c.createdAt DESC
```
**RU Estimate:** 3-5 RU + 1 RU per result

### Update User Preferences
```sql
-- Update using Cosmos DB SDK
// C# example in Business Logic section
```
**RU Estimate:** 5-10 RU (replace operation)

### Update Last Login Time
```sql
-- Partial update using Cosmos DB SDK
// C# example in Business Logic section
```
**RU Estimate:** 5-10 RU (patch operation)

## Business Logic

### User Creation Flow

1. **Azure AD Authentication:** User authenticates with Azure AD
2. **Extract User Info:** Get `id`, `email`, `displayName` from Azure AD claims
3. **Check Existing User:** Query by `id` or `email` to check if user exists
4. **Create New User:** If not exists, create user document with:
   - Identity fields from Azure AD
   - Default preferences based on location/browser
   - Default settings
   - Set `createdAt`, `createdBy`, `updatedAt`, `updatedBy` to current timestamp and user ID
   - Set `version` to "1.0"
   - Set `isActive` to `true`
5. **Update Last Login:** Set `lastLoginAt` to current timestamp
6. **Return User:** Return user document to application

### User Update Flow

1. **Retrieve Current User:** Read user document by `id`
2. **Validate Changes:** Validate updated fields against validation rules
3. **Update Fields:** Apply changes to user document
4. **Update Metadata:** Set `updatedAt` to current timestamp, `updatedBy` to current user ID
5. **Save Document:** Replace user document in Cosmos DB
6. **Return Updated User:** Return updated user document

### Soft Delete Flow

1. **Retrieve User:** Read user document by `id`
2. **Set Inactive:** Set `isActive` to `false`
3. **Update Metadata:** Set `updatedAt` to current timestamp, `updatedBy` to current user ID
4. **Save Document:** Replace user document in Cosmos DB
5. **GDPR Compliance:** Consider permanent deletion after retention period

### Profile Picture Upload Flow

1. **Upload to Blob Storage:** Upload image to Azure Blob Storage
2. **Get SAS URL:** Generate URL or public URL for the uploaded image
3. **Update User:** Set `profilePictureUrl` to the blob URL
4. **Save User:** Update user document with new URL

## Schema Evolution Strategy

### Version 1.0 (Current)
- Initial schema with all core fields
- Supports basic user profile and preferences
- Designed for single-user budgets

### Future Considerations

#### Version 1.1 - Enhanced Notifications
- Add `notificationPreferences` object for granular control
- Add `emailFrequency` for digest notifications
- Backward compatible (add optional fields)

#### Version 1.2 - Multi-Currency Support
- Add `preferredCurrencies` array for users who work with multiple currencies
- Add `currencyConversionProvider` preference
- Backward compatible

#### Version 2.0 - Shared Budget Features
- Add `householdId` for linking users in shared budgets
- Add `defaultBudgetVisibility` setting
- May require data migration

### Migration Strategy

1. **Additive Changes:** Add new optional fields without changing existing ones
2. **Version Field:** Use `version` field to track schema version
3. **Application Logic:** Application code handles multiple schema versions
4. **Lazy Migration:** Update documents to new schema on read/write
5. **Batch Migration:** For breaking changes, use batch migration script
6. **Rollback Plan:** Keep previous version handling in code during transition

## GDPR Compliance

### Right to Erasure (Right to be Forgotten)

1. **Soft Delete:** Set `isActive` to `false` initially
2. **Retention Period:** Keep inactive users for 30-90 days for audit purposes
3. **Permanent Deletion:** After retention period, permanently delete user document
4. **Cascade Delete:** Also delete all related budgets, envelopes, and transactions

### Data Export

1. **User Data:** Export user profile in JSON format
2. **Related Data:** Include all budgets, envelopes, and transactions
3. **Readable Format:** Convert to human-readable format (PDF, CSV)
4. **Delivery:** Provide download link or email

### Data Portability

- Export format should be standards-compliant (JSON)
- Include schema version for import compatibility
- Provide import functionality for other systems

## Security Considerations

### Sensitive Data
- **Email:** PII - use encrypted connection
- **Profile Picture:** Stored in secured blob storage with access control
- **Preferences:** Generally non-sensitive but user-specific

### Access Control
- Users can only read/update their own user document
- System administrators can view user data for support purposes
- Audit all access to user data

### Data Integrity
- Validate all input against schema
- Prevent email address changes without verification
- Log all changes to user profile for audit trail

## Performance Optimization

### Query Optimization
- Always query by partition key (`userId`) when possible
- Use projection to select only needed fields
- Use composite indexes for common query patterns

### RU Optimization
- Use patch operations for single field updates instead of replace
- Cache user preferences in application layer
- Use session consistency level for read-after-write scenarios

### Caching Strategy
- Cache user profile in application memory or Redis
- Cache TTL: 5-15 minutes for preferences
- Invalidate cache on user update

## Testing Checklist

- [ ] User document validates against JSON schema
- [ ] All required fields are present
- [ ] Email format is valid
- [ ] Currency code is valid ISO 4217
- [ ] Locale follows pattern `xx-XX`
- [ ] Timezone is valid IANA identifier
- [ ] Budget alert threshold is 0-100
- [ ] UUID fields are valid GUIDs
- [ ] DateTime fields are ISO 8601 format
- [ ] Soft delete sets `isActive` to `false`
- [ ] Last login timestamp updates on login
- [ ] Schema version is "1.0"

## Related Documentation

- [Budget Data Model](./BUDGET-DATA-MODEL.md)
- [Envelope Data Model](./ENVELOPE-DATA-MODEL.md)
- [Transaction Data Model](./TRANSACTION-DATA-MODEL.md)
- [Cosmos DB Container Architecture](../../infrastructure/arm-templates/cosmos-database/CONTAINERS-REFERENCE.md)
- [Azure AD Authentication Setup](../AAD-AUTHENTICATION-SETUP-GUIDE.md)
- [Data Model Documentation](../DATA-MODEL-DOCUMENTATION.md)

## Change Log

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-02-15 | Initial User data model schema | System |

---

**Document Status:** ✅ Complete  
**Review Status:** Pending Review  
**Approved By:** TBD
