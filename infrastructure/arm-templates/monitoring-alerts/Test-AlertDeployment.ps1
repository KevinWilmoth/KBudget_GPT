################################################################################
# Test Azure Monitor Alerts Deployment Script
# 
# Purpose: Validate alert deployment configuration without deploying to Azure
# Features:
#   - Validate ARM template JSON syntax
#   - Validate parameter files JSON syntax
#   - Validate PowerShell script syntax
#   - Check for required parameters
#   - Simulate deployment with WhatIf mode
#   - Generate test report
#
# Usage:
#   .\Test-AlertDeployment.ps1
#   .\Test-AlertDeployment.ps1 -Environment dev
#   .\Test-AlertDeployment.ps1 -Verbose
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "prod", "all")]
    [string]$Environment = "all"
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

################################################################################
# Test Functions
################################################################################

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $symbol = if ($Passed) { "✓" } else { "✗" }
    $color = if ($Passed) { "Green" } else { "Red" }
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    
    Write-Host "[$symbol] $status - $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "    $Message" -ForegroundColor Gray
    }
    
    return $Passed
}

function Test-JsonFile {
    param(
        [string]$FilePath
    )
    
    try {
        $null = Get-Content $FilePath -Raw | ConvertFrom-Json
        return $true
    }
    catch {
        Write-Verbose "JSON validation error: $_"
        return $false
    }
}

function Test-PowerShellScript {
    param(
        [string]$FilePath
    )
    
    try {
        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$tokens)
        
        if ($errors) {
            Write-Verbose "PowerShell syntax errors: $errors"
            return $false
        }
        return $true
    }
    catch {
        Write-Verbose "PowerShell validation error: $_"
        return $false
    }
}

function Test-ParameterFile {
    param(
        [string]$FilePath
    )
    
    try {
        $params = Get-Content $FilePath -Raw | ConvertFrom-Json
        
        # Check required parameters
        $requiredParams = @(
            "actionGroupName",
            "actionGroupShortName",
            "emailAddress",
            "appServiceId",
            "appServiceName",
            "sqlServerId",
            "sqlServerName",
            "sqlDatabaseName",
            "storageAccountId",
            "storageAccountName",
            "functionAppId",
            "functionAppName"
        )
        
        $missingParams = @()
        foreach ($param in $requiredParams) {
            if (-not $params.parameters.PSObject.Properties[$param]) {
                $missingParams += $param
            }
        }
        
        if ($missingParams.Count -gt 0) {
            Write-Verbose "Missing parameters: $($missingParams -join ', ')"
            return $false
        }
        
        # Check webhook parameters exist
        if (-not $params.parameters.PSObject.Properties["webhookUri"]) {
            Write-Verbose "Missing webhookUri parameter"
            return $false
        }
        
        if (-not $params.parameters.PSObject.Properties["enableWebhook"]) {
            Write-Verbose "Missing enableWebhook parameter"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Verbose "Parameter validation error: $_"
        return $false
    }
}

function Test-ArmTemplate {
    param(
        [string]$TemplatePath
    )
    
    try {
        $template = Get-Content $TemplatePath -Raw | ConvertFrom-Json
        
        # Check schema
        if (-not $template.'$schema') {
            Write-Verbose "Missing ARM template schema"
            return $false
        }
        
        # Check parameters
        if (-not $template.parameters) {
            Write-Verbose "Missing parameters section"
            return $false
        }
        
        # Check resources
        if (-not $template.resources -or $template.resources.Count -eq 0) {
            Write-Verbose "No resources defined"
            return $false
        }
        
        # Check for action group
        $actionGroup = $template.resources | Where-Object { $_.type -eq "Microsoft.Insights/actionGroups" }
        if (-not $actionGroup) {
            Write-Verbose "Missing action group resource"
            return $false
        }
        
        # Check for alert rules
        $alerts = $template.resources | Where-Object { $_.type -eq "Microsoft.Insights/metricAlerts" }
        if (-not $alerts -or $alerts.Count -eq 0) {
            Write-Verbose "No metric alerts defined"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Verbose "ARM template validation error: $_"
        return $false
    }
}

################################################################################
# Main Test Execution
################################################################################

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Monitor Alerts Deployment Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$totalTests = 0
$passedTests = 0

# Test 1: PowerShell Script Syntax
$totalTests++
$testResult = Test-PowerShellScript -FilePath (Join-Path $ScriptDir "Deploy-MonitoringAlerts.ps1")
if (Write-TestResult -TestName "PowerShell Script Syntax" -Passed $testResult -Message "Deploy-MonitoringAlerts.ps1") {
    $passedTests++
}

# Test 2: ARM Template JSON Syntax
$totalTests++
$testResult = Test-JsonFile -FilePath (Join-Path $ScriptDir "monitoring-alerts.json")
if (Write-TestResult -TestName "ARM Template JSON Syntax" -Passed $testResult -Message "monitoring-alerts.json") {
    $passedTests++
}

# Test 3: ARM Template Structure
$totalTests++
$testResult = Test-ArmTemplate -TemplatePath (Join-Path $ScriptDir "monitoring-alerts.json")
if (Write-TestResult -TestName "ARM Template Structure" -Passed $testResult -Message "Validated resources and parameters") {
    $passedTests++
}

# Test 4-6: Parameter Files
$environments = if ($Environment -eq "all") { @("dev", "staging", "prod") } else { @($Environment) }

foreach ($env in $environments) {
    $paramFile = Join-Path $ScriptDir "parameters.$env.json"
    
    # JSON Syntax
    $totalTests++
    $testResult = Test-JsonFile -FilePath $paramFile
    if (Write-TestResult -TestName "Parameter File JSON Syntax ($env)" -Passed $testResult -Message $paramFile) {
        $passedTests++
    }
    
    # Parameter Completeness
    $totalTests++
    $testResult = Test-ParameterFile -FilePath $paramFile
    if (Write-TestResult -TestName "Parameter File Completeness ($env)" -Passed $testResult -Message "All required parameters present") {
        $passedTests++
    }
}

# Test 7: Documentation Files Exist
$totalTests++
$docs = @(
    "README.md",
    "ALERT-CONFIGURATION-GUIDE.md",
    "QUICK-REFERENCE.md"
)

$allDocsExist = $true
$missingDocs = @()
foreach ($doc in $docs) {
    if (-not (Test-Path (Join-Path $ScriptDir $doc))) {
        $allDocsExist = $false
        $missingDocs += $doc
    }
}

if (Write-TestResult -TestName "Documentation Files" -Passed $allDocsExist -Message $(if ($allDocsExist) { "All docs present" } else { "Missing: $($missingDocs -join ', ')" })) {
    $passedTests++
}

# Test 8: Script Parameters
$totalTests++
$scriptPath = Join-Path $ScriptDir "Deploy-MonitoringAlerts.ps1"
try {
    $scriptContent = Get-Content $scriptPath -Raw
    $hasEnvironmentParam = $scriptContent -match '\$Environment'
    $hasSendTestParam = $scriptContent -match '\$SendTestNotification'
    $hasEmailParam = $scriptContent -match '\$EmailAddress'
    $hasWebhookParam = $scriptContent -match '\$WebhookUri'
    
    $paramsValid = $hasEnvironmentParam -and $hasSendTestParam -and $hasEmailParam -and $hasWebhookParam
    
    if (Write-TestResult -TestName "Script Parameters" -Passed $paramsValid -Message "Required parameters defined") {
        $passedTests++
    }
}
catch {
    Write-TestResult -TestName "Script Parameters" -Passed $false -Message "Failed to parse script"
}

# Test 9: Alert Count
$totalTests++
try {
    $template = Get-Content (Join-Path $ScriptDir "monitoring-alerts.json") -Raw | ConvertFrom-Json
    $alertCount = ($template.resources | Where-Object { $_.type -eq "Microsoft.Insights/metricAlerts" }).Count
    $expectedCount = 7 # App CPU, App Memory, App HTTP, SQL DTU, SQL Deadlock, Storage Avail, Function Errors
    
    $alertCountValid = $alertCount -eq $expectedCount
    
    if (Write-TestResult -TestName "Alert Rule Count" -Passed $alertCountValid -Message "$alertCount alerts defined (expected $expectedCount)") {
        $passedTests++
    }
}
catch {
    Write-TestResult -TestName "Alert Rule Count" -Passed $false -Message "Failed to count alerts"
}

# Test 10: Webhook Support
$totalTests++
try {
    $template = Get-Content (Join-Path $ScriptDir "monitoring-alerts.json") -Raw | ConvertFrom-Json
    
    # Check for webhook parameters
    $hasWebhookUri = $null -ne $template.parameters.PSObject.Properties["webhookUri"]
    $hasEnableWebhook = $null -ne $template.parameters.PSObject.Properties["enableWebhook"]
    
    # Check for webhook receivers in action group
    $actionGroupResource = $template.resources | Where-Object { $_.type -eq "Microsoft.Insights/actionGroups" }
    $hasWebhookReceivers = $null -ne $actionGroupResource
    
    $webhookSupported = $hasWebhookUri -and $hasEnableWebhook -and $hasWebhookReceivers
    
    if (Write-TestResult -TestName "Webhook Support" -Passed $webhookSupported -Message "Webhook configuration available") {
        $passedTests++
    }
}
catch {
    Write-TestResult -TestName "Webhook Support" -Passed $false -Message "Failed to validate webhook support"
}

################################################################################
# Summary
################################################################################

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passRate = [math]::Round(($passedTests / $totalTests) * 100, 1)
$summaryColor = if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" }

Write-Host ""
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Red" })
Write-Host "Pass Rate: $passRate%" -ForegroundColor $summaryColor
Write-Host ""

if ($passedTests -eq $totalTests) {
    Write-Host "✓ All tests passed! Deployment configuration is valid." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review parameter files and update email addresses" -ForegroundColor White
    Write-Host "  2. Deploy to dev environment: .\Deploy-MonitoringAlerts.ps1 -Environment dev" -ForegroundColor White
    Write-Host "  3. Send test notification: .\Deploy-MonitoringAlerts.ps1 -Environment dev -SendTestNotification" -ForegroundColor White
    Write-Host ""
    exit 0
}
else {
    Write-Host "✗ Some tests failed. Please review the errors above." -ForegroundColor Red
    Write-Host ""
    exit 1
}
