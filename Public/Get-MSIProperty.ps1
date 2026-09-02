function Get-MSIProperty {
	<#
.SYNOPSIS
    Return msi properties

.DESCRIPTION
    Return all entries from Msi property table

.EXAMPLE
    PS C:\> Get-MSIProperty -FilePath <Path\To\MsiFile.msi>
    Return properties all entries from Property table

.INPUTS string

.OUTPUTS PSObject

.NOTES
#>
	param ( [Parameter(Mandatory)] [String] $FilePath )

	$FilePath = _resolvePath -Path $FilePath

	# open msi in read only mode
	$READONLY = 0
	$WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
	$msidb = $WindowsInstaller.OpenDatabase("$FilePath", $READONLY)

	# read property table
	$queryString = 'SELECT * FROM `Property`'
	$PropertyTable = $msidb.OpenView($queryString)
	$PropertyTable.Execute()

	# read each property name and value row-by-row
	$PROP_NAME_ID = 1
	$PROP_VALUE_ID = 2
	$Props = @{ }
	do {
		$Property = $PropertyTable.Fetch()
		If ($null -eq $Property) { break }
		$PropName = $Property.StringData($PROP_NAME_ID)
		$PropVal = $Property.StringData($PROP_VALUE_ID)
		$Props[$PropName] = $PropVal
	} while ($true)

	$msidb.Commit
	$PropertyTable.Close

	$msidb = $null
	$PropertyTable = $null
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject($WindowsInstaller) | Out-Null
	[System.GC]::Collect()
	[System.GC]::WaitForPendingFinalizers()

	# return result as ps object
	New-Object -TypeName PSObject -Property $Props
}