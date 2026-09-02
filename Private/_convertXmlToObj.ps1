function _convertXmlToObj {
	[CmdletBinding()]
	param([xml]$XmlData)
	
	$ResObjects = [System.Collections.ArrayList]@()

	# add aplications
	if ( $null -ne $XmlData.respowerfuse.buildingblock.application ) {
		$applications = $XmlData.respowerfuse.buildingblock.application
		foreach ($application in $applications) {
			$null = $ResObjects.Add($application)
		}
	}

	# add logon actions
	if ( $null -ne $XmlData.respowerfuse.buildingblock.powerlaunch ) {
		$logonactions = $XmlData.respowerfuse.buildingblock.powerlaunch
		foreach ($logonaction in $logonactions) {
			$null = $ResObjects.Add($logonaction)
		}
		$logonactions = $null
	}

	foreach ($resobject in $ResObjects) {
		# detect app and logon actions
		$app = if ( $resobject.Name -eq 'application') {
			# collect shortcut settings
			$Target = $resobject.configuration.commandline
			$Arguments = $resobject.configuration.parameters
			$WorkingDir = $resobject.configuration.workingdir
			$Name = $resobject.configuration.title
			$Description = $resobject.configuration.description
			$CommandLine = $resobject.configuration.commandline
			$Configuration = $resobject.configuration
			$CreateMenuShortcut = $resobject.configuration.createmenushortcut
			$IsEnabled = $resobject.settings.enabled
			$AccessInfo = _getAccessControl -Target $resobject

			Write-Verbose "RES application $Name was detected"

			# collect apps ftas
			$fta = [System.Collections.ArrayList]@()
			foreach ($extension in $resobject.instantfileassociations.association) {
				$null = $fta.Add(
					[PsCustomObject]@{
						'extension'       = $extension.extension
						'command'         = $extension.command
						'parameters'      = $extension.parameters
						'description'     = $extension.description
						'dde_enabled'     = $extension.dde_enabled
						'dde_message'     = $extension.dde_message
						'dde_application' = $extension.dde_application
						'dde_topic'       = $extension.dde_topic
						'dde_ifexec'      = $extension.dde_ifexec
					} #hashtable fta
				) # add
			} #foreach extension

			Write-Output $resobject.powerlaunch
		}
		else {
			Write-Verbose "At-logon action was detected"
			Write-Output $resobject
		}

		# Collect environment variables
		$EnvVariables = [System.Collections.ArrayList]@()
		foreach ($variable in $app.variable) {
			$null = $EnvVariables.Add(
				[PsCustomObject]@{
					'Name'       = "$($variable.name)"
					'Value'      = "$($variable.value)"
					'Enabled'    = "$($variable.enabled)"
					'Workspace'  = $Workspaces | Foreach-Object { if ($_.Guid -in $variable.workspacecontrol.workspace) { $_.Name } }
					'AccessInfo' = _getAccessControl -Target $variable
				})   #   save as hashtable
		} # foreach $variable

		# Collect on-start scripts and commands
		$ResScripts = [System.Collections.ArrayList]@()
		foreach ($script in $app.exttask) {
			$null = $ResScripts.Add(
				[PsCustomObject]@{
					'Name'       = $script.description
					'Command'    = $script.Command
					'Text'       = $script.script
					'Type'       = $script.scriptext
					'Enabled'    = $script.enabled
					'Workspace'  = $Workspaces | Foreach-Object { if ($_.Guid -in $script.workspacecontrol.workspace) { $_.Name } }
					'AccessInfo' = _getAccessControl -Target $script
				})     #   save as object
		} # foreach $script

		# collect on-close scripts and commands
		$OnCloseScripts = [System.Collections.ArrayList]@()
		foreach ($script in $app.exttaskex) {
			$null = $OnCloseScripts.Add(
				[PsCustomObject]@{
					'Name'       = $script.description
					'Command'    = $script.Command
					'Text'       = $script.script
					'Type'       = $script.scriptext
					'Enabled'    = $script.enabled
					'Workspace'  = $Workspaces | Foreach-Object { if ($_.Guid -in $script.workspacecontrol.workspace) { $_.Name } }
					'AccessInfo' = _getAccessControl -Target $script
				})     #   save as object
		} # foreach $script

		# collect registry
		$ResRegistry = [System.Collections.ArrayList]@()
		foreach ($regEntry in $app.registry) {
			$null = $ResRegistry.Add(
				[PsCustomObject]@{
					'Name'       = $regEntry.name
					'regText'    = [System.Text.Encoding]::ASCII.GetString( [byte[]] -split ($regEntry.registryfile -replace '..', '0x$& ') )
					'Enabled'    = $regEntry.enabled
					'Workspace'  = $Workspaces | Foreach-Object { if ($_.Guid -in $regEntry.workspacecontrol.workspace) { $_.Name } }
					'AccessInfo' = _getAccessControl -Target $regEntry
				}
			)
		} # foreach $regEntry

		# collect linked actions
		$LinkedApplications = [System.Collections.ArrayList]@()
		$LinkedActions = $app.linked_actions
		foreach ($LinkedActionGuid in $LinkedActions) {
			$LinkedApplication = ( $applications | Where-Object { $_.guid -eq $LinkedActionGuid.linked_to_application } ).configuration.title
			if ($LinkedApplication) {
				$null = $LinkedApplications.Add($LinkedApplication)
			}
		} # foreach LinkedActionGuid

		# recognize start of another RES application
		if ($Target -eq '%respfdir%\pwrgate.exe') {

			Write-Warning 'RES <commandline> setting has pwrgate.exe as target. The shortcuts call for another RES application'

			$ResAppId = $Arguments -split ' ' | Select-Object -First 1
			if ($ResAppId -notmatch '[^0-9]') {

				Write-Warning "Called application has id $ResAppId in RES database"

				$Target = ($Arguments -split ' ' | Select-Object -Skip 1) -join ''
				$Arguments = ''
				$WorkingDir = ''
			}
		}

		[PsCustomObject][ordered]@{
			'Name'         = $Name
			'Description'  = $Description
			'Target'       = $Target
			'Arguments'    = $Arguments
			'WorkingDir'   = $WorkingDir
			'Scripts'      = $ResScripts
			'CloseScripts' = $OnCloseScripts
			'Variables'    = $EnvVariables
			'Registry'     = $ResRegistry
			'FTA'          = $fta
			'IsShortcut'   = ( '-' -ne "$CommandLine" ) -and ( $null -ne $Configuration )
			'LinkedApps'   = $LinkedApplications
			'InStartMenu'  = $CreateMenuShortcut
			'IsEnabled'    = $IsEnabled
			'AccessInfo'   = $AccessInfo
		} #hashtable output
	} # foreach $app
}