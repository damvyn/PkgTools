function Import-AppGroup {
    <#
    .Synopsis
        Create application groups in AD from pre-recreated CSV file
    .DESCRIPTION
        Script creates application groups in AD in selected OU from selecting CSV file
        Required parameters:
        $File - CSV file location # EXAMPLE "C:\Temp\ES.csv"
        $Path - OU path location # EXAMPLE "OU=Apps,OU=Groups,OU=LAB,OU=Companies,DC=lab,DC=local"
        Csv File EXAMPLE:
        Description,Name
        7Zip,App_0000000
    .EXAMPLE
        Import-AppGroup -File ".\AppGroups.csv" -Path "OU=Apps,OU=Groups,OU=LAB,OU=Companies,DC=lab,DC=local"
        Import-AppGroup -File ".\AppGroups.csv" -Path "OU=Apps,OU=Groups,OU=LAB,OU=Companies,DC=lab,DC=local" -Local
        Import-AppGroup -File ".\AppGroups.csv" -Path "OU=Apps,OU=Groups,OU=LAB,OU=Companies,DC=lab,DC=local" -Dump
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$File,
    
        [Parameter(Mandatory = $True, Position = 2)]
        [string]$Path,
    
        [Parameter()]
        [switch]$Local,
    
        [Parameter()]
        [switch]$Dump
    
    )
    
    if ($Dump) {
        Get-ADGroup -Filter * -SearchBase $Path -Properties Name, Description |
            Select-Object -Property Name, Description |
            Export-Csv -Path $File -NoTypeInformation
            return
    }

    Get-Content $File | ConvertFrom-Csv | ForEach-Object {
        $AdParams = if ($Local) {
            @{"Name" = $_.Name;
                "Path" = $Path;
                "GroupScope" = "DomainLocal";
                "GroupCategory" = "Security";
                "Description" = $_.Description;
                "Verbose" = $true}
        }
        else {
            @{"Name" = $_.Name;
                "Path" = $Path;
                "GroupScope" = "Global";
                "GroupCategory" = "Security";
                "Description" = $_.Description;
                "Verbose" = $true}
        }
        New-ADGroup @AdParams -Verbose      
    }
}