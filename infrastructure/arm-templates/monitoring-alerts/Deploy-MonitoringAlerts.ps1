################################################################################
# Deploy and Test Azure Monitor Alerts Script
# 
# Purpose: Deploy alert rules and action groups for critical Azure resources
# Features:
#   - Deploy monitoring alerts for App Service, SQL Database, Storage, Functions
#   - Configure email and webhook notifications
#   - Test alert configurations with test notifications
#   - Validate alert deployment
#   - Document deployed alerts with thresholds and severities
#
# Prerequisites:
#   - Azure PowerShell module (Az)
#   - Authenticated to Azure (Connect-AzAccount)
#   - Proper permissions (Contributor or Owner)
#   - Resources to monitor already deployed
#
# Usage:
#   .\Deploy-MonitoringAlerts.ps1 -Environment dev
#   .\Deploy-MonitoringAlerts.ps1 -Environment prod -SendTestNotification
#   .\Deploy-MonitoringAlerts.ps1 -Environment staging -EmailAddress "ops@company.com" -WebhookUri "https://hooks.slack.com/..."
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$EmailAddress,

    [Parameter(Mandatory = $false)]
    [string]$WebhookUri,

    [Parameter(Mandatory = $false)]
    [switch]$SendTestNotification,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "alert-deployment_$($Environment)_$Timestamp.log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Environment mappings
$ResourceGroupName = "kbudget-$Environment-rg"

################################################################################
# Logging Functions
################################################################################

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Level] $TimeStamp - $Message"
    
    # Color coding for console output
    switch ($Level) {
        "INFO"    { Write-Host $LogMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage
}

################################################################################
# Validation Functions
################################################################################

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    # Check for Az PowerShell module
    if (-not (Get-Module -ListAvailable -Name Az.Monitor)) {
        Write-Log "Azure Monitor PowerShell module is not installed" "ERROR"
        Write-Log "Install with: Install-Module -Name Az.Monitor -AllowClobber -Scope CurrentUser" "ERROR"
        throw "Missing Azure Monitor PowerShell module"
    }
    
    # Check Azure authentication
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not authenticated to Azure" "ERROR"
            Write-Log "Run: Connect-AzAccount" "ERROR"
            throw "Not authenticated to Azure"
        }
        Write-Log "Authenticated as: $($context.Account.Id)" "SUCCESS"
        Write-Log "Subscription: $($context.Subscription.Name)" "INFO"
    }
    catch {
        Write-Log "Failed to get Azure context: $_" "ERROR"
        throw
    }

    # Check if resource group exists
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-Log "Resource group '$ResourceGroupName' not found" "ERROR"
            throw "Resource group does not exist"
        }
        Write-Log "Resource group found: $ResourceGroupName" "SUCCESS"
    }
    catch {
        Write-Log "Failed to validate resource group: $_" "ERROR"
        throw
    }
}

################################################################################
# Deployment Functions
################################################################################

function Deploy-AlertRules {
    Write-Log "Deploying Azure Monitor Alert Rules..." "INFO"
    
    $templatePath = Join-Path $ScriptDir "monitoring-alerts.json"
    $parametersPath = Join-Path $ScriptDir "parameters.$Environment.json"
    
    if (-not (Test-Path $templatePath)) {
        Write-Log "Template not found: $templatePath" "ERROR"
        throw "Template file not found"
    }

    if (-not (Test-Path $parametersPath)) {
        Write-Log "Parameters file not found: $parametersPath" "ERROR"
        throw "Parameters file not found"
    }
    
    try {
        if ($WhatIf) {
            Write-Log "WhatIf: Would deploy monitoring alerts" "INFO"
            return $null
        }
        
        # Read parameter file
        $subscriptionId = (Get-AzContext).Subscription.Id
        $paramContent = Get-Content $parametersPath -Raw | ConvertFrom-Json
        
        # Update resource IDs with actual subscription ID
        foreach ($param in $paramContent.parameters.PSObject.Properties) {
            if ($param.Value -is [PSCustomObject] -and $param.Value.value -is [string] -and $param.Value.value -match '\{subscription-id\}') {
                $param.Value.value = $param.Value.value -replace '\{subscription-id\}', $subscriptionId
            }
        }

        # Override email if provided
        if ($EmailAddress) {
            Write-Log "Overriding email address with: $EmailAddress" "INFO"
            $paramContent.parameters.emailAddress.value = $EmailAddress
        }

        # Configure webhook if provided
        if ($WebhookUri) {
            Write-Log "Configuring webhook: $WebhookUri" "INFO"
            $paramContent.parameters.webhookUri.value = $WebhookUri
            $paramContent.parameters.enableWebhook.value = $true
        }
        
        # Create temporary parameter file
        $tempParamFile = Join-Path $env:TEMP "alerts-params-$Timestamp.json"
        $paramContent | ConvertTo-Json -Depth 10 | Set-Content $tempParamFile
        
        Write-Log "Deploying alert rules to resource group: $ResourceGroupName" "INFO"
        
        $deployment = New-AzResourceGroupDeployment `
            -Name "alerts-deployment-$Timestamp" `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $templatePath `
            -TemplateParameterFile $tempParamFile `
            -Verbose
        
        Remove-Item $tempParamFile -Force -ErrorAction SilentlyContinue
        
        Write-Log "Monitoring Alerts deployed successfully" "SUCCESS"
        Write-Log "Action Group: $($deployment.Outputs.actionGroupName.Value)" "INFO"
        Write-Log "Action Group ID: $($deployment.Outputs.actionGroupId.Value)" "INFO"
        
        return $deployment
    }
    catch {
        Write-Log "Failed to deploy Monitoring Alerts: $_" "ERROR"
        if (Test-Path $tempParamFile -ErrorAction SilentlyContinue) {
            Remove-Item $tempParamFile -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

################################################################################
# Validation Functions
################################################################################

function Get-DeployedAlerts {
    param(
        [string]$ResourceGroupName
    )
    
    Write-Log "Retrieving deployed alert rules..." "INFO"
    
    try {
        $alerts = Get-AzMetricAlertRuleV2 -ResourceGroupName $ResourceGroupName
        Write-Log "Found $($alerts.Count) alert rules" "SUCCESS"
        
        return $alerts
    }
    catch {
        Write-Log "Failed to retrieve alerts: $_" "WARNING"
        return @()
    }
}

function Get-ActionGroups {
    param(
        [string]$ResourceGroupName
    )
    
    Write-Log "Retrieving action groups..." "INFO"
    
    try {
        $actionGroups = Get-AzActionGroup -ResourceGroupName $ResourceGroupName
        Write-Log "Found $($actionGroups.Count) action group(s)" "SUCCESS"
        
        return $actionGroups
    }
    catch {
        Write-Log "Failed to retrieve action groups: $_" "WARNING"
        return @()
    }
}

function Show-AlertSummary {
    param(
        [array]$Alerts,
        [array]$ActionGroups
    )
    
    Write-Log "=== Alert Configuration Summary ===" "INFO"
    Write-Log "" "INFO"
    
    # Action Groups Summary
    Write-Log "Action Groups:" "INFO"
    foreach ($ag in $ActionGroups) {
        Write-Log "  Name: $($ag.Name)" "INFO"
        Write-Log "  Short Name: $($ag.GroupShortName)" "INFO"
        Write-Log "  Enabled: $($ag.Enabled)" "INFO"
        
        if ($ag.EmailReceivers) {
            Write-Log "  Email Recipients: $($ag.EmailReceivers.Count)" "INFO"
            foreach ($email in $ag.EmailReceivers) {
                Write-Log "    - $($email.EmailAddress)" "INFO"
            }
        }
        
        if ($ag.WebhookReceivers) {
            Write-Log "  Webhook Recipients: $($ag.WebhookReceivers.Count)" "INFO"
            foreach ($webhook in $ag.WebhookReceivers) {
                Write-Log "    - $($webhook.Name)" "INFO"
            }
        }
        Write-Log "" "INFO"
    }
    
    # Alert Rules Summary
    Write-Log "Alert Rules Configured:" "INFO"
    Write-Log "" "INFO"
    
    foreach ($alert in $Alerts) {
        Write-Log "Alert: $($alert.Name)" "INFO"
        Write-Log "  Description: $($alert.Description)" "INFO"
        Write-Log "  Severity: $($alert.Severity)" "INFO"
        Write-Log "  Enabled: $($alert.Enabled)" "INFO"
        Write-Log "  Evaluation Frequency: $($alert.EvaluationFrequency)" "INFO"
        Write-Log "  Window Size: $($alert.WindowSize)" "INFO"
        
        # Extract metric details
        if ($alert.Criteria -and $alert.Criteria.AllOf) {
            foreach ($criterion in $alert.Criteria.AllOf) {
                Write-Log "  Metric: $($criterion.MetricName)" "INFO"
                Write-Log "  Operator: $($criterion.Operator)" "INFO"
                Write-Log "  Threshold: $($criterion.Threshold)" "INFO"
                Write-Log "  Time Aggregation: $($criterion.TimeAggregation)" "INFO"
            }
        }
        Write-Log "" "INFO"
    }
}

################################################################################
# Test Notification Functions
################################################################################

function Send-TestNotification {
    param(
        [string]$ResourceGroupName,
        [string]$ActionGroupName
    )
    
    Write-Log "Sending test notification..." "INFO"
    
    try {
        # Get the action group
        $actionGroup = Get-AzActionGroup -ResourceGroupName $ResourceGroupName -Name $ActionGroupName
        
        if (-not $actionGroup) {
            Write-Log "Action group '$ActionGroupName' not found" "ERROR"
            return $false
        }
        
        # Send test notification
        $testResult = Test-AzActionGroup `
            -ActionGroupResourceId $actionGroup.Id `
            -AlertType "servicehealth"
        
        Write-Log "Test notification sent successfully" "SUCCESS"
        Write-Log "Check your email and/or webhook endpoint for the test alert" "INFO"
        
        return $true
    }
    catch {
        Write-Log "Failed to send test notification: $_" "ERROR"
        return $false
    }
}

################################################################################
# Documentation Functions
################################################################################

function Export-AlertDocumentation {
    param(
        [array]$Alerts,
        [array]$ActionGroups,
        [string]$Environment
    )
    
    Write-Log "Generating alert documentation..." "INFO"
    
    $outputDir = Join-Path $ScriptDir "outputs"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $docFile = Join-Path $outputDir "alert-configuration_$($Environment)_$Timestamp.md"
    
    $doc = @"
# Azure Monitor Alert Configuration - $Environment Environment

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Resource Group:** $ResourceGroupName  

## Action Groups

"@
    
    foreach ($ag in $ActionGroups) {
        $doc += @"

### $($ag.Name)

- **Short Name:** $($ag.GroupShortName)
- **Enabled:** $($ag.Enabled)
- **Email Recipients:** $($ag.EmailReceivers.Count)
"@
        
        foreach ($email in $ag.EmailReceivers) {
            $doc += "`n  - $($email.EmailAddress)"
        }
        
        if ($ag.WebhookReceivers -and $ag.WebhookReceivers.Count -gt 0) {
            $doc += "`n- **Webhook Recipients:** $($ag.WebhookReceivers.Count)"
            foreach ($webhook in $ag.WebhookReceivers) {
                $doc += "`n  - $($webhook.Name)"
            }
        }
    }
    
    $doc += @"


## Alert Rules

| Alert Name | Resource | Metric | Threshold | Severity | Evaluation Frequency |
|------------|----------|--------|-----------|----------|---------------------|
"@
    
    foreach ($alert in $Alerts) {
        $resourceName = ($alert.Name -split '-')[0]
        
        if ($alert.Criteria -and $alert.Criteria.AllOf) {
            foreach ($criterion in $alert.Criteria.AllOf) {
                $severityText = switch ($alert.Severity) {
                    0 { "Critical" }
                    1 { "Error" }
                    2 { "Warning" }
                    3 { "Informational" }
                    4 { "Verbose" }
                    default { $alert.Severity }
                }
                
                $doc += "`n| $($alert.Name) | $resourceName | $($criterion.MetricName) | $($criterion.Operator) $($criterion.Threshold) | $severityText | $($alert.EvaluationFrequency) |"
            }
        }
    }
    
    $doc += @"


## Alert Severity Levels

- **Severity 0 (Critical):** Service completely down, immediate action required
- **Severity 1 (Error):** Major functionality impaired, urgent attention needed
- **Severity 2 (Warning):** Potential issues requiring attention within business hours
- **Severity 3 (Informational):** Informational messages for awareness
- **Severity 4 (Verbose):** Detailed tracking information for troubleshooting

## Alert Details

"@
    
    foreach ($alert in $Alerts) {
        $doc += @"

### $($alert.Name)

**Description:** $($alert.Description)  
**Severity:** $($alert.Severity)  
**Enabled:** $($alert.Enabled)  
**Evaluation Frequency:** $($alert.EvaluationFrequency)  
**Window Size:** $($alert.WindowSize)  

"@
        
        if ($alert.Criteria -and $alert.Criteria.AllOf) {
            $doc += "**Criteria:**`n"
            foreach ($criterion in $alert.Criteria.AllOf) {
                $doc += "- **Metric:** $($criterion.MetricName)`n"
                $doc += "- **Operator:** $($criterion.Operator)`n"
                $doc += "- **Threshold:** $($criterion.Threshold)`n"
                $doc += "- **Time Aggregation:** $($criterion.TimeAggregation)`n"
            }
        }
    }
    
    $doc += @"


## Response Procedures

### High CPU/Memory Alerts (Severity 2)
1. Check current resource metrics in Azure Portal
2. Review recent deployments or configuration changes
3. Analyze application logs for errors or unusual activity
4. Consider scaling up/out if sustained high usage
5. Investigate and optimize code if inefficient

### HTTP 5xx Errors (Severity 1)
1. Check application logs for error details
2. Review recent code deployments
3. Verify database and external service connectivity
4. Check for configuration issues
5. Implement fix and deploy
6. Monitor for resolution

### Database Issues (Severity 1-2)
1. Review SQL Database metrics in portal
2. Check for slow queries using Query Performance Insights
3. Investigate deadlocks using diagnostic logs
4. Optimize queries or add indexes as needed
5. Consider scaling database if needed

### Storage Availability (Severity 1)
1. Check Azure Service Health for outages
2. Review storage account metrics
3. Verify network connectivity
4. Check for throttling or quota issues
5. Contact Azure Support if needed

### Function Errors (Severity 2)
1. Check function execution logs
2. Review recent code changes
3. Verify dependencies and connections
4. Test function locally if possible
5. Deploy fix and monitor

## Testing Alerts

To verify alert configuration:

\`\`\`powershell
# Send test notification
.\Deploy-MonitoringAlerts.ps1 -Environment $Environment -SendTestNotification
\`\`\`

## Modifying Alerts

To update alert configuration:

1. Edit the parameters file: \`parameters.$Environment.json\`
2. Update email addresses or webhook URIs as needed
3. Redeploy: \`.\Deploy-MonitoringAlerts.ps1 -Environment $Environment\`

To adjust thresholds, edit the template file: \`monitoring-alerts.json\`

---

**Last Updated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    try {
        $doc | Set-Content -Path $docFile
        Write-Log "Alert documentation saved to: $docFile" "SUCCESS"
        
        # Also create a latest version
        $latestFile = Join-Path $outputDir "alert-configuration_$($Environment)_latest.md"
        $doc | Set-Content -Path $latestFile
        
        return $docFile
    }
    catch {
        Write-Log "Failed to export documentation: $_" "WARNING"
        return $null
    }
}

################################################################################
# Main Execution
################################################################################

try {
    Write-Log "=== Azure Monitor Alerts Deployment ===" "INFO"
    Write-Log "Environment: $Environment" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Log File: $LogFile" "INFO"
    
    if ($WhatIf) {
        Write-Log "Running in WhatIf mode - no resources will be created" "WARNING"
    }
    
    # Validate prerequisites
    Test-Prerequisites
    
    # Deploy alert rules
    $deployment = Deploy-AlertRules
    
    if (-not $WhatIf) {
        # Wait for deployment to complete
        Start-Sleep -Seconds 10
        
        # Get deployed resources
        $alerts = Get-DeployedAlerts -ResourceGroupName $ResourceGroupName
        $actionGroups = Get-ActionGroups -ResourceGroupName $ResourceGroupName
        
        # Show summary
        if (-not $SkipValidation) {
            Show-AlertSummary -Alerts $alerts -ActionGroups $actionGroups
        }
        
        # Export documentation
        $docFile = Export-AlertDocumentation `
            -Alerts $alerts `
            -ActionGroups $actionGroups `
            -Environment $Environment
        
        # Send test notification if requested
        if ($SendTestNotification -and $deployment) {
            $actionGroupName = $deployment.Outputs.actionGroupName.Value
            Write-Log "" "INFO"
            Write-Log "Sending test notification to verify configuration..." "INFO"
            $testResult = Send-TestNotification `
                -ResourceGroupName $ResourceGroupName `
                -ActionGroupName $actionGroupName
            
            if ($testResult) {
                Write-Log "" "INFO"
                Write-Log "Test notification sent successfully!" "SUCCESS"
                Write-Log "Please check:" "INFO"
                Write-Log "  - Email inbox for test alert" "INFO"
                if ($WebhookUri) {
                    Write-Log "  - Webhook endpoint for test notification" "INFO"
                }
                Write-Log "  - Spam/junk folder if email not received" "INFO"
            }
        }
        
        Write-Log "" "INFO"
        Write-Log "=== Deployment Summary ===" "SUCCESS"
        Write-Log "Alert Rules Deployed: $($alerts.Count)" "INFO"
        Write-Log "Action Groups: $($actionGroups.Count)" "INFO"
        if ($docFile) {
            Write-Log "Documentation: $docFile" "INFO"
        }
        Write-Log "Log File: $LogFile" "INFO"
    }
    
    Write-Log "" "INFO"
    Write-Log "=== Deployment Completed Successfully ===" "SUCCESS"
}
catch {
    Write-Log "" "INFO"
    Write-Log "=== Deployment Failed ===" "ERROR"
    Write-Log "Error: $_" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    Write-Log "Log File: $LogFile" "ERROR"
    
    exit 1
}
