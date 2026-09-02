function _makeShortcutScript {
	[CmdletBinding()]
	param( [PsCustomObject]$ResObject )
	BEGIN { } #BEGIN
	PROCESS {
		$ScriptTemplate = $script:ScriptTemplate
		$LinkedScriptTemplate = $script:LinkedScriptTemplate

		foreach ($resobject in $ResObject) {
			$Target = ''
			$Arguments = ''
			$WorkingDir = ''
			$AppInfo = ''
			if ($ResObject.IsShortcut -eq $True) {

				if (($resobject.InStartMenu -eq 'no') -or ($resobject.IsEnabled -eq 'no')) {
					$AppInfo += "    # StartMenu shortcut was disabled!!!`n"
				}

				$Target = [system.environment]::ExpandEnvironmentVariables("$($ResObject.Target)")
				$Arguments = [system.environment]::ExpandEnvironmentVariables("$($ResObject.Arguments)")
				$WorkingDir = [system.environment]::ExpandEnvironmentVariables("$($ResObject.WorkingDir)")
				# add path to executable
				$StartApp = $script:StartApp
				$StartApp = $StartApp.Replace('<PATHTOAPP>', $Target)

				# add arguments
				if ('' -ne $ResObject.Arguments) {
					$AppArgs = " -ArgumentList `"$Arguments`""
				}
				else { $AppArgs = '' }
				$StartApp = $StartApp.Replace('<ARGS>', $AppArgs)

				# add working directory
				if ('' -ne $ResObject.WorkingDir) {
					$AppArgs = " -WorkingDirectory `"$WorkingDir`""
				}
				else { $AppArgs = '' }
				$StartApp = $StartApp.Replace('<WKDIR>', $AppArgs)

				$ScriptBody = $ScriptTemplate
				$ScriptBody = $ScriptBody.Replace('<STARTAPP>', $StartApp)
			}
			else {
				$ScriptBody = $LinkedScriptTemplate
			}

			# add security info
			if ($resobject.AccessInfo.Count -ne 0) {
				foreach ($AccessInfo in $resobject.AccessInfo) {
					$AppInfo += "    # $AccessInfo`n"
				}
			}

			# add fta info
			if ($resobject.FTA.Count -ne 0) {
				$ExtensionsForOpen = ($resobject.FTA | Where-Object { $_.command -eq 'open' }).extension -join ', '
				$AppInfo += "    # Extensions registered for open: $ExtensionsForOpen`n"
			}

			# add linked actions
			$LinkedScripts = ''
			if ($null -ne $($resobject.LinkedApps)) {
				foreach ($LinkedApp in $resobject.LinkedApps) {
					$LinkedScripts += "    . `"`$PsScriptRoot\__$LinkedApp.ps1`"`n`n"
				} # foreach $LinkedApp
				$LinkedScripts = "$LinkedScripts`n"
			} #if $resobject

			# add environment variables
			$EnvVarCommand = ''
			if ($null -ne $($resobject.Variables)) {
				foreach ($var in $resobject.Variables) {
					if ($null -ne $var.description) { $DescriptionText = "    # Description: $($var.description)`n" }
					else { $DescriptionText = '' }

					if ($null -ne $var.Workspace) { $WorkspaceText = "    # Workspace: $($var.Workspace)`n" }
					else { $WorkspaceText = '' }

					if ($var.AccessInfo.Count -ne 0) {
						$AccessInfoText = ""
						foreach ($AccessInfo in $var.AccessInfo) {
							$AccessInfoText += "    # $AccessInfo`n"
						}
					}
					else {
						$AccessInfoText = ''
					}

					$EnvVarCommand = $EnvVarCommand + $DescriptionText + $WorkspaceText + $AccessInfoText

					if ($var.Enabled -ne 'yes') {
						$strStart = '# '
						$EnvVarCommand += "    # Environment variable was disabled!!! `n"
					}
					else { $strStart = '' }

					$EnvVarCommand += "    ${strStart}`$EnvName  = '$($var.Name)' `n"
					$EnvVarCommand += "    ${strStart}`$EnvValue = '$($var.Value)' `n"
					$EnvVarCommand += "    ${strStart}[System.Environment]::SetEnvironmentVariable(`$EnvName, `$EnvValue, `"User`") `n"
					$EnvVarCommand += "    ${strStart}[System.Environment]::SetEnvironmentVariable(`$EnvName, `$EnvValue, `"Process`")`n"
					$EnvVarCommand = "$EnvVarCommand`n"
				} # foreach $var
			} # if $resobject.Variables

			# add registry
			$RegistryCommand = ''
			if ($null -ne $($resobject.Registry)) {
				foreach ($RegEntry in $resobject.Registry) {

					if ($null -ne $RegEntry.Workspace) { $WorkspaceText = "    # Workspace: $($RegEntry.Workspace)`n" }
					else { $WorkspaceText = '' }

					if ($null -ne $RegEntry.name) { $DescriptionText = "    # Name: $($RegEntry.name)`n" }
					else { $DescriptionText = '' }

					if ($RegEntry.AccessInfo.Count -ne 0) {
						$AccessInfoText = ""
						foreach ($AccessInfo in $RegEntry.AccessInfo) {
							$AccessInfoText += "    # $AccessInfo`n"
						}
					}
					else {
						$AccessInfoText = ''
					}

					$RegistryCommand = $RegistryCommand + $DescriptionText + $WorkspaceText + $AccessInfoText
					if ($RegEntry.Enabled -ne 'yes') {
						$strStart = '# '
						$RegistryCommand += "    # Registry was disabled!!! `n"
					}
					else { $strStart = '' }
					foreach ($regString in (Convert-RegToScript -RegText $RegEntry.regText)) {
						$RegistryCommand += "    ${strStart}${regString} `n"
					} # foreach $regString
					$RegistryCommand = "$RegistryCommand`n"
				} # foreach $RegEntry
			} #if $resobject

			# add scripts
			$ScriptCommand = ''
			if ($null -ne $($resobject.Scripts)) {
				foreach ($script in $resobject.Scripts) {
					$ScriptCommand += _makeResScript -script $script
					$ScriptCommand = "$ScriptCommand`n"
				} # foreach $ResScript
			} # if $resobject.Scripts

			if ($null -ne $($resobject.CloseScripts)) {
				foreach ($script in $resobject.CloseScripts) {
					$ScriptCommand += "    # Action on app close!!!`n"
					$ScriptCommand += _makeResScript -script $script
					$ScriptCommand = "$ScriptCommand`n"
				} # foreach $ResScript
			} # if $resobject.Scripts

		} #foreach resobject

		$ScriptBody = $ScriptBody.Replace('<INFO>', $AppInfo)
		$ScriptBody = $ScriptBody.Replace('<LINKEDAPPS>', $LinkedScripts)
		$ScriptBody = $ScriptBody.Replace('<ENVVAR>', $EnvVarCommand)
		$ScriptBody = $ScriptBody.Replace('<REG_ENTRY>', $RegistryCommand)
		$ScriptBody = $ScriptBody.Replace('<SCRIPTS>', $ScriptCommand)

		$ScriptBody
	} #PROCESS
	END { } #END
} #function _makeShortcutScript