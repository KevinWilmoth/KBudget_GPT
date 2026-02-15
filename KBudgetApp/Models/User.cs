using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace KBudgetApp.Models;

/// <summary>
/// Represents a user profile in the envelope budgeting system.
/// Stores user identity, profile information, preferences, settings, and metadata.
/// This model supports multi-user scenarios with isolated budgets and envelopes per user.
/// </summary>
public class User
{
    #region Identity Fields

    /// <summary>
    /// Unique user identifier (GUID). Matches Azure AD user ID.
    /// This serves as the primary key in Cosmos DB.
    /// </summary>
    [Required]
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// User identifier used for partition key consistency across containers.
    /// Should always match the Id field.
    /// </summary>
    [Required]
    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    /// <summary>
    /// Document type discriminator. Always set to "user".
    /// Supports potential future use of a single container for multiple entity types.
    /// </summary>
    [Required]
    [JsonPropertyName("type")]
    public string Type { get; set; } = "user";

    #endregion

    #region Profile Information

    /// <summary>
    /// User email address from Azure AD. Must be unique across all users.
    /// </summary>
    [Required]
    [EmailAddress]
    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// User's display name from Azure AD or user preference.
    /// </summary>
    [Required]
    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    /// User's first name (optional).
    /// </summary>
    [JsonPropertyName("firstName")]
    public string? FirstName { get; set; }

    /// <summary>
    /// User's last name (optional).
    /// </summary>
    [JsonPropertyName("lastName")]
    public string? LastName { get; set; }

    /// <summary>
    /// URL to user's profile picture stored in Azure Blob Storage (optional).
    /// </summary>
    [Url]
    [JsonPropertyName("profilePictureUrl")]
    public string? ProfilePictureUrl { get; set; }

    #endregion

    #region Preferences

    /// <summary>
    /// Default currency code (ISO 4217) for the user's budgets.
    /// Examples: "USD", "EUR", "GBP", "CAD"
    /// </summary>
    [Required]
    [StringLength(3, MinimumLength = 3)]
    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    /// <summary>
    /// User locale for date/number formatting.
    /// Examples: "en-US", "en-GB", "fr-FR", "de-DE"
    /// </summary>
    [Required]
    [JsonPropertyName("locale")]
    public string Locale { get; set; } = "en-US";

    /// <summary>
    /// User timezone (IANA timezone database name).
    /// Examples: "America/New_York", "Europe/London", "Asia/Tokyo"
    /// </summary>
    [Required]
    [JsonPropertyName("timezone")]
    public string Timezone { get; set; } = "America/New_York";

    /// <summary>
    /// Default budget period type for new budgets.
    /// Valid values: "monthly", "biweekly", "weekly"
    /// </summary>
    [Required]
    [JsonPropertyName("defaultBudgetPeriod")]
    public string DefaultBudgetPeriod { get; set; } = "monthly";

    /// <summary>
    /// Day of the week when budget periods start.
    /// Range: 0-6, where 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    /// </summary>
    [Range(0, 6)]
    [JsonPropertyName("startOfWeek")]
    public int StartOfWeek { get; set; } = 0;

    /// <summary>
    /// Month when the fiscal year starts.
    /// Range: 1-12, where 1 = January, 12 = December
    /// </summary>
    [Range(1, 12)]
    [JsonPropertyName("fiscalYearStart")]
    public int FiscalYearStart { get; set; } = 1;

    #endregion

    #region Settings

    /// <summary>
    /// Enable or disable email notifications for budget alerts and updates.
    /// </summary>
    [JsonPropertyName("enableEmailNotifications")]
    public bool EnableEmailNotifications { get; set; } = true;

    /// <summary>
    /// Enable or disable push notifications for mobile devices.
    /// </summary>
    [JsonPropertyName("enablePushNotifications")]
    public bool EnablePushNotifications { get; set; } = false;

    /// <summary>
    /// Enable or disable budget threshold alerts when spending approaches limits.
    /// </summary>
    [JsonPropertyName("enableBudgetAlerts")]
    public bool EnableBudgetAlerts { get; set; } = true;

    /// <summary>
    /// Percentage threshold (0-100) at which budget alerts are triggered.
    /// For example, 80 means alert when envelope spending reaches 80% of allocation.
    /// </summary>
    [Range(0, 100)]
    [JsonPropertyName("budgetAlertThreshold")]
    public int BudgetAlertThreshold { get; set; } = 80;

    /// <summary>
    /// Enable or disable automatic rollover of unused envelope balances to next period.
    /// </summary>
    [JsonPropertyName("enableRollover")]
    public bool EnableRollover { get; set; } = true;

    #endregion

    #region Metadata

    /// <summary>
    /// Timestamp when the user record was created (ISO 8601 format).
    /// </summary>
    [Required]
    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// User ID of the user who created this record.
    /// For user records, this is typically the same as the Id field.
    /// </summary>
    [Required]
    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when the user record was last updated (ISO 8601 format).
    /// </summary>
    [Required]
    [JsonPropertyName("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// User ID of the user who last updated this record.
    /// </summary>
    [Required]
    [JsonPropertyName("updatedBy")]
    public string UpdatedBy { get; set; } = string.Empty;

    /// <summary>
    /// Indicates whether the user account is active.
    /// Used for soft deletes to maintain data integrity and comply with GDPR.
    /// </summary>
    [JsonPropertyName("isActive")]
    public bool IsActive { get; set; } = true;

    /// <summary>
    /// Timestamp of the user's last login (ISO 8601 format).
    /// Used for account activity tracking and security monitoring.
    /// </summary>
    [JsonPropertyName("lastLoginAt")]
    public DateTime? LastLoginAt { get; set; }

    /// <summary>
    /// Schema version number for this document.
    /// Supports future data migrations and schema evolution.
    /// </summary>
    [Required]
    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0";

    #endregion
}
