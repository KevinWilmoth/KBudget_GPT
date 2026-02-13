################################################################################
# Set-AuditLogRetention.Tests.ps1
#
# Purpose: Pester tests for Set-AuditLogRetention.ps1 script
# Features:
#   - Validates script parameters
#   - Tests policy file loading
#   - Validates helper functions
#   - Tests compliance checking logic
#
# Prerequisites:
#   - Pester module (Install-Module -Name Pester)
#
# Usage:
#   Invoke-Pester -Path .\Set-AuditLogRetention.Tests.ps1
#
################################################################################

BeforeAll {
    # Define script path
    $scriptPath = Join-Path $PSScriptRoot "Set-AuditLogRetention.ps1"
    $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
    
    # Verify files exist
    if (-not (Test-Path $scriptPath)) {
        throw "Script not found: $scriptPath"
    }
    
    if (-not (Test-Path $policyPath)) {
        throw "Policy file not found: $policyPath"
    }
}

Describe "Set-AuditLogRetention Script" {
    
    Context "Script File Validation" {
        
        It "Should exist in the expected location" {
            $scriptPath = Join-Path $PSScriptRoot "Set-AuditLogRetention.ps1"
            Test-Path $scriptPath | Should -Be $true
        }
        
        It "Should have valid PowerShell syntax" {
            $scriptPath = Join-Path $PSScriptRoot "Set-AuditLogRetention.ps1"
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }
        
        It "Should have required parameters defined" {
            $scriptPath = Join-Path $PSScriptRoot "Set-AuditLogRetention.ps1"
            $content = Get-Content $scriptPath -Raw
            
            $content | Should -Match 'param\s*\('
            $content | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true\)\]'
            $content | Should -Match '\$Environment'
        }
    }
    
    Context "Policy File Validation" {
        
        It "Should exist" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            Test-Path $policyPath | Should -Be $true
        }
        
        It "Should contain valid JSON" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            { Get-Content $policyPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should have required policy sections" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.PSObject.Properties.Name | Should -Contain 'version'
            $policy.PSObject.Properties.Name | Should -Contain 'complianceFrameworks'
            $policy.PSObject.Properties.Name | Should -Contain 'retentionPolicies'
            $policy.PSObject.Properties.Name | Should -Contain 'resourcePolicies'
            $policy.PSObject.Properties.Name | Should -Contain 'securityPolicies'
        }
        
        It "Should define policies for all resource types" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.resourcePolicies.PSObject.Properties.Name | Should -Contain 'appService'
            $policy.resourcePolicies.PSObject.Properties.Name | Should -Contain 'sqlDatabase'
            $policy.resourcePolicies.PSObject.Properties.Name | Should -Contain 'storageAccount'
            $policy.resourcePolicies.PSObject.Properties.Name | Should -Contain 'functionApp'
            $policy.resourcePolicies.PSObject.Properties.Name | Should -Contain 'keyVault'
        }
        
        It "Should have audit log retention >= 180 days" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.retentionPolicies.default.auditLogs.retentionDays | Should -BeGreaterOrEqual 180
        }
        
        It "Should have critical audit log retention >= 365 days" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.retentionPolicies.default.criticalAuditLogs.retentionDays | Should -BeGreaterOrEqual 365
        }
        
        It "Should include all compliance frameworks" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.complianceFrameworks | Should -Contain 'SOC 2 Type II'
            $policy.complianceFrameworks | Should -Contain 'ISO 27001'
            $policy.complianceFrameworks | Should -Contain 'GDPR'
            $policy.complianceFrameworks | Should -Contain 'HIPAA'
            $policy.complianceFrameworks | Should -Contain 'PCI DSS'
        }
    }
    
    Context "App Service Log Categories" {
        
        It "Should configure AppServiceAuditLogs with 180+ day retention" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $auditLog = $policy.resourcePolicies.appService.logs | Where-Object { $_.category -eq 'AppServiceAuditLogs' }
            $auditLog | Should -Not -BeNullOrEmpty
            $auditLog.enabled | Should -Be $true
            $auditLog.retentionDays | Should -BeGreaterOrEqual 180
        }
        
        It "Should configure AppServiceIPSecAuditLogs with 180+ day retention" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $secLog = $policy.resourcePolicies.appService.logs | Where-Object { $_.category -eq 'AppServiceIPSecAuditLogs' }
            $secLog | Should -Not -BeNullOrEmpty
            $secLog.enabled | Should -Be $true
            $secLog.retentionDays | Should -BeGreaterOrEqual 180
        }
        
        It "Should enable all required log categories" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $requiredCategories = @(
                'AppServiceHTTPLogs',
                'AppServiceConsoleLogs',
                'AppServiceAppLogs',
                'AppServiceAuditLogs',
                'AppServiceIPSecAuditLogs',
                'AppServicePlatformLogs'
            )
            
            $configuredCategories = $policy.resourcePolicies.appService.logs | Select-Object -ExpandProperty category
            
            foreach ($category in $requiredCategories) {
                $configuredCategories | Should -Contain $category
            }
        }
    }
    
    Context "SQL Database Log Categories" {
        
        It "Should enable all critical SQL log categories" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $requiredCategories = @(
                'Errors',
                'Deadlocks',
                'Timeouts'
            )
            
            $configuredCategories = $policy.resourcePolicies.sqlDatabase.logs | Select-Object -ExpandProperty category
            
            foreach ($category in $requiredCategories) {
                $configuredCategories | Should -Contain $category
            }
        }
        
        It "Should have 90+ day retention for all SQL logs" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.resourcePolicies.sqlDatabase.logs | ForEach-Object {
                $_.retentionDays | Should -BeGreaterOrEqual 90
            }
        }
    }
    
    Context "Storage Account Log Categories" {
        
        It "Should configure StorageDelete with 180+ day retention" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $deleteLog = $policy.resourcePolicies.storageAccount.logs | Where-Object { $_.category -eq 'StorageDelete' }
            $deleteLog | Should -Not -BeNullOrEmpty
            $deleteLog.enabled | Should -Be $true
            $deleteLog.retentionDays | Should -BeGreaterOrEqual 180
        }
        
        It "Should enable all storage operation categories" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $requiredCategories = @(
                'StorageRead',
                'StorageWrite',
                'StorageDelete'
            )
            
            $configuredCategories = $policy.resourcePolicies.storageAccount.logs | Select-Object -ExpandProperty category
            
            foreach ($category in $requiredCategories) {
                $configuredCategories | Should -Contain $category
            }
        }
    }
    
    Context "Key Vault Log Categories" {
        
        It "Should configure AuditEvent with 365 day retention" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $auditEvent = $policy.resourcePolicies.keyVault.logs | Where-Object { $_.category -eq 'AuditEvent' }
            $auditEvent | Should -Not -BeNullOrEmpty
            $auditEvent.enabled | Should -Be $true
            $auditEvent.retentionDays | Should -Be 365
        }
        
        It "Should configure AzurePolicyEvaluationDetails with 180+ day retention" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policyLog = $policy.resourcePolicies.keyVault.logs | Where-Object { $_.category -eq 'AzurePolicyEvaluationDetails' }
            $policyLog | Should -Not -BeNullOrEmpty
            $policyLog.enabled | Should -Be $true
            $policyLog.retentionDays | Should -BeGreaterOrEqual 180
        }
    }
    
    Context "Function App Log Categories" {
        
        It "Should enable FunctionAppLogs" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $functionLogs = $policy.resourcePolicies.functionApp.logs | Where-Object { $_.category -eq 'FunctionAppLogs' }
            $functionLogs | Should -Not -BeNullOrEmpty
            $functionLogs.enabled | Should -Be $true
            $functionLogs.retentionDays | Should -BeGreaterOrEqual 90
        }
    }
    
    Context "Security Policies" {
        
        It "Should enable encryption" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.securityPolicies.encryption.enabled | Should -Be $true
        }
        
        It "Should require access approval" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.securityPolicies.accessControl.approvalRequired | Should -Be $true
        }
        
        It "Should enable monitoring alerts" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.securityPolicies.monitoring.alertOnRetentionChange | Should -Be $true
            $policy.securityPolicies.monitoring.alertOnDeletionAttempt | Should -Be $true
        }
        
        It "Should enable backup and archival" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.securityPolicies.backup.archiveToStorage | Should -Be $true
            $policy.securityPolicies.backup.archiveAfterDays | Should -BeGreaterOrEqual 90
        }
    }
    
    Context "Validation Rules" {
        
        It "Should enforce minimum retention of 90 days" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.validationRules.minimumRetentionDays | Should -BeGreaterOrEqual 90
        }
        
        It "Should enforce audit logs minimum retention of 180 days" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.validationRules.auditLogsMinimumRetention | Should -BeGreaterOrEqual 180
        }
        
        It "Should enforce critical audit logs minimum retention of 365 days" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.validationRules.criticalAuditLogsMinimumRetention | Should -BeGreaterOrEqual 365
        }
        
        It "Should require all resources to have diagnostics" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.validationRules.allResourcesMustHaveDiagnostics | Should -Be $true
        }
    }
    
    Context "Compliance Requirements" {
        
        It "Should meet SOC 2 retention requirements" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.complianceRequirements.soc2.minimumRetention | Should -BeGreaterOrEqual 365
        }
        
        It "Should meet ISO 27001 retention requirements" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.complianceRequirements.iso27001.minimumRetention | Should -BeGreaterOrEqual 180
        }
        
        It "Should meet GDPR retention requirements" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.complianceRequirements.gdpr.minimumRetention | Should -BeGreaterOrEqual 90
        }
        
        It "Should meet HIPAA retention requirements" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.complianceRequirements.hipaa.minimumRetention | Should -BeGreaterOrEqual 730
        }
        
        It "Should meet PCI DSS retention requirements" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.complianceRequirements.pciDss.minimumRetention | Should -BeGreaterOrEqual 365
        }
    }
    
    Context "Review Schedule" {
        
        It "Should have quarterly review frequency" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.reviewSchedule.frequency | Should -Be 'quarterly'
        }
        
        It "Should define reviewer and approver" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.reviewSchedule.reviewer | Should -Not -BeNullOrEmpty
            $policy.reviewSchedule.approver | Should -Not -BeNullOrEmpty
        }
        
        It "Should have next review date defined" {
            $policyPath = Join-Path $PSScriptRoot "audit-retention-policy.json"
            $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
            
            $policy.reviewSchedule.nextReview | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Documentation Files" {
    
    Context "Compliance Validation Guide" {
        
        It "Should exist" {
            $guidePath = Join-Path $PSScriptRoot "COMPLIANCE-VALIDATION-GUIDE.md"
            Test-Path $guidePath | Should -Be $true
        }
        
        It "Should contain required sections" {
            $guidePath = Join-Path $PSScriptRoot "COMPLIANCE-VALIDATION-GUIDE.md"
            $content = Get-Content $guidePath -Raw
            
            $content | Should -Match '## Prerequisites'
            $content | Should -Match '## Validation Procedures'
            $content | Should -Match '## Compliance Check Steps'
            $content | Should -Match '## Remediation Procedures'
            $content | Should -Match '## Report Generation'
            $content | Should -Match '## Security Team Review'
            $content | Should -Match '## Troubleshooting'
        }
        
        It "Should include PowerShell command examples" {
            $guidePath = Join-Path $PSScriptRoot "COMPLIANCE-VALIDATION-GUIDE.md"
            $content = Get-Content $guidePath -Raw
            
            $content | Should -Match '```powershell'
            $content | Should -Match 'Set-AuditLogRetention\.ps1'
        }
    }
    
    Context "Compliance Documentation" {
        
        It "Should exist in docs folder" {
            $docsPath = Join-Path $PSScriptRoot "..\..\..\docs\COMPLIANCE-DOCUMENTATION.md"
            Test-Path $docsPath | Should -Be $true
        }
        
        It "Should document all compliance frameworks" {
            $docsPath = Join-Path $PSScriptRoot "..\..\..\docs\COMPLIANCE-DOCUMENTATION.md"
            $content = Get-Content $docsPath -Raw
            
            $content | Should -Match 'SOC 2'
            $content | Should -Match 'ISO 27001'
            $content | Should -Match 'GDPR'
            $content | Should -Match 'HIPAA'
            $content | Should -Match 'PCI DSS'
        }
        
        It "Should document all resource log categories" {
            $docsPath = Join-Path $PSScriptRoot "..\..\..\docs\COMPLIANCE-DOCUMENTATION.md"
            $content = Get-Content $docsPath -Raw
            
            $content | Should -Match 'App Service'
            $content | Should -Match 'SQL Database'
            $content | Should -Match 'Storage Account'
            $content | Should -Match 'Azure Functions'
            $content | Should -Match 'Key Vault'
        }
        
        It "Should include retention policy summary" {
            $docsPath = Join-Path $PSScriptRoot "..\..\..\docs\COMPLIANCE-DOCUMENTATION.md"
            $content = Get-Content $docsPath -Raw
            
            $content | Should -Match '## Retention Policy Summary'
            $content | Should -Match 'Standard Logs'
            $content | Should -Match 'Audit Logs'
            $content | Should -Match 'Critical Audit Logs'
        }
        
        It "Should include security policies" {
            $docsPath = Join-Path $PSScriptRoot "..\..\..\docs\COMPLIANCE-DOCUMENTATION.md"
            $content = Get-Content $docsPath -Raw
            
            $content | Should -Match '## Security Policies'
            $content | Should -Match 'Encryption'
            $content | Should -Match 'Access Control'
            $content | Should -Match 'Monitoring and Alerting'
        }
    }
}
