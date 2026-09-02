function Set-ShortcutAccess {
    <#
    .Synopsis
        The script adds AD groups to shortcuts from pre-recreated CSV file
    .DESCRIPTION
        The script adds AD groups to shortcuts from selected CSV file
        Required parameters:
        $File - CSV file location # EXAMPLE "C:\Temp\ES.csv"
        $Path - location of shortcuts # EXAMPLE "\\server\Startmenu\"
        Optional parameters:
        $dump - create CSV file from the existing shortcuts
        Csv File EXAMPLE:
        ADDescription,ADName
        7Zip,App_000000
    .EXAMPLE
        Set-ShortcutAccess -File "C:\Temp\ES.csv" -Path "\\server\Startmenu\"
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$File,
    
        [Parameter(Mandatory = $True, Position = 2)]
        [string]$Path,
    
        [Parameter(Mandatory = $false)]
        [switch]$dump
    
    )
    
    if ($dump) {
        Get-ChildItem -Path $Path -Filter '*.lnk' -File -Recurse -Force | select-object @{n = "ADDescription"; e = { $_.baseName } }, @{n = "ADName"; e = { ((((get-acl $_.fullName).access.identityReference.value -like "*\ES_*") + @(".\ES_000000"))[0].split("\"))[1] } } | where-object { $_.ADName -ne "ES_000000" } | export-csv -path $file -noTypeInformation
        exit
    }
    
    $groups = Import-Csv -Path $file
    
    # get a list of *.lnk FileIfo objects where the file's BaseName can be found in the
    # CSV column 'Name'. Group these files on their BaseName properties
    $linkfiles = Get-ChildItem -Path $Path -Filter '*.lnk' -File -Recurse -Force |
    Where-Object { $groups.ADDescription -contains $_.BaseName } |
    Group-Object BaseName
    
    # iterate through the grouped *.lnk files
    $linkfiles | ForEach-Object {
        $baseADDescription = $_.Name  # the name of the Group is the BaseName of the files in it
        $adGroup = ($groups | Where-Object { $_.ADDescription -eq $baseADDescription }).ADName
    
        # create a new access rule
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new($adGroup, "ReadAndExecute", "Allow")
    
        $_.Group | ForEach-Object {
            # get the current ACL of the file
            $acl = Get-Acl -Path $_.FullName
            # disable inhiritance and apply
            $acl.SetAccessRuleProtection($true, $true)
                (Get-Item $_.FullName).SetAccessControl($acl)# use this method to avoid executing script with elevated privileges
            # remove company group from the ACL
            $acl = Get-Acl -Path $_.FullName
            $ruleIT = $acl.access | Where-Object { $_.IdentityReference -eq "$env:USERDOMAIN\$env:USERDOMAIN" }
    
            if ($ruleIT) {
                $acl.RemoveAccessRule($ruleIT) | Out-Null
            }
            # remove Authenticated Users group from the ACL
            $ruleAuth = $acl.access | Where-Object { $_.IdentityReference -eq "NT AUTHORITY\Authenticated Users" }
            if ($ruleAuth) {
                $acl.RemoveAccessRule($ruleAuth) | Out-Null
            }
            # add the new rule to the ACL
            $acl.SetAccessRule($rule)
                (Get-Item $_.FullName).SetAccessControl($acl)# use this method to avoid executing script with elevated privileges
            # output for logging csv
            [PsCustomObject]@{
                'Group' = $adGroup
                'File'  = $_.FullName
            }
        }
    }
}