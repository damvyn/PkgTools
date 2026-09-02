function Zip-File {
	param ( [string]$SourcePath, [string]$ZipPath )

	$SourcePath = _resolvePath -Path $SourcePath
	$ZipPath = _resolvePath -Path $ZipPath

	Add-Type -Assembly System.IO.Compression.FileSystem
	$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	[System.IO.Compression.ZipFile]::CreateFromDirectory($SourcePath, $ZipPath, $compressionLevel, $false)
}