################################################################################
# Deployment Scripts Tests
# 
# Purpose: Validate PowerShell deployment scripts using Pester
# Framework: Pester (PowerShell testing framework)
#
# Usage:
#   Install-Module -Name Pester -Force -SkipPublisherCheck
#   Invoke-Pester -Path .\Deploy-AzureResources.Tests.ps1
#
################################################################################

BeforeAll {
    $ScriptDir = Split-Path -Parent $PSCommandPath
    $DeployScript = Join-Path $ScriptDir "Deploy-AzureResources.ps1"
    $ValidationModule = Join-Path $ScriptDir "Deployment-Validation.psm1"
    $ValidateScript = Join-Path $ScriptDir "Validate-Templates.ps1"
}

Describe "Deploy-AzureResources.ps1 Script Tests" {
    
    Context "Script File Validation" {
        It "Deploy-AzureResources.ps1 should exist" {
            Test-Path $DeployScript | Should -Be $true
        }
        
        It "Deploy-AzureResources.ps1 should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $DeployScript -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }
        
        It "Deploy-AzureResources.ps1 should contain CmdletBinding" {
            $content = Get-Content $DeployScript -Raw
            $content | Should -Match '\[CmdletBinding\(\)\]'
        }
        
        It "Deploy-AzureResources.ps1 should have Environment parameter" {
            $content = Get-Content $DeployScript -Raw
            $content | Should -Match 'param\s*\('
            $content | Should -Match '\$Environment'
        }
    }
    
    Context "Required Functions Validation" {
        BeforeAll {
            $content = Get-Content $DeployScript -Raw
        }
        
        It "Should contain Test-Prerequisites function" {
            $content | Should -Match 'function Test-Prerequisites'
        }
        
        It "Should contain Deploy-ResourceGroup function" {
            $content | Should -Match 'function Deploy-ResourceGroup'
        }
        
        It "Should contain Deploy-VirtualNetwork function" {
            $content | Should -Match 'function Deploy-VirtualNetwork'
        }
        
        It "Should contain Deploy-KeyVault function" {
            $content | Should -Match 'function Deploy-KeyVault'
        }
        
        It "Should contain Deploy-StorageAccount function" {
            $content | Should -Match 'function Deploy-StorageAccount'
        }
        
        It "Should contain Deploy-CosmosDatabase function" {
            $content | Should -Match 'function Deploy-CosmosDatabase'
        }
        
        It "Should contain Deploy-CosmosContainers function" {
            $content | Should -Match 'function Deploy-CosmosContainers'
        }
        
        It "Should contain Test-CosmosContainerPrerequisites function" {
            $content | Should -Match 'function Test-CosmosContainerPrerequisites'
        }
        
        It "Should contain Test-CosmosContainers function" {
            $content | Should -Match 'function Test-CosmosContainers'
        }
        
        It "Should contain Deploy-AppService function" {
            $content | Should -Match 'function Deploy-AppService'
        }
        
        It "Should contain Deploy-AzureFunctions function" {
            $content | Should -Match 'function Deploy-AzureFunctions'
        }
        
        It "Should contain Deploy-ApplicationGateway function" {
            $content | Should -Match 'function Deploy-ApplicationGateway'
        }
        
        It "Should contain Invoke-PostDeploymentValidation function" {
            $content | Should -Match 'function Invoke-PostDeploymentValidation'
        }
        
        It "Should contain Export-DeploymentResults function" {
            $content | Should -Match 'function Export-DeploymentResults'
        }
    }
    
    Context "Error Handling Validation" {
        BeforeAll {
            $content = Get-Content $DeployScript -Raw
        }
        
        It "Should have try-catch blocks for error handling" {
            $content | Should -Match 'try\s*\{'
            $content | Should -Match 'catch\s*\{'
        }
        
        It "Should have ErrorActionPreference set" {
            $content | Should -Match '\$ErrorActionPreference\s*='
        }
        
        It "Should exit with code 1 on error" {
            $content | Should -Match 'exit 1'
        }
    }
    
    Context "Logging Validation" {
        BeforeAll {
            $content = Get-Content $DeployScript -Raw
        }
        
        It "Should have Write-Log function" {
            $content | Should -Match 'function Write-Log'
        }
        
        It "Should create log directory" {
            $content | Should -Match 'LogDir'
        }
        
        It "Should use Write-Log for deployment status" {
            $content | Should -Match 'Write-Log.*Starting'
            $content | Should -Match 'Write-Log.*Completed'
        }
    }
    
    Context "Validation Integration" {
        BeforeAll {
            $content = Get-Content $DeployScript -Raw
        }
        
        It "Should call Invoke-PostDeploymentValidation" {
            $content | Should -Match 'Invoke-PostDeploymentValidation'
        }
        
        It "Should call Export-DeploymentResults" {
            $content | Should -Match 'Export-DeploymentResults'
        }
        
        It "Should send alerts on validation failure" {
            $content | Should -Match 'Send-DeploymentAlert'
        }
        
        It "Should exit with error code if validation fails" {
            $content | Should -Match 'if \(-not \$validationPassed\)'
        }
    }
}

Describe "Deployment-Validation.psm1 Module Tests" {
    
    Context "Module File Validation" {
        It "Deployment-Validation.psm1 should exist" {
            Test-Path $ValidationModule | Should -Be $true
        }
        
        It "Deployment-Validation.psm1 should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ValidationModule -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
    
    Context "Module Functions Validation" {
        BeforeAll {
            Import-Module $ValidationModule -Force
        }
        
        AfterAll {
            Remove-Module Deployment-Validation -ErrorAction SilentlyContinue
        }
        
        It "Should export Get-DeploymentStatus function" {
            Get-Command Get-DeploymentStatus -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-ResourceGroupExists function" {
            Get-Command Test-ResourceGroupExists -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-VirtualNetworkExists function" {
            Get-Command Test-VirtualNetworkExists -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-KeyVaultExists function" {
            Get-Command Test-KeyVaultExists -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-StorageAccountExists function" {
            Get-Command Test-StorageAccountExists -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-AppServiceExists function" {
            Get-Command Test-AppServiceExists -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-FunctionAppExists function" {
            Get-Command Test-FunctionAppExists -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-DeploymentResources function" {
            Get-Command Test-DeploymentResources -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Export-DeploymentOutputs function" {
            Get-Command Export-DeploymentOutputs -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Write-DeploymentSummary function" {
            Get-Command Write-DeploymentSummary -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Send-DeploymentAlert function" {
            Get-Command Send-DeploymentAlert -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Function Parameter Validation" {
        BeforeAll {
            Import-Module $ValidationModule -Force
        }
        
        AfterAll {
            Remove-Module Deployment-Validation -ErrorAction SilentlyContinue
        }
        
        It "Test-DeploymentResources should have mandatory Environment parameter" {
            $cmd = Get-Command Test-DeploymentResources
            $envParam = $cmd.Parameters['Environment']
            $envParam | Should -Not -BeNullOrEmpty
            $envParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }
        
        It "Test-DeploymentResources should validate Environment values" {
            $cmd = Get-Command Test-DeploymentResources
            $envParam = $cmd.Parameters['Environment']
            $validateSet = $envParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain "dev"
            $validateSet.ValidValues | Should -Contain "staging"
            $validateSet.ValidValues | Should -Contain "prod"
        }
    }
}

Describe "Validate-Templates.ps1 Script Tests" {
    
    Context "Script File Validation" {
        It "Validate-Templates.ps1 should exist" {
            Test-Path $ValidateScript | Should -Be $true
        }
        
        It "Validate-Templates.ps1 should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ValidateScript -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
    
    Context "Validation Functions" {
        BeforeAll {
            $content = Get-Content $ValidateScript -Raw
        }
        
        It "Should contain Test-JsonFile function" {
            $content | Should -Match 'function Test-JsonFile'
        }
        
        It "Should contain Test-ArmTemplate function" {
            $content | Should -Match 'function Test-ArmTemplate'
        }
        
        It "Should validate template schema" {
            $content | Should -Match '\$schema'
        }
        
        It "Should validate template resources" {
            $content | Should -Match 'resources'
        }
    }
}

Describe "Integration Tests" {
    
    Context "WhatIf Mode Testing" {
        It "Deploy-AzureResources.ps1 should support WhatIf parameter" {
            $content = Get-Content $DeployScript -Raw
            $content | Should -Match '\[switch\]\$WhatIf'
        }
        
        It "WhatIf mode should prevent resource creation" {
            $content = Get-Content $DeployScript -Raw
            $content | Should -Match 'if \(\$WhatIf\)'
        }
    }
    
    Context "Output Directory Structure" {
        It "Should create logs directory structure" {
            $content = Get-Content $DeployScript -Raw
            $content | Should -Match 'LogDir'
            $content | Should -Match 'New-Item.*-ItemType Directory'
        }
        
        It "Should create outputs directory for results" {
            $content = Get-Content $DeployScript -Raw
            $content | Should -Match 'outputDir'
        }
    }
    
    Context "Deployment Results Export" {
        BeforeAll {
            $content = Get-Content $DeployScript -Raw
        }
        
        It "Should export deployment results to JSON" {
            $content | Should -Match 'ConvertTo-Json'
            $content | Should -Match 'deployment-results'
        }
        
        It "Should create latest.json file" {
            $content | Should -Match 'latest\.json'
        }
        
        It "Should include environment in output filename" {
            $content | Should -Match '\$Environment'
        }
    }
}

Describe "Alert and Error Handling Tests" {
    
    Context "Alert Mechanism" {
        BeforeAll {
            Import-Module $ValidationModule -Force
        }
        
        AfterAll {
            Remove-Module Deployment-Validation -ErrorAction SilentlyContinue
        }
        
        It "Send-DeploymentAlert should accept ValidationResults parameter" {
            $cmd = Get-Command Send-DeploymentAlert
            $cmd.Parameters.ContainsKey('ValidationResults') | Should -Be $true
        }
        
        It "Send-DeploymentAlert should support different alert levels" {
            $cmd = Get-Command Send-DeploymentAlert
            $alertParam = $cmd.Parameters['AlertLevel']
            $validateSet = $alertParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain "Info"
            $validateSet.ValidValues | Should -Contain "Warning"
            $validateSet.ValidValues | Should -Contain "Critical"
        }
    }
    
    Context "Critical Failure Handling" {
        BeforeAll {
            $content = Get-Content $DeployScript -Raw
        }
        
        It "Should send critical alert on deployment failure" {
            $content | Should -Match 'AlertLevel.*"Critical"'
        }
        
        It "Should exit with error code on validation failure" {
            $content | Should -Match 'if \(-not \$validationPassed\)'
            $content | Should -Match 'exit 1'
        }
    }
}
