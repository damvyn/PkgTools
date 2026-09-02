function Get-Shortcut {
	<#
.SYNOPSIS
    Get shortcut information.
.DESCRIPTION
    Get properties of all shortcuts in StartMenu folders (Current User and All Users ).
	Parameter path allow to change search path to another folder.
	Object include next properties
    Name - shortcut name
    Path - shortcut location
    Target - target path
    Args - target arguments
    WKDir - taget working directory
.EXAMPLE
    PS C:\> Get-Shortcut
    Return properties for all shortcuts in StartMenu folder
.EXAMPLE
    PS C:\> Get-Shortcut -Path \\server\someshare -Filter *Petrel*
    Returns PsCustomObject for all lnk and url files
.EXAMPLE
    PS C:\> Get-Shortcut -Path \\server\someshare\SomeShortcut.lnk
    Returns PsCustomObject for SomeShortcut.lnk file
.INPUTS
	<String[]> Path
	<String[]> Filter
.OUTPUTS
	PSObject
.NOTES
    General notes
#>
	[CmdletBinding()]
	param([string[]]$Path, [string[]]$Filter = '*')

	BEGIN {
		$WsShell = New-Object -ComObject "Wscript.Shell"
		if ($null -eq $($Path)) {
			$Path = 'CommonPrograms', 'Programs' | Foreach-Object { [Environment]::GetFolderPath($PSItem) }
		}
	} #BEGIN
	PROCESS {
		foreach ($s_path in $Path) {
			$s_path = _resolvePath -Path $s_path

			Write-Verbose "$s_path"
			$gciArgs = @{
				'Path'    = $s_path
				'File'    = $true
				'Recurse'	= $true
			}

			$s_path = Get-Item $s_path
			if ($s_path -is 'System.IO.FileInfo') {
				Write-Verbose 'Path parameter got file'
			}
			elseif ($s_path -is 'System.IO.DirectoryInfo') {
				Write-Verbose 'Path parameter got folder'
				$gciArgs.Add('Filter', "$Filter.lnk" )
			}
			else { Write-Error 'Incorrect value in Path parameter' }

			Get-ChildItem @gciArgs | Foreach-Object {
				$Shortcut = $WsShell.CreateShortcut($_.FullName)
				[PsCustomObject][ordered]@{
					Name   = $_.Name
					Path   = $_.FullName
					Target = $Shortcut.TargetPath
					Args   = $Shortcut.Arguments
					WKDir  = $Shortcut.WorkingDirectory
					Icon   = $Shortcut.IconLocation
				}
			} #Foreach-Object
		}
	} #PROCESS
	END { $WsShell = $null }
}