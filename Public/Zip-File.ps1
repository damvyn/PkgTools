function Zip-File {
	param (
		[Parameter(Mandatory)][string[]]$SourcePath,
		[Parameter(Mandatory)][string]$ZipPath,
		[System.IO.Compression.CompressionLevel]$CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	)

	Add-Type -Assembly System.IO.Compression.FileSystem

	$ZipPath = _resolvePath -Path $ZipPath
	if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

	$zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
	try {
		foreach ($src in $SourcePath) {
			$resolved = _resolvePath -Path $src

			if (Test-Path $resolved -PathType Container) {
				Get-ChildItem -Path $resolved -Recurse -File | ForEach-Object {
					$entryName = $_.FullName.Substring($resolved.Length + 1) -replace '\\', '/'
					[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entryName, $CompressionLevel) | Out-Null
				}
			} else {
				$entryName = Split-Path $resolved -Leaf
				[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $resolved, $entryName, $CompressionLevel) | Out-Null
			}
		}
	} finally {
		$zip.Dispose()
	}

	return $ZipPath
}