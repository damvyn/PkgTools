function _resolvePath {
	[CmdletBinding()]
	param($Path)

	if ($Path -is 'Io.FileInfo') { $Path = $Path.FullName }
	(resolve-path -Path $Path).Path
}