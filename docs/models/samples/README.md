# User Data Model Sample Documents

This directory contains sample JSON documents demonstrating various User model scenarios.

## Available Samples

### user-complete.json
Complete user profile with all optional fields populated.
- Includes first name, last name, and profile picture URL
- Standard US user with USD currency
- All notification settings enabled

### user-minimal.json
Minimal user profile with only required fields.
- New user registration scenario
- No optional profile information
- Default settings applied

### user-international-uk.json
UK-based user with British preferences.
- Currency: GBP (British Pound)
- Locale: en-GB (British English)
- Timezone: Europe/London
- Fiscal year starts in April (UK tax year)
- Week starts on Monday (UK convention)

### user-international-spain.json
Spain-based user with European preferences.
- Currency: EUR (Euro)
- Locale: es-ES (Spanish)
- Timezone: Europe/Madrid
- Week starts on Monday (European convention)
- Custom alert threshold at 75%

### user-soft-deleted.json
Demonstrates soft-deleted user for GDPR compliance.
- isActive: false
- All notifications disabled
- Retains audit trail and metadata
- Scheduled for hard deletion after retention period

## Usage

These samples can be used for:
- Testing data validation rules
- Demonstrating internationalization features
- Cosmos DB container initialization
- API testing and development
- Documentation and training

## Validation

All samples conform to the User data model schema defined in [USER-DATA-MODEL.md](../USER-DATA-MODEL.md).

To validate a sample against the schema:

1. Ensure all required fields are present
2. Check field types match specifications
3. Verify ranges for numeric fields (startOfWeek, fiscalYearStart, budgetAlertThreshold)
4. Confirm ISO 8601 date format for timestamps
5. Validate email format
6. Confirm currency codes are valid ISO 4217
7. Verify timezone names are valid IANA identifiers

## Testing

You can import these samples into Cosmos DB for testing:

```bash
# Using Azure CLI
az cosmosdb sql container import \
  --account-name <account-name> \
  --database-name KBudgetDB \
  --name Users \
  --file user-complete.json
```

Or use the Azure Portal Data Explorer to manually insert documents.

## Notes

- All GUIDs in samples are for demonstration only
- Email addresses are example domains
- Timestamps reflect the sample creation date
- Profile picture URLs reference placeholder Azure Blob Storage paths
