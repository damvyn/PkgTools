function Convert-RegEscapeCodes {
	Param(
		[Parameter(Position = 1)][string]$regstring)
		
	return $regstring.Replace("\\", "\").Replace('\"', '"')
}