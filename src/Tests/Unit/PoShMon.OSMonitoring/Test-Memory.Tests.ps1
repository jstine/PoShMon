$rootPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ('..\..\..\') -Resolve
Remove-Module PoShMon -ErrorAction SilentlyContinue
Import-Module (Join-Path $rootPath -ChildPath "PoShMon.psd1") -Verbose
<#$rootPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ('..\..\..\') -Resolve
$sutFileName = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests", "")
$sutFilePath = Join-Path $rootPath -ChildPath "Functions\PoShMon.OSMonitoring\$sutFileName" 
. $sutFilePath
#>

class ServerMemoryMock {
    [string]$PSComputerName
    [UInt64]$TotalVisibleMemorySize
    [UInt64]$FreePhysicalMemory

    ServerMemoryMock ([string]$NewPSComputerName, [UInt64]$NewTotalVisibleMemorySize, [UInt64]$NewFreePhysicalMemory) {
        $this.PSComputerName = $NewPSComputerName;
        $this.TotalVisibleMemorySize = $NewTotalVisibleMemorySize;
        $this.FreePhysicalMemory = $NewFreePhysicalMemory;
    }
}

Describe "Test-Memory" {
    It "Should throw an exception if no OperatingSystem configuration is set" {
    
        $poShMonConfiguration = New-PoShMonConfiguration { }

        { Test-Memory $poShMonConfiguration } | Should throw
    }

    It "Should return a matching output structure" {
    
        Mock -CommandName Get-WmiObject -MockWith {
            return [ServerMemoryMock]::new('Server1', 8312456, 2837196)
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-Memory $poShMonConfiguration

        $actual.Keys.Count | Should Be 5
        $actual.ContainsKey("NoIssuesFound") | Should Be $true
        $actual.ContainsKey("OutputHeaders") | Should Be $true
        $actual.ContainsKey("OutputValues") | Should Be $true
        $actual.ContainsKey("SectionHeader") | Should Be $true
        $actual.ContainsKey("ElapsedTime") | Should Be $true
        $headers = $actual.OutputHeaders
        $headers.Keys.Count | Should Be 4
        $values1 = $actual.OutputValues[0]
        $values1.Keys.Count | Should Be 5
        $values1.ContainsKey("ServerName") | Should Be $true
        $values1.ContainsKey("TotalMemory") | Should Be $true
        $values1.ContainsKey("FreeMemory") | Should Be $true
        $values1.ContainsKey("FreeSpacePerc") | Should Be $true
        $values1.ContainsKey("Highlight") | Should Be $true
    }

    It "Should not warn on space above threshold" {

        Mock -CommandName Get-WmiObject -MockWith {
            return [ServerMemoryMock]::new('Server1', 8312456, 2837196)
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'localhost'
                        OperatingSystem
                    }

        $actual = Test-Memory $poShMonConfiguration
        
        $actual.NoIssuesFound | Should Be $true

        $actual.OutputValues.GroupOutputValues.Highlight.Count | Should Be 0
    }

    It "Should warn on space below threshold" {
        
        Mock -CommandName Get-WmiObject -MockWith {
            return [ServerMemoryMock]::new('TheServer', 8312456, 10000)
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'TheServer'
                        OperatingSystem
                    }

        $actual = Test-Memory $poShMonConfiguration
        
        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues.Highlight.Count | Should Be 1
        $actual.OutputValues.Highlight | Should Be 'FreeMemory'
    }

    It "Should use the configuration threshold properly" {
        
        $memory = 8312456*0.5

        Mock -CommandName Get-WmiObject -MockWith {
            return [ServerMemoryMock]::new('Server1', 8312456, $memory)
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'localhost'
                        OperatingSystem -FreeMemoryThreshold 51
                    }

        $actual = Test-Memory $poShMonConfiguration
        
        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues.Highlight.Count | Should Be 1
        $actual.OutputValues.Highlight | Should Be 'FreeMemory'
    }
}