function Copy-RebasedFile {
	<#
	.SYNOPSIS
		Copies a file from a path under $Base to the equivalent path under $Target,
		optionally adding or removing a filename prefix.
	.NOTES
		Renamed from "rebase-file" to use an approved PowerShell verb (Copy-*).
		An alias is kept below for backward compatibility with existing callers.
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$Source,

		[Parameter(Mandatory)]
		[string]$Base,

		[Parameter(Mandatory)]
		[string]$Target,

		[string]$Prefix,

		[ValidateSet('add', 'remove')]
		[string]$PrefixAction
	)

	if (-not (Test-Path -LiteralPath $Source)) {
		throw "Source path not found: $Source"
	}

	$targetPath = $Source -replace [regex]::Escape($Base), $Target

	if ($Prefix) {
		if ($PrefixAction -eq 'remove') {
			$targetPath = $targetPath -replace [regex]::Escape($Prefix), ''
		}
		else {
			$leaf = Split-Path -Path $targetPath -Leaf
			$targetPath = $targetPath -replace [regex]::Escape($leaf), ($Prefix + $leaf)
		}
	}

	$result = [PSCustomObject]@{
		Source = $Source
		Target = $Source
	}

	$destDir = Split-Path -Path $targetPath -Parent
	New-Item -ItemType Directory -Path $destDir -ErrorAction SilentlyContinue | Out-Null
	Copy-Item -Path $Source -Destination $targetPath -Force

	if (Test-Path -LiteralPath $targetPath) {
		$result.Target = $targetPath
	}
	else {
		Write-Warning "Failed to copy '$Source' to '$targetPath'"
	}

	return $result
}