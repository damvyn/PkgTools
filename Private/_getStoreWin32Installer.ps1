function _getStoreWin32Installer {
	# Fallback for Store apps that are plain Win32 EXE/MSI (no MSIX):
	# the storeedgefd packageManifests API (the source winget's 'msstore' uses)
	param([string]$ProductId, [string]$Market, [string]$Architecture)

	Write-Host 'No MSIX packages found - trying the Win32 (EXE/MSI) manifest API...'
	$uri = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/packageManifests/${ProductId}?market=$Market&locale=en-us&deviceFamily=Windows.Desktop"
	$m   = Invoke-RestMethod -Uri $uri -UseBasicParsing -ErrorAction Stop
	$ver = @($m.Data.Versions)[-1]
	$all = @($ver.Installers)
	$pick = @($all | Where-Object { $_.Architecture -eq $Architecture })
	if (-not $pick) { $pick = @($all | Where-Object { $_.Architecture -eq 'neutral' -or -not $_.Architecture }) }
	if (-not $pick) { $pick = $all }
	foreach ($i in ($pick | Select-Object -First 1)) {
		$name = [IO.Path]::GetFileName(([uri]$i.InstallerUrl).AbsolutePath)
		if (-not [IO.Path]::GetExtension($name)) { $name = "$ProductId.$($i.InstallerType)" }
		[pscustomobject]@{ FileName = $name; Url = $i.InstallerUrl; IsMain = $true; Version = $ver.PackageVersion }
	}
}
