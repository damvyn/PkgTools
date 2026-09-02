function Reset-CsvTestCase {
    <#
    .SYNOPSIS
        Reset values in Azure Devops csv files
    .DESCRIPTION
        Script sets ID to '' for each TestCase and replace Area Path with new value if it was specified
    .NOTES
        N/A
    .EXAMPLE
        Reset-CsvTestCase -FilePath C:\AzureDevops\SomeTestCase.scv
        Set Id value to '' for each step in SomeTestCase.scv
    .EXAMPLE
        ls C:\AzureDevops\*.csv | Reset-CsvTestCase -$AreaPath 'MY_NEW_PROJECT'
        Set Id value to '' for each csv file in C:\AzureDevops and replace Area Path with 'MY_NEW_PROJECT'
    #>
    [CmdletBinding(DefaultParameterSetName = "Pipeline")]
    param(
        [Parameter(ParameterSetName = 'Inline', Mandatory)]
        [string[]]$FilePath,
        [Parameter(ParameterSetName = "Pipeline", Mandatory, ValueFromPipeline )]
        [System.IO.FileSystemInfo]$InputObject,
        [string]$AreaPath = ''
    )
    BEGIN {}
    PROCESS {
        if ($FilePath) { $TargetFiles = Resolve-Path ($FilePath) }
        else { $TargetFiles = $InputObject.FullName }
    
        foreach ( $targetfile in $TargetFiles ) {
            $TestCases = Import-Csv -Path $targetfile
            foreach ( $testCase in $TestCases ) {
                $TestCase.Id = ""
                if ( $TestCase.'Work Item Type' -eq 'Test Case' ) {
                    if ($AreaPath -ne '') { $TestCase."Area Path" = $AreaPath }
                }
            }
                
            $TestCases | Export-Csv -Path $targetfile -NoTypeInformation
        }
    }
    END {}
}