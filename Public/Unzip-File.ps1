function Unzip-File {
	param (
		[Parameter(Mandatory)][string]$Path,
		[string]$DestinationPath
	)

	Add-Type -AssemblyName System.IO.Compression.FileSystem

	$Path = _resolvePath -Path $Path

	if (-not $DestinationPath) {
		$DestinationPath = Join-Path (Split-Path $Path -Parent) ([IO.Path]::GetFileNameWithoutExtension($Path))
	}
	$DestinationPath = _resolvePath -Path $DestinationPath

	$null = New-Item -Path $DestinationPath -ItemType Directory -Force
	[System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)

	return $DestinationPath
}