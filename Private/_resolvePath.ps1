function _resolvePath {
	[CmdletBinding()]
	param($Path)

	if ($Path -is [IO.FileInfo]) { $Path = $Path.FullName }

	$PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
}