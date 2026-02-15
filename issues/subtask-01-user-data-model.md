# Subtask 1: Design User Data Model

**Parent Epic:** [EPIC: Envelope-Based Budgeting Data Model](./EPIC-envelope-budgeting-data-model.md)

## Description
Design the User data model to store user profile information, preferences, and settings for the envelope budgeting system. This model will support multi-user scenarios where each user has their own isolated budgets and envelopes.

## Requirements

### Data Model Schema
Define the User document structure with the following fields:

1. **Identity Fields**
   - `id`: Unique user identifier (GUID, matches Azure AD user ID)
   - `userId`: Same as id (for partition key consistency)
   - `type`: Document type discriminator (value: "user")

2. **Profile Information**
   - `email`: User email address (unique, from Azure AD)
   - `displayName`: User's display name
   - `firstName`: First name (optional)
   - `lastName`: Last name (optional)
   - `profilePictureUrl`: URL to profile picture (optional)

3. **Preferences**
   - `currency`: Default currency code (e.g., "USD", "EUR", "GBP")
   - `locale`: User locale for date/number formatting (e.g., "en-US")
   - `timezone`: User timezone (e.g., "America/New_York")
   - `defaultBudgetPeriod`: Default budget period type ("monthly", "biweekly", "weekly")
   - `startOfWeek`: Day of week for budget periods (0-6, Sunday=0)
   - `fiscalYearStart`: Month for fiscal year start (1-12)

4. **Settings**
   - `enableEmailNotifications`: Boolean for email notifications
   - `enablePushNotifications`: Boolean for push notifications
   - `enableBudgetAlerts`: Boolean for budget threshold alerts
   - `budgetAlertThreshold`: Percentage threshold for alerts (e.g., 80)
   - `enableRollover`: Boolean to enable envelope balance rollover

5. **Metadata**
   - `createdAt`: Timestamp (ISO 8601)
   - `createdBy`: User ID who created the record
   - `updatedAt`: Timestamp (ISO 8601)
   - `updatedBy`: User ID who last updated the record
   - `isActive`: Boolean (for soft delete)
   - `lastLoginAt`: Timestamp of last login
   - `version`: Schema version number (e.g., "1.0")

### Validation Rules
- Email must be valid and unique
- Currency must be valid ISO 4217 code
- Timezone must be valid IANA timezone
- Budget alert threshold must be between 0-100
- All required fields must be present

### Indexing Strategy
- Primary index on `id` (automatic)
- Composite index on `email` for lookups
- Index on `isActive` for filtering active users
- Index on `createdAt` for sorting/reporting

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

## Deliverables
- [ ] User data model schema documented with all fields
- [ ] Sample JSON document created
- [ ] Validation rules defined
- [ ] Indexing strategy documented
- [ ] Data types and constraints specified
- [ ] Default values identified
- [ ] Schema evolution strategy noted
- [ ] Documentation added to repository

## Acceptance Criteria
- User schema includes all identity, profile, preferences, settings, and metadata fields
- Sample document validates against schema
- Indexing strategy supports common query patterns
- Email uniqueness can be enforced
- Schema supports soft deletes with `isActive` flag
- Currency and locale fields support internationalization
- Timezone support enables accurate date/time handling
- Schema version field supports future migrations
- Documentation is clear and includes examples

## Technical Notes
- The `userId` field duplicates `id` to maintain consistent partition key patterns across containers
- Azure AD integration will populate `id`, `email`, and `displayName` on first login
- Profile picture URLs will reference Azure Blob Storage
- Consider GDPR compliance for user data (right to deletion, data export)
- The `type` field supports potential future use of a single container for multiple entity types

## Dependencies
- Azure AD integration for user authentication
- Azure Blob Storage for profile pictures (optional)
- Cosmos DB Users container (Subtask 6)

## Estimated Effort
- Schema design: 2 hours
- Documentation: 1 hour
- Review and validation: 1 hour
- **Total**: 4 hours
