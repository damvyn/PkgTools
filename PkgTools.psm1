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
	. $PublicScript.FullName
}
#endregion ******** public functions ********