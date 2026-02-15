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
- [x] User data model schema documented with all fields
- [x] Sample JSON document created
- [x] Validation rules defined
- [x] Indexing strategy documented
- [x] Data types and constraints specified
- [x] Default values identified
- [x] Schema evolution strategy noted
- [x] Documentation added to repository

### Implementation Details
- **C# Model Class**: `KBudgetApp/Models/User.cs` - Complete implementation with all fields, validation attributes, and XML documentation
- **Comprehensive Documentation**: `docs/models/USER-DATA-MODEL.md` - Includes schema definition, field specifications, validation rules, indexing strategy, and GDPR compliance notes
- **Sample JSON Documents**: `docs/models/samples/` - Five sample documents covering minimal, complete, international (UK/Spain), and soft-deleted scenarios
- **Documentation Index**: `docs/models/README.md` - Overview of all data models and design principles

## Acceptance Criteria
- [x] User schema includes all identity, profile, preferences, settings, and metadata fields
- [x] Sample document validates against schema
- [x] Indexing strategy supports common query patterns
- [x] Email uniqueness can be enforced
- [x] Schema supports soft deletes with `isActive` flag
- [x] Currency and locale fields support internationalization
- [x] Timezone support enables accurate date/time handling
- [x] Schema version field supports future migrations
- [x] Documentation is clear and includes examples

### Acceptance Criteria Verification

✅ **User schema includes all identity, profile, preferences, settings, and metadata fields**
- Identity: `id`, `userId`, `type`
- Profile: `email`, `displayName`, `firstName`, `lastName`, `profilePictureUrl`
- Preferences: `currency`, `locale`, `timezone`, `defaultBudgetPeriod`, `startOfWeek`, `fiscalYearStart`
- Settings: `enableEmailNotifications`, `enablePushNotifications`, `enableBudgetAlerts`, `budgetAlertThreshold`, `enableRollover`
- Metadata: `createdAt`, `createdBy`, `updatedAt`, `updatedBy`, `isActive`, `lastLoginAt`, `version`

✅ **Sample documents validate against schema**
- Five sample documents provided in `docs/models/samples/`
- All samples conform to schema with required fields and valid data types
- Samples include minimal, complete, and international variations

✅ **Indexing strategy supports common query patterns**
- Primary index on `id` (automatic in Cosmos DB)
- Composite index on `email` for authentication lookups
- Composite indexes on `isActive` + `createdAt` and `isActive` + `lastLoginAt` for filtering and sorting
- Documented in `docs/models/USER-DATA-MODEL.md` with query examples

✅ **Email uniqueness can be enforced**
- Email field marked as required and unique in documentation
- Composite index on email enables efficient uniqueness checks
- Validation with `[EmailAddress]` attribute in C# model

✅ **Schema supports soft deletes with `isActive` flag**
- `isActive` boolean field included in schema
- Default value: `true`
- Sample soft-deleted user document provided
- Composite indexes include `isActive` for filtering

✅ **Currency and locale fields support internationalization**
- `currency`: ISO 4217 currency code (e.g., USD, EUR, GBP)
- `locale`: Standard locale identifier (e.g., en-US, es-ES)
- International samples provided for UK and Spain users
- Validation rules documented for both fields

✅ **Timezone support enables accurate date/time handling**
- `timezone`: IANA timezone database name (e.g., America/New_York, Europe/London)
- Required field with default value
- Validation rules documented
- International samples demonstrate timezone usage

✅ **Schema version field supports future migrations**
- `version` field included with default value "1.0"
- Schema evolution strategy documented
- Version history table in documentation
- Migration strategy outlined for future changes

✅ **Documentation is clear and includes examples**
- Comprehensive documentation in `docs/models/USER-DATA-MODEL.md`
- README files for models and samples directories
- XML documentation comments in C# model class
- Multiple sample JSON documents with explanatory README
- Field specifications table with types, constraints, and descriptions
- Validation rules clearly documented with examples

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
