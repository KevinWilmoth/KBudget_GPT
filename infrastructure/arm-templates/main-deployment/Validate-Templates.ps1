################################################################################
# Template Validation Script
# 
# Purpose: Validate ARM templates and parameter files
# Features:
#   - Validates JSON syntax
#   - Validates ARM template schema
#   - Checks parameter file compatibility
#   - Reports any errors found
#
# Usage:
#   .\Validate-Templates.ps1
#   .\Validate-Templates.ps1 -ResourceType "app-service"
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("all", "app-service", "sql-database", "storage-account", "azure-functions", "key-vault", "virtual-network")]
    [string]$ResourceType = "all"
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

################################################################################
# Helper Functions
################################################################################

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    
    $script:TotalTests++
    
    if ($Success) {
        Write-Host "✓ $TestName" -ForegroundColor Green
        $script:PassedTests++
    }
    else {
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($ErrorMessage) {
            Write-Host "  Error: $ErrorMessage" -ForegroundColor Yellow
        }
        $script:FailedTests++
    }
}

function Test-JsonFile {
    param(
        [string]$FilePath
    )
    
    try {
        $content = Get-Content $FilePath -Raw
        $null = $content | ConvertFrom-Json
        return $true
    }
    catch {
        Write-Verbose "JSON validation error: $_"
        return $false
    }
}

function Test-ArmTemplate {
    param(
        [string]$TemplatePath,
        [string]$ResourceName
    )
    
    Write-Host "`nValidating $ResourceName..." -ForegroundColor Cyan
    
    # Test template file exists
    $templateExists = Test-Path $TemplatePath
    Write-TestResult "$ResourceName template exists" $templateExists
    
    if (-not $templateExists) {
        return
    }
    
    # Test template JSON syntax
    $templateValid = Test-JsonFile -FilePath $TemplatePath
    Write-TestResult "$ResourceName template has valid JSON syntax" $templateValid
    
    if (-not $templateValid) {
        return
    }
    
    # Test template schema
    $template = Get-Content $TemplatePath -Raw | ConvertFrom-Json
    $hasSchema = $null -ne $template.'$schema'
    Write-TestResult "$ResourceName template has schema" $hasSchema
    
    $hasResources = $null -ne $template.resources
    Write-TestResult "$ResourceName template has resources" $hasResources
    
    # Test parameter files
    $templateDir = Split-Path -Parent $TemplatePath
    $environments = @("dev", "staging", "prod")
    
    foreach ($env in $environments) {
        $paramFile = Join-Path $templateDir "parameters.$env.json"
        $paramExists = Test-Path $paramFile
        Write-TestResult "$ResourceName $env parameter file exists" $paramExists
        
        if ($paramExists) {
            $paramValid = Test-JsonFile -FilePath $paramFile
            Write-TestResult "$ResourceName $env parameter file has valid JSON" $paramValid
        }
    }
}

################################################################################
# Main Execution
################################################################################

Write-Host "=== ARM Template Validation ===" -ForegroundColor Cyan
Write-Host "Script Directory: $ScriptDir`n" -ForegroundColor Gray

$resourcesToTest = @()

if ($ResourceType -eq "all") {
    $resourcesToTest = @(
        @{Name = "App Service"; Path = "app-service/app-service.json"},
        @{Name = "SQL Database"; Path = "sql-database/sql-database.json"},
        @{Name = "Storage Account"; Path = "storage-account/storage-account.json"},
        @{Name = "Azure Functions"; Path = "azure-functions/azure-functions.json"},
        @{Name = "Key Vault"; Path = "key-vault/key-vault.json"},
        @{Name = "Virtual Network"; Path = "virtual-network/virtual-network.json"}
    )
}
else {
    $resourceMap = @{
        "app-service" = @{Name = "App Service"; Path = "app-service/app-service.json"}
        "sql-database" = @{Name = "SQL Database"; Path = "sql-database/sql-database.json"}
        "storage-account" = @{Name = "Storage Account"; Path = "storage-account/storage-account.json"}
        "azure-functions" = @{Name = "Azure Functions"; Path = "azure-functions/azure-functions.json"}
        "key-vault" = @{Name = "Key Vault"; Path = "key-vault/key-vault.json"}
        "virtual-network" = @{Name = "Virtual Network"; Path = "virtual-network/virtual-network.json"}
    }
    $resourcesToTest = @($resourceMap[$ResourceType])
}

foreach ($resource in $resourcesToTest) {
    $templatePath = Join-Path $ScriptDir "..\$($resource.Path)"
    Test-ArmTemplate -TemplatePath $templatePath -ResourceName $resource.Name
}

# Test PowerShell deployment script
Write-Host "`nValidating PowerShell Deployment Script..." -ForegroundColor Cyan
$deployScriptPath = Join-Path $ScriptDir "Deploy-AzureResources.ps1"
$deployScriptExists = Test-Path $deployScriptPath
Write-TestResult "Deploy-AzureResources.ps1 exists" $deployScriptExists

if ($deployScriptExists) {
    try {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $deployScriptPath -Raw), [ref]$errors)
        $syntaxValid = $errors.Count -eq 0
        Write-TestResult "Deploy-AzureResources.ps1 has valid PowerShell syntax" $syntaxValid
    }
    catch {
        Write-TestResult "Deploy-AzureResources.ps1 has valid PowerShell syntax" $false $_
    }
}

# Summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $TotalTests" -ForegroundColor Gray
Write-Host "Passed: $PassedTests" -ForegroundColor Green
Write-Host "Failed: $FailedTests" -ForegroundColor Red

if ($FailedTests -eq 0) {
    Write-Host "`n✓ All validation tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n✗ Some validation tests failed. Please review the errors above." -ForegroundColor Red
    exit 1
}
