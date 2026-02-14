# WAF Configuration Guide

This guide provides detailed information about configuring and managing the Web Application Firewall (WAF) for Azure Application Gateway.

## Table of Contents

- [Overview](#overview)
- [WAF Modes](#waf-modes)
- [OWASP Rule Sets](#owasp-rule-sets)
- [Custom Rules](#custom-rules)
- [Exclusions](#exclusions)
- [Policy Settings](#policy-settings)
- [Common Attack Protection](#common-attack-protection)
- [Tuning WAF](#tuning-waf)
- [Monitoring WAF](#monitoring-waf)

## Overview

The Web Application Firewall (WAF) protects web applications from common web exploits and vulnerabilities. It provides centralized protection using the OWASP (Open Web Application Security Project) Core Rule Set.

### Key Features

- **OWASP Core Rule Set**: Industry-standard protection against web attacks
- **Detection and Prevention Modes**: Flexible operation modes
- **Custom Rules**: Create application-specific protection rules
- **Exclusions**: Fine-tune rules to reduce false positives
- **Logging**: Comprehensive logging for security analysis

## WAF Modes

The WAF can operate in two modes:

### Detection Mode

- **Behavior**: Monitors and logs threats without blocking
- **Use Case**: Development, staging, and initial production deployment
- **Advantages**:
  - No risk of blocking legitimate traffic
  - Allows thorough testing before enabling Prevention mode
  - Useful for tuning rules and creating exclusions
- **Disadvantages**:
  - Does not provide active protection
  - Malicious requests reach the backend

**Recommended for**: Development and Staging environments

```powershell
# Set WAF to Detection mode
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-dev-appgw-waf-policy" `
    -ResourceGroupName "kbudget-dev-rg"

$wafPolicy.PolicySettings.Mode = "Detection"
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

### Prevention Mode

- **Behavior**: Actively blocks detected threats
- **Use Case**: Production environments after tuning
- **Advantages**:
  - Provides active protection against attacks
  - Blocks malicious requests before reaching backend
  - Industry best practice for production
- **Disadvantages**:
  - May block legitimate traffic if not properly tuned
  - Requires careful monitoring and tuning

**Recommended for**: Production environment (after thorough testing)

```powershell
# Set WAF to Prevention mode
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-prod-appgw-waf-policy" `
    -ResourceGroupName "kbudget-prod-rg"

$wafPolicy.PolicySettings.Mode = "Prevention"
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

## OWASP Rule Sets

The WAF uses OWASP (Open Web Application Security Project) Core Rule Set (CRS) to protect against common vulnerabilities.

### Supported Versions

- **OWASP 3.0**: Older version, less comprehensive
- **OWASP 3.1**: Improved detection, fewer false positives
- **OWASP 3.2**: Latest version, most comprehensive (recommended)

**Default**: OWASP 3.2 (configured in templates)

### Rule Categories

The OWASP CRS includes rules for:

1. **SQL Injection** (SQLi)
   - Detects SQL injection attempts
   - Protects database queries
   - Rule Group: 942xxx

2. **Cross-Site Scripting** (XSS)
   - Detects JavaScript injection
   - Protects against stored and reflected XSS
   - Rule Group: 941xxx

3. **Local File Inclusion** (LFI)
   - Detects file path traversal
   - Protects file system access
   - Rule Group: 930xxx

4. **Remote File Inclusion** (RFI)
   - Detects remote file inclusion attempts
   - Prevents code execution from remote sources
   - Rule Group: 931xxx

5. **Remote Code Execution** (RCE)
   - Detects command injection
   - Prevents arbitrary code execution
   - Rule Group: 932xxx

6. **PHP Injection**
   - Detects PHP-specific attacks
   - Protects PHP applications
   - Rule Group: 933xxx

7. **Session Fixation**
   - Detects session hijacking attempts
   - Protects session management
   - Rule Group: 943xxx

8. **Protocol Attacks**
   - Detects HTTP protocol violations
   - Enforces valid HTTP requests
   - Rule Group: 920xxx

9. **Request Smuggling**
   - Detects HTTP request smuggling
   - Prevents cache poisoning
   - Rule Group: 921xxx

### Viewing Active Rules

```powershell
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-dev-appgw-waf-policy" `
    -ResourceGroupName "kbudget-dev-rg"

# View rule sets
$wafPolicy.ManagedRules.ManagedRuleSets
```

## Custom Rules

Custom rules allow you to create application-specific protection beyond OWASP rules.

### Rule Priority

- Custom rules are evaluated before managed rules
- Priority determines evaluation order (lower = higher priority)
- Priority range: 1-100

### Rule Types

1. **Rate Limiting**: Limit requests from an IP address
2. **Geo-Filtering**: Block/allow traffic from specific countries
3. **Custom Match Rules**: Match specific patterns in requests

### Example: Rate Limiting

Limit requests to 100 per minute from a single IP:

```powershell
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-dev-appgw-waf-policy" `
    -ResourceGroupName "kbudget-dev-rg"

# Create rate limit rule
$rateLimitRule = New-AzApplicationGatewayFirewallCustomRule `
    -Name "RateLimitRule" `
    -Priority 10 `
    -RuleType RateLimitRule `
    -RateLimitDuration OneMin `
    -RateLimitThreshold 100 `
    -Action Block `
    -MatchCondition $matchCondition

# Add to policy
$wafPolicy.CustomRules.Add($rateLimitRule)
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

### Example: Block Specific User-Agent

Block requests with suspicious user agents:

```powershell
# Create match condition
$matchCondition = New-AzApplicationGatewayFirewallMatchVariable `
    -VariableName RequestHeaders `
    -Selector "User-Agent"

$condition = New-AzApplicationGatewayFirewallCondition `
    -MatchVariable $matchCondition `
    -Operator Contains `
    -MatchValue @("sqlmap", "nikto", "nmap") `
    -NegationCondition $false

# Create custom rule
$blockRule = New-AzApplicationGatewayFirewallCustomRule `
    -Name "BlockMaliciousUserAgents" `
    -Priority 5 `
    -RuleType MatchRule `
    -MatchCondition $condition `
    -Action Block

# Add to policy
$wafPolicy.CustomRules.Add($blockRule)
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

## Exclusions

Exclusions help reduce false positives by excluding specific request elements from WAF inspection.

### When to Use Exclusions

- Legitimate traffic is being blocked
- Known safe parameters trigger WAF rules
- After thorough analysis of WAF logs

### Exclusion Scopes

1. **Request Header**: Exclude specific headers
2. **Request Cookie**: Exclude cookies
3. **Request Body**: Exclude POST body parameters
4. **Request Args**: Exclude query string parameters

### Example: Exclude Query Parameter

Exclude a specific query parameter from SQL injection checks:

```powershell
$wafPolicy = Get-AzApplicationGatewayFirewallPolicy `
    -Name "kbudget-dev-appgw-waf-policy" `
    -ResourceGroupName "kbudget-dev-rg"

# Create exclusion for specific parameter
$exclusion = New-AzApplicationGatewayFirewallExclusion `
    -MatchVariable "RequestArgNames" `
    -SelectorMatchOperator "Equals" `
    -Selector "search_query"

# Apply to specific rule group (SQL Injection)
$ruleGroupOverride = New-AzApplicationGatewayFirewallPolicyManagedRuleOverride `
    -RuleId "942100" `
    -State "Disabled"

$managedRuleGroup = New-AzApplicationGatewayFirewallPolicyManagedRuleGroupOverride `
    -RuleGroupName "SQLI" `
    -Rule $ruleGroupOverride

# Update policy
$wafPolicy.ManagedRules.Exclusions.Add($exclusion)
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

### Best Practices for Exclusions

1. **Be Specific**: Exclude only what's necessary
2. **Document**: Keep record of why exclusions were added
3. **Review Regularly**: Periodically review if exclusions are still needed
4. **Test**: Validate exclusions don't create security gaps
5. **Limit Scope**: Apply exclusions to specific rules, not globally

## Policy Settings

### Request Body Inspection

Configure request body inspection limits:

```powershell
$wafPolicy.PolicySettings.RequestBodyCheck = $true
$wafPolicy.PolicySettings.MaxRequestBodySizeInKb = 128  # Max 128 KB
$wafPolicy.PolicySettings.FileUploadLimitInMb = 100     # Max 100 MB
Set-AzApplicationGatewayFirewallPolicy -ApplicationGatewayFirewallPolicy $wafPolicy
```

**Recommendations**:
- Enable request body inspection for POST requests
- Set size limits based on application requirements
- Monitor for requests exceeding limits

## Common Attack Protection

### SQL Injection Protection

**What it protects**:
- Database query manipulation
- Unauthorized data access
- Data theft or modification

**Example blocked requests**:
```
/?id=' OR '1'='1
/?user=admin'--
/?id=1 UNION SELECT password FROM users
```

**OWASP Rules**: 942xxx series

### Cross-Site Scripting (XSS) Protection

**What it protects**:
- JavaScript injection
- Cookie theft
- Phishing attacks

**Example blocked requests**:
```
/?name=<script>alert('XSS')</script>
/?comment=<img src=x onerror=alert(1)>
/?input=<svg/onload=alert('XSS')>
```

**OWASP Rules**: 941xxx series

### Path Traversal Protection

**What it protects**:
- File system access
- Reading sensitive files
- Directory traversal

**Example blocked requests**:
```
/?file=../../../etc/passwd
/?path=..\..\..\..\windows\system32\config\sam
```

**OWASP Rules**: 930xxx series

### Command Injection Protection

**What it protects**:
- OS command execution
- System compromise
- Arbitrary code execution

**Example blocked requests**:
```
/?cmd=; ls -la
/?exec=| cat /etc/passwd
```

**OWASP Rules**: 932xxx series

## Tuning WAF

### Initial Deployment

1. **Deploy in Detection Mode**
   ```powershell
   # Start with Detection mode
   $wafPolicy.PolicySettings.Mode = "Detection"
   ```

2. **Monitor for 1-2 Weeks**
   - Review WAF logs daily
   - Identify false positives
   - Document legitimate blocked requests

3. **Create Exclusions**
   - Add exclusions for false positives
   - Test exclusions thoroughly
   - Document each exclusion

4. **Enable Prevention Mode**
   ```powershell
   # Switch to Prevention mode after tuning
   $wafPolicy.PolicySettings.Mode = "Prevention"
   ```

### Analyzing WAF Logs

Query WAF logs in Log Analytics:

```kusto
// Find all blocked requests
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, Message
| order by TimeGenerated desc

// Top blocked rules
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize Count = count() by ruleId_s, Message
| order by Count desc

// Blocked requests by IP
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize Count = count() by clientIp_s
| order by Count desc
```

### Common False Positive Scenarios

1. **Rich Text Editors**: May trigger XSS rules
   - **Solution**: Exclude specific POST parameters
   
2. **Search Queries**: May trigger SQL injection rules
   - **Solution**: Exclude search parameters or use parameterized queries
   
3. **JSON APIs**: May trigger various rules
   - **Solution**: Validate JSON schema, exclude Content-Type application/json
   
4. **File Uploads**: May exceed size limits
   - **Solution**: Adjust file upload limits

## Monitoring WAF

### Key Metrics

Monitor these metrics in Azure Portal:

1. **Firewall Requests**: Total requests processed by WAF
2. **Blocked Requests**: Requests blocked by WAF
3. **Blocked Requests by Rule**: Distribution of blocks by rule
4. **Threat Distribution**: Types of attacks detected

### Setting Up Alerts

Create alerts for suspicious activity:

```powershell
# Alert on high number of blocked requests
$actionGroup = Get-AzActionGroup -ResourceGroupName "kbudget-dev-rg" -Name "SecurityAlerts"

$condition = New-AzMetricAlertRuleV2Criteria `
    -MetricName "ApplicationGatewayFirewallBlockedCount" `
    -TimeAggregation Total `
    -Operator GreaterThan `
    -Threshold 100

Add-AzMetricAlertRuleV2 `
    -Name "HighWAFBlocks" `
    -ResourceGroupName "kbudget-dev-rg" `
    -TargetResourceId "/subscriptions/.../applicationGateways/kbudget-dev-appgw" `
    -Condition $condition `
    -ActionGroup $actionGroup `
    -Severity 2 `
    -WindowSize (New-TimeSpan -Minutes 5) `
    -Frequency (New-TimeSpan -Minutes 5)
```

### Log Analytics Queries

Useful queries for WAF monitoring:

```kusto
// Daily attack summary
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize Attacks = count() by bin(TimeGenerated, 1d), ruleSetType_s
| render timechart

// Geographic distribution of attacks
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| extend country = tostring(split(clientIp_s, '.')[0])
| summarize Count = count() by clientIp_s
| top 10 by Count
```

## Security Best Practices

1. **Use Prevention Mode in Production**: After thorough testing
2. **Keep Rule Sets Updated**: Use latest OWASP version
3. **Regular Log Review**: Monitor WAF logs weekly
4. **Implement Custom Rules**: Add application-specific protection
5. **Minimize Exclusions**: Only exclude when absolutely necessary
6. **Test WAF Regularly**: Use Test-WAF.ps1 script monthly
7. **Document Changes**: Keep audit trail of WAF modifications
8. **Coordinate with Development**: Ensure application follows secure coding practices
9. **Enable All Logging**: Send logs to Log Analytics
10. **Set Up Alerts**: Be notified of security incidents

## Troubleshooting

### Issue: Legitimate Traffic Blocked

1. Identify the rule triggering the block from logs
2. Analyze the request to confirm it's legitimate
3. Either:
   - Modify application to avoid triggering rule
   - Create exclusion for specific parameter
4. Test thoroughly after changes
5. Document the exclusion

### Issue: No Blocks in Prevention Mode

1. Verify WAF policy is attached to Application Gateway
2. Check WAF mode is set to "Prevention"
3. Test with known malicious requests
4. Review WAF logs for "Detected" entries
5. Verify rule sets are enabled

### Issue: Performance Impact

1. Review request body size limits
2. Optimize rule exclusions
3. Consider upgrading Application Gateway SKU
4. Analyze traffic patterns for optimization

## Additional Resources

- [Azure WAF Documentation](https://docs.microsoft.com/azure/web-application-firewall/)
- [OWASP Core Rule Set](https://owasp.org/www-project-modsecurity-core-rule-set/)
- [Azure Application Gateway Best Practices](https://docs.microsoft.com/azure/application-gateway/application-gateway-best-practices)
- [Integration Guide](./INTEGRATION-GUIDE.md)
- [Main README](./README.md)
