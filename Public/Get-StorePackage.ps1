function Get-StorePackage {
	<#
.SYNOPSIS
    Downloads a Microsoft Store app plus its dependencies without the Store app
    or an Entra ID account, into one folder.

.DESCRIPTION
    Same technique as store.rg-adguard.net:
      1. displaycatalog.mp.microsoft.com  -> WuCategoryId / PackageFamilyName
      2. FE3 GetCookie + SyncUpdates       -> package list (UpdateID, Revision, file names, digests)
      3. FE3 GetExtendedUpdateInfo2        -> signed, temporary CDN URLs
      4. Download into one folder and write Install.ps1
    For Store apps that are plain Win32 EXE/MSI (no MSIX), falls back to the
    storeedgefd packageManifests API (the source winget's 'msstore' uses).

.PARAMETER ProductId
    Store product ID, e.g. 9WZDNCRFJ3PS

.PARAMETER OutputPath
    Folder where a "<Title> (<ProductId>) <Arch>" subfolder is created. Defaults to the current location.

.PARAMETER Architecture
    x64, x86, arm64 or arm

.PARAMETER Ring
    Retail = normal release, RP = Release Preview, WIS = Insider Slow, WIF = Insider Fast

.PARAMETER Market
    Store market (country code)

.PARAMETER ListOnly
    Only print the links, don't download

.EXAMPLE
    PS C:\> Get-StorePackage -ProductId 9WZDNCRFJ3PS -OutputPath C:\Dev\Test

.EXAMPLE
    PS C:\> Get-StorePackage 9WZDNCRFJ3PS -Architecture arm64 -ListOnly

.INPUTS N/A

.OUTPUTS N/A

.NOTES
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory, Position = 0)]
		[string]$ProductId,

		[string]$OutputPath = (Get-Location).Path,

		[ValidateSet('x64', 'x86', 'arm64', 'arm')]
		[string]$Architecture = 'x64',

		[ValidateSet('Retail', 'RP', 'WIS', 'WIF')]
		[string]$Ring = 'Retail',

		[string]$Market = 'US',

		[switch]$ListOnly
	)

	$ErrorActionPreference = 'Stop'
	$ProgressPreference    = 'SilentlyContinue'   # makes Invoke-WebRequest much faster on PS 5.1
	[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

	$ProductId    = $ProductId.Trim().ToUpperInvariant()
	$OutputPath   = _resolvePath $OutputPath
	$Fe3          = 'https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx'
	$Fe3Secure    = "$Fe3/secured"
	$OsArch       = @{ x64 = 'AMD64'; x86 = 'x86'; arm64 = 'ARM64'; arm = 'ARM' }[$Architecture]
	$EncryptedExt = '.eappx', '.eappxbundle', '.emsix', '.emsixbundle'

	# Pretend to be an ordinary Windows 11 24H2 desktop on the chosen ring
	$DeviceAttr = @(
		'BranchReadinessLevel=CB', 'CurrentBranch=ge_release', "FlightRing=$Ring", 'AttrDataVer=21',
		'InstallLanguage=en-US', 'OSUILocale=en-US', 'InstallationType=Client', 'FlightingBranchName=',
		'OSSkuId=48', 'App=WU', 'AppVer=10.0.26100.1', "OSArchitecture=$OsArch", 'UpdateManagementGroup=2',
		'IsDeviceRetailDemo=0', 'IsFlightingEnabled=0', 'TelemetryLevel=1',
		'OSVersion=10.0.26100.1', 'DeviceFamily=Windows.Desktop'
	)
	$SyncDeviceAttr = [Security.SecurityElement]::Escape(($DeviceAttr -join ';') + ';')
	$UrlDeviceAttr  = [Security.SecurityElement]::Escape('E:' + ($DeviceAttr -join '&'))

	# ----------------------------------------------------------------------- 1. catalog

	Write-Host "Looking up $ProductId in the Store catalog..."
	$cat = Invoke-RestMethod -UseBasicParsing `
		-Uri "https://displaycatalog.mp.microsoft.com/v7.0/products/${ProductId}?market=$Market&languages=en-US&fieldsTemplate=Details"

	$product = $cat.Product
	if (-not $product) { throw "Product $ProductId not found in market $Market." }
	$title = @($product.LocalizedProperties)[0].ProductTitle
	$fd    = @($product.DisplaySkuAvailabilities)[0].Sku.Properties.FulfillmentData
	if ($fd -is [string]) { $fd = $fd | ConvertFrom-Json }

	$catId    = $fd.WuCategoryId
	$pfn      = $fd.PackageFamilyName
	$mainName = if ($pfn) { $pfn.Split('_')[0] } else { $null }
	Write-Host "  $title"
	Write-Host "  PackageFamilyName: $pfn"
	Write-Host "  WuCategoryId:      $catId"

	$downloads = @()

	if ($catId) {
		# ------------------------------------------------------------------- 2. cookie
		$cookieBody = @"
<GetCookie xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
  <oldCookie></oldCookie>
  <lastChange>2015-10-21T17:01:07.1472913Z</lastChange>
  <currentTime>$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))</currentTime>
  <protocolVersion>1.40</protocolVersion>
</GetCookie>
"@
		$resp   = _invokeSoap $Fe3 (_newSoapEnvelope 'GetCookie' $Fe3 $cookieBody)
		$cookie = @(_selectXmlByName $resp 'EncryptedData' -Deep)[0].InnerText
		if (-not $cookie) { throw 'FE3 GetCookie returned no cookie.' }

		# ------------------------------------------------------------------- 3. SyncUpdates
		# Base IDs a real client reports as installed; FE3 returns nothing useful without them
		$nonLeaf = 1, 2, 3, 11, 19, 544, 549, 2359974, 2359977, 5169044, 8788830, 23110993, 23110994,
			54341900, 54343656, 59830006, 59830007, 59830008, 60484010, 62450018, 62450019,
			62450020, 66027979, 66053150, 97657898, 98822896, 98959022, 98959023, 98959024,
			98959025, 98959026, 104433538, 104900364, 105489019, 117765322, 129905029,
			130040031, 132387090, 132393049, 133399034, 138537048, 140377312, 143747671,
			158941041, 158941042, 158941043, 158941044, 159123858, 159130928, 164836897,
			164847386, 164848327, 164852241, 164852246, 164852252, 164852253
		$nonLeafXml = ($nonLeaf | ForEach-Object { "<int>$_</int>" }) -join ''

		$syncBody = @"
<SyncUpdates xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
  <cookie>
    <Expiration>2045-03-11T02:02:48Z</Expiration>
    <EncryptedData>$cookie</EncryptedData>
  </cookie>
  <parameters>
    <ExpressQuery>false</ExpressQuery>
    <InstalledNonLeafUpdateIDs>$nonLeafXml</InstalledNonLeafUpdateIDs>
    <OtherCachedUpdateIDs></OtherCachedUpdateIDs>
    <SkipSoftwareSync>false</SkipSoftwareSync>
    <NeedTwoGroupOutOfScopeUpdates>true</NeedTwoGroupOutOfScopeUpdates>
    <FilterAppCategoryIds>
      <CategoryIdentifier><Id>$catId</Id></CategoryIdentifier>
    </FilterAppCategoryIds>
    <TreatAppCategoryIdsAsInstalled>true</TreatAppCategoryIdsAsInstalled>
    <AlsoPerformRegularSync>false</AlsoPerformRegularSync>
    <ComputerSpec/>
    <ExtendedUpdateInfoParameters>
      <XmlUpdateFragmentTypes><XmlUpdateFragmentType>Extended</XmlUpdateFragmentType></XmlUpdateFragmentTypes>
      <Locales><string>en-US</string><string>en</string></Locales>
    </ExtendedUpdateInfoParameters>
    <ClientPreferredLanguages><string>en-US</string></ClientPreferredLanguages>
    <ProductsParameters>
      <SyncCurrentVersionOnly>false</SyncCurrentVersionOnly>
      <DeviceAttributes>$SyncDeviceAttr</DeviceAttributes>
      <CallerAttributes>Interactive=1;IsSeeker=0;</CallerAttributes>
      <Products/>
    </ProductsParameters>
  </parameters>
</SyncUpdates>
"@
		Write-Host 'Querying Windows Update (FE3) for packages...'
		$sync = _invokeSoap $Fe3 (_newSoapEnvelope 'SyncUpdates' $Fe3 $syncBody)

		# The <Xml> elements in FE3 responses hold escaped XML fragments with several roots,
		# so they are wrapped in a dummy root before parsing

		# ExtendedUpdateInfo/Updates/Update: ID -> file info (name, digest, package identity)
		$fileById = @{}
		foreach ($u in _selectXmlByName $sync 'Update' -Deep) {
			$id  = @(_selectXmlByName $u 'ID')[0].InnerText
			$xml = @(_selectXmlByName $u 'Xml')[0]
			if (-not $id -or -not $xml) { continue }
			$frag = [xml]"<r>$($xml.InnerText)</r>"
			$file = $frag.SelectSingleNode("//*[local-name()='File' and @InstallerSpecificIdentifier]")
			if ($file) { $fileById[$id] = $file }
		}

		# NewUpdates/UpdateInfo: ID -> UpdateID + RevisionNumber (only downloadable ones have SecuredFragment)
		$candidates = foreach ($u in _selectXmlByName $sync 'UpdateInfo' -Deep) {
			$id  = @(_selectXmlByName $u 'ID')[0].InnerText
			$xml = @(_selectXmlByName $u 'Xml')[0]
			if (-not $id -or -not $xml -or -not $fileById.ContainsKey($id)) { continue }
			$frag = [xml]"<r>$($xml.InnerText)</r>"
			if (-not $frag.SelectSingleNode("//*[local-name()='SecuredFragment']")) { continue }
			$ident = $frag.SelectSingleNode("//*[local-name()='UpdateIdentity']")
			$file  = $fileById[$id]
			$isi   = $file.InstallerSpecificIdentifier          # Name_Version_Arch_ResourceId_PublisherId
			$parts = $isi.Split('_')
			$ext   = [IO.Path]::GetExtension($file.FileName).ToLowerInvariant()
			[pscustomobject]@{
				UpdateID = $ident.UpdateID
				Revision = $ident.RevisionNumber
				Name     = $parts[0]
				Version  = [version]$parts[1]
				Arch     = $parts[2]
				FileName = "$isi$ext"
				Ext      = $ext
				Digest   = $file.Digest
				IsMain   = ($parts[0] -eq $mainName)
			}
		}

		# Newest version per package name, for our architecture (or neutral)
		$selected = $candidates |
			Where-Object { $_.Arch -in @($Architecture, 'neutral') } |
			Group-Object Name |
			ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -First 1 }

		foreach ($p in @($selected | Where-Object { $EncryptedExt -contains $_.Ext })) {
			Write-Warning "Skipping encrypted package $($p.FileName) (needs a license to decrypt)."
		}
		$selected = @($selected | Where-Object { $EncryptedExt -notcontains $_.Ext })

		# ------------------------------------------------------------------- 4. URLs
		foreach ($p in $selected) {
			$urlBody = @"
<GetExtendedUpdateInfo2 xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
  <updateIDs>
    <UpdateIdentity>
      <UpdateID>$($p.UpdateID)</UpdateID>
      <RevisionNumber>$($p.Revision)</RevisionNumber>
    </UpdateIdentity>
  </updateIDs>
  <infoTypes>
    <XmlUpdateFragmentType>FileUrl</XmlUpdateFragmentType>
    <XmlUpdateFragmentType>FileDecryption</XmlUpdateFragmentType>
  </infoTypes>
  <deviceAttributes>$UrlDeviceAttr</deviceAttributes>
</GetExtendedUpdateInfo2>
"@
			$r = _invokeSoap $Fe3Secure (_newSoapEnvelope 'GetExtendedUpdateInfo2' $Fe3Secure $urlBody)
			$loc = _selectXmlByName $r 'FileLocation' -Deep | Where-Object {
				@(_selectXmlByName $_ 'FileDigest')[0].InnerText -eq $p.Digest
			} | Select-Object -First 1
			if (-not $loc) { Write-Warning "No URL returned for $($p.FileName)"; continue }
			$downloads += [pscustomobject]@{
				FileName = $p.FileName
				Url      = @(_selectXmlByName $loc 'Url')[0].InnerText
				IsMain   = $p.IsMain
				Version  = $p.Version
			}
		}
	}

	if (-not $downloads) { $downloads = @(_getStoreWin32Installer -ProductId $ProductId -Market $Market -Architecture $Architecture) }
	if (-not $downloads) { throw "Nothing downloadable found for $ProductId ($Architecture, $Ring)." }

	Write-Host ''
	$downloads | Sort-Object IsMain | Format-Table @{ n = 'Main'; e = { if ($_.IsMain) { '*' } } }, FileName, Url -AutoSize -Wrap | Out-Host

	if ($ListOnly) { return }

	# ----------------------------------------------------------------------- 5. download

	$safeTitle = ($title -replace '[\\/:*?"<>|]', '').Trim()
	if (-not $safeTitle) { $safeTitle = $ProductId }
	$folder = Join-Path $OutputPath "$safeTitle ($ProductId) $Architecture"
	New-Item -ItemType Directory -Path $folder -Force | Out-Null

	foreach ($d in $downloads) {
		$dest = Join-Path $folder $d.FileName
		Write-Host "Downloading $($d.FileName)..."
		Invoke-WebRequest -Uri $d.Url -OutFile $dest -UseBasicParsing

		$sig = Get-AuthenticodeSignature $dest
		$who = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { '-' }
		Write-Host "  Signature: $($sig.Status)  $who"
		if ($sig.Status -in 'HashMismatch', 'NotSigned', 'NotTrusted') {
			Write-Warning "$($d.FileName): signature status is $($sig.Status)!"
		}
	}

	# Installer helper: dependencies first, main app last
	$mainFiles = @($downloads | Where-Object IsMain | ForEach-Object FileName)
	$installScript = @"
# Installs dependencies first, then the main app. Run from this folder.
`$main = @('$($mainFiles -join "','")')
`$pkgs = Get-ChildItem -LiteralPath `$PSScriptRoot -File |
    Where-Object { `$_.Extension -match '^\.(appx|msix|appxbundle|msixbundle)$' }
foreach (`$p in `$pkgs | Where-Object { `$main -notcontains `$_.Name }) {
    Write-Host "Installing dependency `$(`$p.Name)"
    try { Add-AppxPackage -Path `$p.FullName -ErrorAction Stop }
    catch { Write-Warning "  `$(`$_.Exception.Message.Split([Environment]::NewLine)[0])" }
}
foreach (`$p in `$pkgs | Where-Object { `$main -contains `$_.Name }) {
    Write-Host "Installing `$(`$p.Name)"
    Add-AppxPackage -Path `$p.FullName
}
"@
	Set-Content -Path (Join-Path $folder 'Install.ps1') -Value $installScript -Encoding UTF8

	Write-Host ''
	Write-Host "Done: $folder" -ForegroundColor Green
}
