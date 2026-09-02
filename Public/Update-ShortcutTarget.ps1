function Update-ShortcutTarget {
	<#
.Synopsis
   Script for modifying shortcuts targets
.VERSION
   1.0 - initial
.DESCRIPTION
   Script modifies all .lnk files in selected folder by searching and replacing given text in TargetPath and Comments fields
   Required parameters:
   $oldString - old script location # EXAMPLE "OLD_PATH\"
   $newString - new script location # EXAMPLE "NEW_PATH\"
.EXAMPLE
   Update-ShortcutTarget "OLD_PATH\Shortcut.lnk" "NEW_PATH\" "NEW_PATH\"
#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, Position = 1)]
		[string]$oldString,
		[Parameter(Mandatory = $true, Position = 2)]
		[string]$newString,
		[Parameter(Mandatory = $true, Position = 3, ValueFromPipeline = $true)]
		[System.IO.FileSystemInfo]$FilePath
	)

	BEGIN {	}
	PROCESS {
		$shell = new-object -com wscript.shell
		$lnk = $shell.createShortcut( $FilePath.fullname )
		$oldDescription = $lnk.Description
		$oldArgs = $lnk.Arguments
		$lnkRegex = ",*" + [regex]::escape( $oldString )

		if ( $oldArgs -match $lnkRegex ) {
			$newArgs = $oldArgs -replace $lnkRegex, $newString
	
			$lnk.Arguments = $newArgs
			$lnk.Save()      
		}
		if ( $oldDescription -match $lnkRegex ) {
			$newDescription = $oldDescription -replace $lnkRegex, $newString
			
			$lnk.Description = $newDescription
			$lnk.Save()
			$shell = $null   
		}
	}
	END { }
}