# Data Model Sample Documents

This directory contains sample JSON documents demonstrating various data model scenarios for the KBudget application.

## User Model Samples

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

## Budget Model Samples

### budget-complete.json
Complete budget with all fields populated.
- Active monthly budget for February 2026
- Includes rollover from previous period
- Savings goals and spending limits configured
- All financial tracking fields populated

### budget-draft.json
Draft budget being prepared for future period.
- Status: draft (not yet active)
- Minimal income and allocation (zero values)
- March 2026 budget ready for configuration
- Template for new budget setup

### budget-active.json
Current active budget in use.
- Status: active, isCurrent: true
- Mid-period with partial spending
- Rollover enabled with previous budget link
- Demonstrates typical active budget state

### budget-closed.json
Closed budget from previous period.
- Status: closed (period ended)
- Complete financial data preserved
- Available for rollover to next period
- Historical record maintained

### budget-minimal.json
Minimal budget with only required fields.
- Draft status with basic information
- No optional fields populated
- Demonstrates minimum viable budget
- Starting point for budget creation

### budget-biweekly.json
Biweekly pay period budget example.
- Period type: biweekly (14 days)
- Smaller income amount reflecting pay frequency
- Rollover disabled (common for biweekly budgets)
- Alternative to monthly budgeting

### budget-archived.json
Archived budget from over 2 years ago.
- Status: archived
- Historical budget from 2023
- Demonstrates long-term storage
- Optimizes query performance for active budgets

## Envelope Model Samples

### envelope-groceries-essential.json
Complete envelope for essential spending category.
- Category: Essential (Groceries)
- Active with partial spending
- Includes rollover tracking
- Warning threshold configured
- Demonstrates typical essential envelope

### envelope-entertainment-discretionary.json
Discretionary spending envelope for entertainment.
- Category: Discretionary (Entertainment)
- Optional description with details
- Active with spending history
- Last transaction timestamp recorded
- Standard discretionary envelope

### envelope-emergency-savings.json
Savings envelope with significant rollover balance.
- Category: Savings (Emergency Fund)
- Large rollover amount from previous periods
- Target goal set ($15,000)
- No warning threshold (savings accumulation)
- Demonstrates long-term savings envelope

### envelope-credit-card-debt.json
Debt payment envelope for credit card payoff.
- Category: Debt (Credit Card)
- Fully spent (payment made)
- Target amount for total payoff
- No rollover (debt payments don't carry forward)
- Demonstrates debt reduction envelope

### envelope-paused.json
Paused envelope demonstrating temporary inactivity.
- Status: paused
- Paused timestamp recorded
- Balance preserved during pause
- No allocation for current period
- Demonstrates pausing functionality

### envelope-minimal.json
Minimal envelope with only required fields.
- Discretionary miscellaneous category
- No description or target amount
- Default settings applied
- No spending yet
- Starting point for envelope creation

### envelope-overspend-allowed.json
Essential envelope with overspend capability.
- Category: Essential (Medical)
- Negative balance allowed
- Maximum overspend limit set
- Currently in overspent state
- Demonstrates overspend feature for emergencies

## Usage

These samples can be used for:
- Testing data validation rules
- Demonstrating internationalization features
- Cosmos DB container initialization
- API testing and development
- Documentation and training

## Validation

All samples conform to their respective data model schemas:
- User samples: [USER-DATA-MODEL.md](../USER-DATA-MODEL.md)
- Budget samples: [BUDGET-DATA-MODEL.md](../BUDGET-DATA-MODEL.md)
- Envelope samples: [ENVELOPE-DATA-MODEL.md](../ENVELOPE-DATA-MODEL.md)

To validate samples against their schemas:

### User Model Validation
1. Ensure all required fields are present
2. Check field types match specifications
3. Verify ranges for numeric fields (startOfWeek, fiscalYearStart, budgetAlertThreshold)
4. Confirm ISO 8601 date format for timestamps
5. Validate email format
6. Confirm currency codes are valid ISO 4217
7. Verify timezone names are valid IANA identifiers

### Budget Model Validation
1. Ensure all required fields are present
2. Verify startDate is before endDate
3. Confirm status is one of: draft, active, closed, archived
4. Validate budgetPeriodType is one of: monthly, biweekly, weekly, custom
5. Check fiscal year range (2000-2100)
6. Verify fiscal month range (1-12)
7. Confirm currency codes are valid ISO 4217
8. Validate financial amounts are non-negative
9. Check totalRemaining = totalIncome - totalAllocated
10. Verify only one budget per user has isCurrent = true

### Envelope Model Validation
1. Ensure all required fields are present
2. Verify budgetId references an existing budget
3. Confirm categoryType is one of: essential, discretionary, savings, debt
4. Validate status is one of: active, paused, closed
5. Check color is valid hex format (#RRGGBB or #RGB)
6. Confirm currency codes are valid ISO 4217
7. Validate financial amounts are non-negative
8. Check currentBalance = allocatedAmount + rolloverAmount - spentAmount
9. Verify warningThreshold is between 0-100
10. Confirm name is unique within budget
11. Verify sortOrder is unique within budget
12. If isPaused = true, verify pausedAt is set and status = "paused"
13. If isOverspendAllowed = false, verify currentBalance >= 0
14. If maxOverspendAmount is set, verify isOverspendAllowed = true

## Testing

You can import these samples into Cosmos DB for testing:

```bash
# Using Azure CLI - Import User samples
az cosmosdb sql container import \
  --account-name <account-name> \
  --database-name KBudgetDB \
  --name Users \
  --file user-complete.json

# Import Budget samples
az cosmosdb sql container import \
  --account-name <account-name> \
  --database-name KBudgetDB \
  --name Budgets \
  --file budget-complete.json

# Import Envelope samples
az cosmosdb sql container import \
  --account-name <account-name> \
  --database-name KBudgetDB \
  --name Envelopes \
  --file envelope-groceries-essential.json
```

Or use the Azure Portal Data Explorer to manually insert documents.

## Notes

- All GUIDs in samples are for demonstration only
- Email addresses are example domains
- Timestamps reflect the sample creation date
- Profile picture URLs reference placeholder Azure Blob Storage paths
