function Get-Arp {
	<#
.SYNOPSIS
    Return list of installed software, visible in Programs and Features

.DESCRIPTION
    List contains PsCustomObjects with properties DisplayName, DisplayVersion, InstallDate,
	Publisher, UninstallString

.EXAMPLE
    PS C:\> Get-Arp
    Return properties for all entries in Programs & Features

.INPUTS N/A

.OUTPUTS PSObject

.NOTES
#>
	[CmdletBinding()]
	param([string]$DisplayName = '*', [string]$Publisher = '*' )

	# Service info
	Write-Verbose "User = $env:UserDomain\$env:USERNAME"
	Write-Verbose "OS Build = $([system.environment]::OSVersion.Version.Build)"
	Write-Verbose "IP Address = $((Get-NetIPAddress -AddressFamily IPv4).IPAddress)"

	$UninstallRoot = [System.Collections.ArrayList]@(
		"HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
		"HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
	)

	Get-ItemProperty -Path $UninstallRoot |
	Where-Object {
			($null -eq $_.SystemComponent) -and
			($null -ne $_.UninstallString) -and
			($_.DisplayName -like $DisplayName) -and
			($null -ne $_.DisplayName) -and
			($_.Publisher -like $Publisher)
	} |
	Select-Object -Property DisplayName,
	DisplayVersion,
	InstallDate,
	Publisher,
	UninstallString
}