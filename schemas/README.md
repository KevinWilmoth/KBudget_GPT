# Data Model Schemas

This directory contains JSON Schema definitions for all data models in the KBudget envelope budgeting system.

## Overview

JSON Schema files provide formal validation rules for documents stored in Azure Cosmos DB. These schemas can be used for:

- **Validation:** Ensure data integrity before writing to database
- **Documentation:** Serve as machine-readable documentation
- **Code Generation:** Generate TypeScript interfaces or C# classes
- **Testing:** Validate sample documents and test data

## Schema Files

### User Schema
- **File:** `user-schema.json`
- **Entity:** User profile and preferences
- **Sample:** `user-sample.json`
- **Documentation:** [docs/data-models/USER-DATA-MODEL.md](../docs/data-models/USER-DATA-MODEL.md)

## Schema Validation

### Using Node.js (Ajv)

```javascript
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const ajv = new Ajv();
addFormats(ajv);

const userSchema = require('./user-schema.json');
const validate = ajv.compile(userSchema);

const userData = {
  // ... user document
};

const valid = validate(userData);
if (!valid) {
  console.log(validate.errors);
}
```

### Using C# (NJsonSchema)

```csharp
using NJsonSchema;
using Newtonsoft.Json.Linq;

var schema = await JsonSchema.FromFileAsync("user-schema.json");
var userData = JObject.Parse(userJson);
var errors = schema.Validate(userData);

if (errors.Count > 0)
{
    foreach (var error in errors)
    {
        Console.WriteLine(error);
    }
}
```

### Using Python (jsonschema)

```python
import jsonschema
import json

with open('user-schema.json') as f:
    schema = json.load(f)

with open('user-sample.json') as f:
    user_data = json.load(f)

try:
    jsonschema.validate(user_data, schema)
    print("Valid!")
except jsonschema.ValidationError as e:
    print(f"Validation error: {e.message}")
```

## Schema Standards

All schemas follow:

- **Specification:** JSON Schema Draft 7
- **Format:** Formatted JSON with 2-space indentation
- **Validation:** All schemas validated before commit
- **Documentation:** Each field includes description
- **Examples:** Sample documents provided for each schema

## Schema Versioning

Schemas include a `version` property in the data model to support evolution:

- **Version Format:** "major.minor" (e.g., "1.0")
- **Major Version:** Breaking changes, may require data migration
- **Minor Version:** Additive changes, backward compatible

## Adding New Schemas

When adding a new entity schema:

1. Create `{entity}-schema.json` with complete JSON Schema
2. Create `{entity}-sample.json` with valid sample document
3. Validate sample against schema
4. Create documentation in `docs/data-models/{ENTITY}-DATA-MODEL.md`
5. Update this README with new schema information
6. Update main documentation index

## Related Documentation

- [User Data Model](../docs/data-models/USER-DATA-MODEL.md)
- [Data Model Documentation](../docs/DATA-MODEL-DOCUMENTATION.md) (coming soon)
- [Cosmos DB Container Architecture](../infrastructure/arm-templates/cosmos-database/CONTAINERS-REFERENCE.md) (coming soon)

## Validation Tools

### Online Validators
- [JSONSchema.net](https://www.jsonschema.net/) - Generate schemas from JSON
- [JSON Schema Validator](https://www.jsonschemavalidator.net/) - Validate JSON against schema

### Command Line Tools
```bash
# Using ajv-cli
npm install -g ajv-cli ajv-formats
ajv validate -s user-schema.json -d user-sample.json
```

## License

*License information to be added*
