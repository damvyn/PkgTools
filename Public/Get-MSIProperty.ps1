function Get-MSIProperty {
	<#
.SYNOPSIS
    Return msi properties

.DESCRIPTION
    Return all entries from Msi Property table, optionally with transforms applied.
    With -SummaryInfo returns the Summary Information stream instead
    (Title, Author, Template, RevisionNumber = PackageCode, etc.)

.PARAMETER FilePath
    Path to the msi file

.PARAMETER Transform
    One or more mst files, applied in the given order before reading

.PARAMETER SummaryInfo
    Return Summary Information properties instead of the Property table

.EXAMPLE
    PS C:\> Get-MSIProperty -FilePath <Path\To\MsiFile.msi>
    Return all entries from Property table

.EXAMPLE
    PS C:\> Get-MSIProperty -FilePath <Path\To\MsiFile.msi> -Transform <Path\To\Transform.mst>
    Return all entries from Property table with the transform applied

.EXAMPLE
    PS C:\> Get-MSIProperty -FilePath <Path\To\MsiFile.msi> -SummaryInfo
    Return Summary Information properties

.INPUTS string

.OUTPUTS PSObject

.NOTES
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)] [String] $FilePath,
		[String[]] $Transform,
		[Switch] $SummaryInfo
	)

	$FilePath = _resolvePath -Path $FilePath

	$READONLY = 0
	$WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
	$msidb = $null
	$view = $null
	try {
		# open msi in read only mode, transforms are applied in memory only
		$msidb = $WindowsInstaller.OpenDatabase($FilePath, $READONLY)
		foreach ($mst in $Transform) {
			$msidb.ApplyTransform((_resolvePath -Path $mst), 0) | Out-Null
		}

		if ($SummaryInfo) {
			# PID -> name, see "Summary Information Stream Property Set" in MSI docs
			$pids = @(
				@(1, 'Codepage'), @(2, 'Title'), @(3, 'Subject'), @(4, 'Author'), @(5, 'Keywords'), @(6, 'Comments'),
				@(7, 'Template'), @(8, 'LastSavedBy'), @(9, 'RevisionNumber'), @(11, 'LastPrinted'), @(12, 'CreateTime'),
				@(13, 'LastSaveTime'), @(14, 'PageCount'), @(15, 'WordCount'), @(16, 'CharCount'),
				@(18, 'CreatingApplication'), @(19, 'Security')
			)
			$si = $msidb.SummaryInformation(0)
			$props = [ordered]@{}
			foreach ($p in $pids) {
				$props[$p[1]] = $si.Property($p[0])
			}
			[System.Runtime.Interopservices.Marshal]::ReleaseComObject($si) | Out-Null
			return [pscustomobject]$props
		}

		# read property table row-by-row
		$view = $msidb.OpenView('SELECT `Property`, `Value` FROM `Property`')
		$view.Execute() | Out-Null
		$props = [ordered]@{}
		while ($null -ne ($record = $view.Fetch())) {
			$props[$record.StringData(1)] = $record.StringData(2)
		}
		$view.Close() | Out-Null

		[pscustomobject]$props
	}
	finally {
		foreach ($com in $view, $msidb, $WindowsInstaller) {
			if ($null -ne $com) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($com) | Out-Null }
		}
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
	}
}
