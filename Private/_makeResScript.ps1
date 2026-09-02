function _makeResScript {
	param($script)

	$ScriptCommand = ''

	if ($null -ne $script.Workspace) { $WorkspaceText = "    # Workspace: $($script.Workspace)`n" }
	else { $WorkspaceText = '' }

	if ($null -ne $script.name) { $DescriptionText = "    # Name: $($script.name)`n" }
	else { $DescriptionText = '' }

	if ($script.AccessInfo.Count -ne 0) {
		$AccessInfoText = ""
		foreach ($AccessInfo in $script.AccessInfo) {
			$AccessInfoText += "# $AccessInfo`n"
		}
	}
	else {
		$AccessInfoText = ''
	}

	$ScriptCommand += $DescriptionText + $WorkspaceText + $AccessInfoText
	if ($script.Enabled -ne 'yes') {
		$strStart = '# '
		$ScriptCommand += "    # Script was disabled!!!`n"
	}
	else { $strStart = '' }

	if (($script.Type -ne 'ps1')) {
		$strStart = '# '
	}

	$ScriptCommand += "    # Command: $($script.Command) `n"
	$lines = $script.Text -split "`n"

	foreach ($scriptText in $lines) {
		$ScriptCommand += "    ${strStart}${scriptText} `n"
	} #foreach $scriptText

	Write-Output $ScriptCommand
} # function _makeResScript