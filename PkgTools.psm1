#region ******** module variables ********
$ScriptTemplate = @'
<INFO>function Start-Application {
<LINKEDAPPS><ENVVAR><REG_ENTRY><SCRIPTS><STARTAPP>
}
Start-Application
'@

$LinkedScriptTemplate = @'
<INFO><LINKEDAPPS><ENVVAR><REG_ENTRY><SCRIPTS>
'@

$StartApp = @'
    Start-Process -FilePath "<PATHTOAPP>"<ARGS><WKDIR> -WindowStyle Normal
'@
#endregion ******** module variables ********


#region ******** hidden functions ********
foreach ($PrivateScript in (Get-ChildItem -Filter "*.ps1" -Path "$PsScriptRoot\Private")) {
	. $PrivateScript.FullName
}
#endregion ******** hidden functions ********


#region ******** public functions ********
foreach ($PublicScript in (Get-ChildItem -Filter "*.ps1" -Path "$PsScriptRoot\Public")) {
	$skipScript = ($PSVersionTable.PSVersion -lt [version]'7.0' -and $PublicScript.Name -eq 'Show-Tree2.ps1') -or
		($PSVersionTable.PSVersion -ge [version]'7.0' -and $PublicScript.Name -eq 'Show-Tree1.ps1')
	if ($skipScript) {
		continue
	}
	. $PublicScript.FullName
}
#endregion ******** public functions ********