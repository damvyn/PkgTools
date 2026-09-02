function Get-DnsHostByAddress {
	<#
.SYNOPSIS
	Return DNS name for list of provided IP addresses
.DESCRIPTION
	Script return PsCustomObjects for all IP addresses specified in parameter Address. Each property contains two properties
		IP address
		DNS Name
	If dns name cannot be extracted, its value is NULL
.EXAMPLE
	PS C:\Get-DnsHostByAddress -Address 8.8.8.8

		HostName   Address
		--------   -------
		dns.google 8.8.8.8
.INPUTS
	System.String
.OUTPUTS
	PsCustomObject
.NOTES
	Small helper function
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string[]]$Address
	)

	BEGIN {}
	PROCESS {
		foreach ($addr in $Address) {
			$props = @{'Address' = $addr }
			try {
				$result = [System.Net.Dns]::GetHostByAddress($addr)
				$props.Add('HostName', $result.HostName)
			}
			Catch {
				$props.Add('HostName', $null)
			}
			New-Object -TypeName PSObject -Property $props
		}
	}
	END {}
}