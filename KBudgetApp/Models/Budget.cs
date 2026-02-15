using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace KBudgetApp.Models;

/// <summary>
/// Represents a budget period in the envelope budgeting system.
/// Each budget represents a specific time period (e.g., monthly, bi-weekly) 
/// during which users allocate income to envelopes and track expenses.
/// </summary>
public class Budget
{
    #region Identity Fields

    /// <summary>
    /// Unique budget identifier (GUID).
    /// This serves as the primary key in Cosmos DB.
    /// </summary>
    [Required]
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// User identifier who owns this budget.
    /// Used as the partition key for user isolation in Cosmos DB.
    /// </summary>
    [Required]
    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    /// <summary>
    /// Document type discriminator. Always set to "budget".
    /// Supports potential future use of a single container for multiple entity types.
    /// </summary>
    [Required]
    [JsonPropertyName("type")]
    public string Type { get; set; } = "budget";

    #endregion

    #region Budget Information

    /// <summary>
    /// Budget name for easy identification.
    /// Examples: "February 2026 Budget", "Q1 2026", "Pay Period 2026-02"
    /// </summary>
    [Required]
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Optional description providing additional context about this budget.
    /// </summary>
    [JsonPropertyName("description")]
    public string? Description { get; set; }

    /// <summary>
    /// Budget period type indicating the frequency of this budget.
    /// Valid values: "monthly", "biweekly", "weekly", "custom"
    /// </summary>
    [Required]
    [JsonPropertyName("budgetPeriodType")]
    public string BudgetPeriodType { get; set; } = "monthly";

    /// <summary>
    /// Budget period start date (ISO 8601 format).
    /// Must be before the end date.
    /// </summary>
    [Required]
    [JsonPropertyName("startDate")]
    public DateTime StartDate { get; set; }

    /// <summary>
    /// Budget period end date (ISO 8601 format).
    /// Must be after the start date.
    /// </summary>
    [Required]
    [JsonPropertyName("endDate")]
    public DateTime EndDate { get; set; }

    /// <summary>
    /// Fiscal year this budget belongs to.
    /// Example: 2026
    /// </summary>
    [Required]
    [Range(2000, 2100)]
    [JsonPropertyName("fiscalYear")]
    public int FiscalYear { get; set; }

    /// <summary>
    /// Fiscal month number (1-12) within the fiscal year.
    /// 1 = January, 12 = December (adjusted for fiscal year start)
    /// </summary>
    [Required]
    [Range(1, 12)]
    [JsonPropertyName("fiscalMonth")]
    public int FiscalMonth { get; set; }

    #endregion

    #region Budget Status

    /// <summary>
    /// Current lifecycle status of the budget.
    /// Valid values: "draft", "active", "closed", "archived"
    /// Status transitions: draft → active → closed → archived
    /// </summary>
    [Required]
    [JsonPropertyName("status")]
    public string Status { get; set; } = "draft";

    /// <summary>
    /// Indicates if this is the current active budget for the user.
    /// Only one budget per user can have isCurrent = true at any time.
    /// </summary>
    [JsonPropertyName("isCurrent")]
    public bool IsCurrent { get; set; } = false;

    /// <summary>
    /// Total income allocated for this budget period.
    /// </summary>
    [Required]
    [Range(0, double.MaxValue)]
    [JsonPropertyName("totalIncome")]
    public decimal TotalIncome { get; set; } = 0;

    /// <summary>
    /// Total amount allocated to envelopes from the income.
    /// Should not exceed totalIncome (warning, not strict validation).
    /// </summary>
    [Required]
    [Range(0, double.MaxValue)]
    [JsonPropertyName("totalAllocated")]
    public decimal TotalAllocated { get; set; } = 0;

    /// <summary>
    /// Total amount spent from all envelopes in this budget period.
    /// Calculated from transaction data.
    /// </summary>
    [Required]
    [Range(0, double.MaxValue)]
    [JsonPropertyName("totalSpent")]
    public decimal TotalSpent { get; set; } = 0;

    /// <summary>
    /// Unallocated funds remaining.
    /// Calculated as: totalIncome - totalAllocated
    /// </summary>
    [Required]
    [JsonPropertyName("totalRemaining")]
    public decimal TotalRemaining { get; set; } = 0;

    /// <summary>
    /// Currency code for this budget (ISO 4217).
    /// Should match the user's default currency preference.
    /// Examples: "USD", "EUR", "GBP"
    /// </summary>
    [Required]
    [StringLength(3, MinimumLength = 3)]
    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    #endregion

    #region Rollover Configuration

    /// <summary>
    /// Indicates whether envelope balances can roll over from the previous budget.
    /// Inherits from user preference but can be overridden per budget.
    /// </summary>
    [JsonPropertyName("allowRollover")]
    public bool AllowRollover { get; set; } = true;

    /// <summary>
    /// Reference to the previous budget ID for rollover and linking.
    /// Enables budget history and trend analysis.
    /// </summary>
    [JsonPropertyName("previousBudgetId")]
    public string? PreviousBudgetId { get; set; }

    /// <summary>
    /// Total amount rolled over from the previous budget period.
    /// Sum of all envelope balances carried forward.
    /// </summary>
    [Range(0, double.MaxValue)]
    [JsonPropertyName("rolloverAmount")]
    public decimal RolloverAmount { get; set; } = 0;

    #endregion

    #region Goals and Targets

    /// <summary>
    /// Target savings amount for this budget period.
    /// Users can set savings goals to track financial progress.
    /// </summary>
    [Range(0, double.MaxValue)]
    [JsonPropertyName("savingsGoal")]
    public decimal SavingsGoal { get; set; } = 0;

    /// <summary>
    /// Actual savings achieved during this budget period.
    /// Calculated based on income minus expenses.
    /// </summary>
    [JsonPropertyName("savingsActual")]
    public decimal SavingsActual { get; set; } = 0;

    /// <summary>
    /// Maximum spending limit for this budget period (optional).
    /// Can be used to enforce strict spending controls.
    /// </summary>
    [Range(0, double.MaxValue)]
    [JsonPropertyName("spendingLimit")]
    public decimal? SpendingLimit { get; set; }

    #endregion

    #region Metadata

    /// <summary>
    /// Timestamp when the budget record was created (ISO 8601 format).
    /// </summary>
    [Required]
    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// User ID who created this budget.
    /// </summary>
    [Required]
    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when the budget record was last updated (ISO 8601 format).
    /// </summary>
    [Required]
    [JsonPropertyName("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// User ID who last updated this budget.
    /// </summary>
    [Required]
    [JsonPropertyName("updatedBy")]
    public string UpdatedBy { get; set; } = string.Empty;

    /// <summary>
    /// Indicates whether the budget is active.
    /// Used for soft deletes to maintain data integrity.
    /// </summary>
    [JsonPropertyName("isActive")]
    public bool IsActive { get; set; } = true;

    /// <summary>
    /// Indicates whether the budget has been archived.
    /// Archived budgets are old budgets moved to long-term storage.
    /// Recommended to archive budgets after 2 years.
    /// </summary>
    [JsonPropertyName("isArchived")]
    public bool IsArchived { get; set; } = false;

    /// <summary>
    /// Schema version number for this document.
    /// Supports future data migrations and schema evolution.
    /// </summary>
    [Required]
    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0";

    #endregion
}
