function Convert-ResToScript {
    <#
.SYNOPSIS
    Converts RES export to PowerShell
.DESCRIPTION
    Creates one script per application (xml may contain several apps). Generates code for
        - Application start
        - Registry
        - Environment variables
        - Scripts
        - Linked actions
    By default, output is saved to <CURRENT CONSOLE WORKING DIRECTORY>\Scripts.
.EXAMPLE
    PS C:\Temp> Convert-ResToScript -Path "C:\data\path_to_res_file.xml"
    Creates C:\Temp\Scripts directory and save ps1 scripts there. Return PsCustomObject with properties from RES application
.EXAMPLE
    PS C:\Temp> Convert-ResToScript -Path "C:\data\path_to_res_file.xml" -Force
    Creates C:\Temp\Scripts directory and save ps1 scripts there. If C:\Temp\Scripts already contains scripts with app names, they will be overwritten. Return PsCustomObject with properties from RES application
.EXAMPLE
    dir C:\data *.xml | Convert-ResToScript -OutputDir C:\Results -Silent
    Creates C:\Results directory and save ps1 scripts for each applications described in xml files from C:\data directory. Silent switch suppress object return
.INPUTS
    XML file exported from RES
.OUTPUTS
    PowerShell script
	PsCustomObject
.NOTES
    Version 2.8
		* Update function that convert reg data to PowerShell commands
		* Replace PassThru argument with silent. By default, function returns information for farther processing
		  Silent switch disables this behavior. Only errors and warning will be displayed.
		* Add default output as object which stores RES information as properties:
			'Description'  = RES App Name
			'Target'       = Path to application
			'Arguments'    = Application start arguments
			'WorkingDir'   = Application start working directory
			'Scripts'      = Scripts which executed before application start
			'CloseScripts' = Scripts which executed after application close
			'Variables'    = Environment variables
			'Registry'     = Windows registry
			'FTA'          = assigned file associations
			'IsShortcut'   = (bool) indicate that RES App is shortcut
			'LinkedApps'   = List of linked RES Apps
			'InStartMenu'  = (bool) indicate that RES App has start menu
			'IsEnabled'    = (bool) indicate that RES App is enabled
			'AccessInfo'   = AD groups and users assigned on RES App
	Version 2.7
		* Fix fantom linked scripts
		* Fix empty scripts from empty res instances
		* code refactoring
	Version 2.6
		* Fix issue when logon scripts and apps are stored in one file
	Version 2.5
        * Recognize start of another RES application
    Version 2.4
        * Info about RES shortcut permissions moved on top of the script.
        * Add assigned permissions on registry/variables/actions.
        * Add powerzone information.
        * fix registry with empty ""
        * Refactor code to make it more clear
        * Small fixes in output script formatting.
    Version 2.3
        * fix bug for Path parameter with Resolve-Path
        * Resolve dos-style %variables%
        * Add information about disabled shortcuts: by Disable option, by StartMenu item option
        * Add partial information about access groups and users
        * Add actions on app close
        * Change info appearance: additional comments will be added to result script if requested info has
          non-default values. For example, if workspace was not set, result script will not have workspace
          comment at all. If workspace has specific value, script will have workspace comment with value
    Version 2.2
        * Script adjusted to work with logon actions
        * removed undesired blank lines
        * added additional info about to each res object (name or description)
        *changed default output dir to current working directory. See examples
    TO-DO:
    - Folder Redirections
    - mapping
    - embeddedpolicies
#>
    [CmdletBinding()]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
        $Path,
        [string]$OutputDir = "$PWD\Scripts",
        [switch]$Silent,
        [switch]$Force
    )
    BEGIN { }
    PROCESS {
        foreach ($file in $Path) {
            # enable relative path support
            if ($file -is 'Io.FileInfo') { $file = $file.FullName }
            $file = (resolve-path -Path $file).Path

            Write-Verbose "Parse file:`t$file"
            [xml]$XmlData = Get-Content -Path $file

            $Workspaces = _getSecureArea -SecureArea $XmlData.respowerfuse.buildingblock.workspaces.workspace
            $PowerZones = _getSecureArea -SecureArea $XmlData.respowerfuse.buildingblock.powerzones.powerzone
            $ResObjects = _convertXmlToObj -XmlData $XmlData

            if (Test-Path $OutputDir) {} else { $null = New-Item -Path $OutputDir -ItemType Directory }

            foreach ($resobject in $ResObjects) {
                # Check that object is not empty to avoid empty scipts:
                $IsEmpty = ($($resobject.IsShortcut) -eq $false) -and
					   ($null -eq $($resobject.Scripts)) -and
					   ($null -eq $($resobject.CloseScripts)) -and
					   ($null -eq $($resobject.Variables)) -and
					   ($null -eq $($resobject.Registry)) -and
					   ($null -eq $($resobject.FTA)) -and
					   ($null -eq $($resobject.LinkedApps))

                if ( $IsEmpty ) {
                    Write-Verbose "Res Object is empty:`t$($resobject.Description)"
                    continue
                }

                $FileNamePrefix = ''

                if ($resobject.IsShortcut -eq $false) {
                    $FileNamePrefix = '__'
                }

                if ($null -eq $resobject.Name) {
                    $FileName = (Get-Item $file).BaseName
                }
                else { $FileName = $resobject.Name }
                $FileName = "$FileNamePrefix$FileName.ps1"
                $FilePath = "$OutputDir\$FileName"

                if ( !$Silent ) {
                    $resobject | Add-Member -MemberType 'NoteProperty' -Name 'FilePath' -Value $FilePath
                    Write-Output $resobject
                }

                if ( (Test-Path $FilePath) -and !$Force) {

                    Write-Verbose "File already exists:`t${FileName}"
                    continue
                }

                $ShortcutScript = _makeShortcutScript -ResObject $resobject

                $null = New-Item -Path $FilePath -ItemType File -Value $ShortcutScript -Force:$Force
                Write-Verbose "New script was created:`t${FileName}"
            } #foreach $resobject
        } #foreach $file
    } #PROCESS
    END { }
}