function _getAccessControl {
	param(
		$Target
	)
	$AccessList = [System.Collections.ArrayList]@()
	$AccessControl = $Target.accesscontrol
	if ($AccessControl.accesstype -eq 'group') {
		foreach ($group in $AccessControl.grouplist.group) {
			$AccessOptions = @()
			if ($null -ne $group.type) { $AccessOptions += $group.type }
			if ($null -ne $group.InnerText) { $AccessOptions += $group.InnerText }
			$null = $AccessList.Add("$AccessOptions")
		}
		foreach ($group in $AccessControl.notgrouplist.group) {
			$AccessOptions = @()
			if ($null -ne $group.type) { $AccessOptions += $group.type }
			if ($null -ne $group.InnerText) { $AccessOptions += $group.InnerText }
			$null = $AccessList.Add("NOT $AccessOptions")
		}
	}

	#if ($null -ne $AccessControl.access.type) { $null = $AccessList.Add($AccessControl.access.type) }

	if ($null -ne $AccessControl.access) {
		foreach ($subnode in $AccessControl.access) {
			$AccessOptions = @()
			if ($null -ne $subnode.options) { $AccessOptions += $subnode.options }
			if ($null -ne $subnode.type) { $AccessOptions += $subnode.type.ToUpper() }
			if ($null -ne $subnode.object) {
				if ($subnode.type -eq 'powerzone') {
					$Name = $Powerzones | Foreach-Object {
						if ($_.Guid -eq $subnode.object) { $_.Name } }
				}
				else {
					$Name = $subnode.object
				}
				$AccessOptions += $Name
			}
			$null = $AccessList.Add("$AccessOptions")
		}
	}
	Write-Output $AccessList
} # function _getAccessControl