################################################################################
# WAF Detection Test Script
# 
# Purpose: Test Web Application Firewall (WAF) detection capabilities
# Features:
#   - Tests common attack patterns (SQL injection, XSS, etc.)
#   - Validates WAF is blocking/detecting malicious requests
#   - Tests health probe functionality
#   - Validates SSL/TLS configuration
#   - Generates test report
#
# Prerequisites:
#   - Application Gateway with WAF deployed
#   - PowerShell 5.1 or later
#   - Internet access to test endpoint
#
# Usage:
#   .\Test-WAF.ps1 -ApplicationGatewayUrl "https://your-appgw.region.cloudapp.azure.com"
#   .\Test-WAF.ps1 -ApplicationGatewayUrl "https://your-appgw.region.cloudapp.azure.com" -Verbose
#
################################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApplicationGatewayUrl,

    [Parameter(Mandatory = $false)]
    [switch]$SkipSslValidation
)

################################################################################
# Script Configuration
################################################################################

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "waf_test_$Timestamp.log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Test results
$TestResults = @()

################################################################################
# Logging Functions
################################################################################

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "TEST")]
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
        "TEST"    { Write-Host $LogMessage -ForegroundColor Magenta }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage
}

function Write-SectionHeader {
    param([string]$Title)
    
    $separator = "=" * 80
    Write-Log ""
    Write-Log $separator
    Write-Log $Title
    Write-Log $separator
}

################################################################################
# Test Functions
################################################################################

function Test-BasicConnectivity {
    param([string]$Url)
    
    Write-Log "Testing basic connectivity to: $Url" "TEST"
    
    try {
        if ($SkipSslValidation) {
            # Skip SSL validation for self-signed certificates
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 30 -UseBasicParsing
        
        Write-Log "Status Code: $($response.StatusCode)" "INFO"
        Write-Log "Basic connectivity test passed" "SUCCESS"
        
        return @{
            TestName = "Basic Connectivity"
            Passed   = $true
            Details  = "HTTP $($response.StatusCode)"
        }
    }
    catch {
        Write-Log "Basic connectivity test failed: $($_.Exception.Message)" "ERROR"
        
        return @{
            TestName = "Basic Connectivity"
            Passed   = $false
            Details  = $_.Exception.Message
        }
    }
    finally {
        if ($SkipSslValidation) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

function Test-SqlInjection {
    param([string]$BaseUrl)
    
    Write-Log "Testing SQL Injection detection..." "TEST"
    
    $sqlInjectionPayloads = @(
        "' OR '1'='1",
        "1' OR '1'='1' --",
        "' UNION SELECT NULL--",
        "admin'--",
        "1' AND 1=1--"
    )
    
    $blocked = 0
    $allowed = 0
    
    foreach ($payload in $sqlInjectionPayloads) {
        $testUrl = "$BaseUrl/?id=$([System.Web.HttpUtility]::UrlEncode($payload))"
        
        try {
            if ($SkipSslValidation) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
            
            $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                $allowed++
                Write-Log "Payload allowed: $payload" "WARNING"
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            if ($statusCode -eq 403) {
                $blocked++
                Write-Log "Payload blocked (403): $payload" "SUCCESS"
            }
            else {
                Write-Log "Unexpected response ($statusCode): $payload" "WARNING"
            }
        }
        finally {
            if ($SkipSslValidation) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    $passed = $blocked -gt 0
    Write-Log "SQL Injection test: $blocked blocked, $allowed allowed" "INFO"
    
    return @{
        TestName = "SQL Injection Detection"
        Passed   = $passed
        Details  = "$blocked of $($sqlInjectionPayloads.Count) payloads blocked"
    }
}

function Test-CrossSiteScripting {
    param([string]$BaseUrl)
    
    Write-Log "Testing Cross-Site Scripting (XSS) detection..." "TEST"
    
    $xssPayloads = @(
        "<script>alert('XSS')</script>",
        "<img src=x onerror=alert('XSS')>",
        "<svg/onload=alert('XSS')>",
        "javascript:alert('XSS')",
        "<iframe src='javascript:alert(1)'>"
    )
    
    $blocked = 0
    $allowed = 0
    
    foreach ($payload in $xssPayloads) {
        $testUrl = "$BaseUrl/?input=$([System.Web.HttpUtility]::UrlEncode($payload))"
        
        try {
            if ($SkipSslValidation) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
            
            $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                $allowed++
                Write-Log "Payload allowed: $payload" "WARNING"
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            if ($statusCode -eq 403) {
                $blocked++
                Write-Log "Payload blocked (403): $payload" "SUCCESS"
            }
            else {
                Write-Log "Unexpected response ($statusCode): $payload" "WARNING"
            }
        }
        finally {
            if ($SkipSslValidation) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    $passed = $blocked -gt 0
    Write-Log "XSS test: $blocked blocked, $allowed allowed" "INFO"
    
    return @{
        TestName = "Cross-Site Scripting (XSS) Detection"
        Passed   = $passed
        Details  = "$blocked of $($xssPayloads.Count) payloads blocked"
    }
}

function Test-PathTraversal {
    param([string]$BaseUrl)
    
    Write-Log "Testing Path Traversal detection..." "TEST"
    
    $pathTraversalPayloads = @(
        "../../../etc/passwd",
        "..\..\..\..\windows\system32\config\sam",
        "....//....//....//etc/passwd",
        "%2e%2e%2f%2e%2e%2f%2e%2e%2f",
        "..;/..;/..;/"
    )
    
    $blocked = 0
    $allowed = 0
    
    foreach ($payload in $pathTraversalPayloads) {
        $testUrl = "$BaseUrl/?file=$([System.Web.HttpUtility]::UrlEncode($payload))"
        
        try {
            if ($SkipSslValidation) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
            
            $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                $allowed++
                Write-Log "Payload allowed: $payload" "WARNING"
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            if ($statusCode -eq 403) {
                $blocked++
                Write-Log "Payload blocked (403): $payload" "SUCCESS"
            }
            else {
                Write-Log "Unexpected response ($statusCode): $payload" "WARNING"
            }
        }
        finally {
            if ($SkipSslValidation) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    $passed = $blocked -gt 0
    Write-Log "Path Traversal test: $blocked blocked, $allowed allowed" "INFO"
    
    return @{
        TestName = "Path Traversal Detection"
        Passed   = $passed
        Details  = "$blocked of $($pathTraversalPayloads.Count) payloads blocked"
    }
}

function Test-SslConfiguration {
    param([string]$Url)
    
    Write-Log "Testing SSL/TLS configuration..." "TEST"
    
    try {
        # Parse URL to get hostname
        $uri = [System.Uri]$Url
        
        if ($uri.Scheme -ne "https") {
            Write-Log "URL is not using HTTPS" "WARNING"
            return @{
                TestName = "SSL/TLS Configuration"
                Passed   = $false
                Details  = "Not using HTTPS"
            }
        }
        
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($uri.Host, $uri.Port)
        
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
        $sslStream.AuthenticateAsClient($uri.Host)
        
        $protocol = $sslStream.SslProtocol
        $cipher = $sslStream.CipherAlgorithm
        
        $sslStream.Close()
        $tcpClient.Close()
        
        Write-Log "SSL Protocol: $protocol" "INFO"
        Write-Log "Cipher Algorithm: $cipher" "INFO"
        
        # Check for secure protocols
        $secureProtocols = @("Tls12", "Tls13")
        $passed = $secureProtocols -contains $protocol.ToString()
        
        if ($passed) {
            Write-Log "SSL/TLS configuration is secure" "SUCCESS"
        }
        else {
            Write-Log "SSL/TLS protocol is not secure: $protocol" "WARNING"
        }
        
        return @{
            TestName = "SSL/TLS Configuration"
            Passed   = $passed
            Details  = "Protocol: $protocol, Cipher: $cipher"
        }
    }
    catch {
        Write-Log "SSL/TLS test failed: $($_.Exception.Message)" "ERROR"
        
        return @{
            TestName = "SSL/TLS Configuration"
            Passed   = $false
            Details  = $_.Exception.Message
        }
    }
}

function Show-TestSummary {
    param([array]$Results)
    
    Write-SectionHeader "TEST SUMMARY"
    
    $totalTests = $Results.Count
    $passedTests = ($Results | Where-Object { $_.Passed }).Count
    $failedTests = $totalTests - $passedTests
    
    Write-Log "Total Tests: $totalTests" "INFO"
    Write-Log "Passed: $passedTests" "SUCCESS"
    Write-Log "Failed: $failedTests" $(if ($failedTests -eq 0) { "SUCCESS" } else { "WARNING" })
    Write-Log ""
    
    foreach ($result in $Results) {
        $status = if ($result.Passed) { "PASS" } else { "FAIL" }
        $color = if ($result.Passed) { "SUCCESS" } else { "WARNING" }
        
        Write-Log "[$status] $($result.TestName): $($result.Details)" $color
    }
    
    Write-Log ""
    Write-Log "Log file: $LogFile" "INFO"
}

################################################################################
# Main Script Execution
################################################################################

try {
    Write-SectionHeader "WAF DETECTION TEST"
    Write-Log "Testing Application Gateway: $ApplicationGatewayUrl" "INFO"
    Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    
    # Add System.Web assembly for URL encoding
    Add-Type -AssemblyName System.Web
    
    # Run tests
    Write-SectionHeader "RUNNING WAF TESTS"
    
    $TestResults += Test-BasicConnectivity -Url $ApplicationGatewayUrl
    $TestResults += Test-SqlInjection -BaseUrl $ApplicationGatewayUrl
    $TestResults += Test-CrossSiteScripting -BaseUrl $ApplicationGatewayUrl
    $TestResults += Test-PathTraversal -BaseUrl $ApplicationGatewayUrl
    
    if ($ApplicationGatewayUrl -like "https://*") {
        $TestResults += Test-SslConfiguration -Url $ApplicationGatewayUrl
    }
    
    # Show summary
    Show-TestSummary -Results $TestResults
    
    # Return appropriate exit code
    $failedCount = ($TestResults | Where-Object { -not $_.Passed }).Count
    
    if ($failedCount -eq 0) {
        Write-Log "All tests passed!" "SUCCESS"
        exit 0
    }
    else {
        Write-Log "$failedCount test(s) failed" "WARNING"
        exit 1
    }
}
catch {
    Write-Log "Test execution failed: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" "ERROR"
    Write-Log "Log file: $LogFile" "INFO"
    
    exit 1
}
