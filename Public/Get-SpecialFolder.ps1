function Get-SpecialFolder {
	<#
.SYNOPSIS
	Return special folders
.DESCRIPTION
	Script return PsCustomObjects for all special folders registered in the system. Each object has two properties:
		Special folder Name
		Literal Path
.EXAMPLE
	PS C:\Get-SpecialFolder
	Return list of PsCustomObjects for all special folders registered in the system
.INPUTS
	NULL
.OUTPUTS
	PsCustomObject
.NOTES
	Small helper function
#>
	[CmdletBinding()]
	param()

	$folders = [enum]::GetNames([System.Environment+SpecialFolder])
	Write-Verbose "Got $($folders.count) folders"
	foreach ($folder in $folders) {
		[pscustomobject]@{
			Name = $folder
			Path = [System.Environment]::GetFolderPath($folder)
		}
	} #foreach
} #function