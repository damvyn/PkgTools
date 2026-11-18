function _invokeSoap {
	param([string]$Url, [string]$Body)

	$r = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -UseBasicParsing `
		-ContentType 'application/soap+xml; charset=utf-8' -ErrorAction Stop
	[xml]$r.Content
}
