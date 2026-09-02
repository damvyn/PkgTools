function _getSecureArea {
	[CmdletBinding()]
	param(
		$SecureArea
	)

	foreach ($Area in $SecureArea) {
		[PsCustomObject]@{
			'Name'    = $Area.name
			'Guid'    = $Area.guid
			'Enabled' = $Area.enabled
		}
	}
}