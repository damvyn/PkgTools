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
	param([string]$Name = '*', [string]$Vendor = '*' )

	# Service info
	Write-Verbose "User = $env:UserDomain\$env:USERNAME"
	Write-Verbose "OS Build = $([system.environment]::OSVersion.Version.Build)"
	Write-Verbose "IP Address = $((Get-NetIPAddress -AddressFamily IPv4).IPAddress)"

	$UninstallRoot = @(
		"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOw6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
	)
	foreach ( $key in $UninstallRoot) {
		if (-not (Test-Path $key)) { continue }

		Get-ItemProperty -Path "$key\*" |
		Where-Object {
				($null -eq $_.SystemComponent) -and
				($null -ne $_.UninstallString) -and
				($null -ne $_.DisplayName) -and
				($_.DisplayName -like $Name) -and
				($_.Publisher -like $Vendor)
		} |
		Select-Object @{n="Vendor"; e={ $_.Publisher } },
					  @{n="Name"; e={ $_.DisplayName } },
		              @{n="Version"; e={ $_.DisplayVersion } },
					  @{n="InstallDate"; e={ $_.InstallDate } },
					  @{n="Uninstall"; e={ $_.UninstallString } }
	}
}