function Convert-ShortcutToScript {
<#
.Synopsis
    Transforms original shortcuts to powershell scripts
.DESCRIPTION
    Transforms original application shortcuts to powershell based ones. Prepares both: shortcuts and underlying powershell scripts (based on template)
.EXAMPLE
    C:\PS> .\ConvertTo-PortalShortcut.ps1 -source "c:\ProgramData\Microsoft\Windows\Start Menu\Programs\harmon.ie\harmon.ie on the web.lnk" -target "\\server\TargetFolder" -prefix "TEST - "

	Convert "harmon.ie on the web.lnk" into shortcut script under "\\server\TargetFolder"
	Resulted file is  "TEST - harmon.ie on the web.ps1"
.EXAMPLE
    C:\PS> dir "Path_To_Startmenu\Landmark\" | Convert-ShortcutToScript -sourceBase "Path_To_Startmenu\Landmark\" -target "\\server\TargetFolder -scripts "\\server\StartMenuScripts" -prefix "TEST - "

	Convert shortcuts under "Path_To_Startmenu\Landmark\" into powershell scripts.
	Put shortcuts under "\\server\TargetFolder" (preserving directory structure under "Path_To_Startmenu\Landmark")
	Put shortcut script under "\\server\StartMenuScripts"
	Prepend shortcuts' and scripts' names with "TEST - "
.PARAMETER source
	Full path to particular shortcut or directory, containing shortcuts
.PARAMETER target
	Full path to directory (top level) to place shortcut(s) to
.PARAMETER scripts
	Full path to directory to place shortcut scripts to
.PARAMETER prefix
	Prefix to mark files with
.PARAMETER sourceBase
	Directory (full path), to consider as base for source shortcuts. Use when need to preserve source directory structure (under the base) in target location.
	If not supplied, will try to use "start menu\programs" as the base (supposing path to startmenu shortcut is supplied in "source"). For arbitrary shortcut\directory (not in "start menu\programs"),
	parent directory (for shortcut) or directory itself will be used as the base, resulting in shortcut(s) placed to the root of "target"
.PARAMETER template
	Full path to custom PS script template. Use "ConvertTo-UnPackedBytes" function, $scriptTemplate (line: 171) and command '[IO.File]::writeAllBytes("<path to save the template>", (ConvertTo-UnPackedBytes -packedString $scriptTemplate))' to extract the template, used by this script
.INPUTS
    Accepts (from pipeline):
	- full file path(s) as string of "FullName" object (System.IO.FileInfo) property
.OUTPUTS
	N/A
#>

	param(
		[Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[string]$Source,
		[Parameter(Mandatory = $true)]
		[string]$target,
		[string]$scripts = '',
		[string]$prefix = '',
		[string]$sourceBase = '',
		[string]$template = ''
	)

	begin {
		# use ConvertTo-PackedString -byteArray ([IO.File]::ReadAllBytes("<full path to>\template.ps1"))
		$scriptTemplate = "H4sIAAAAAAAEAM2VXU/CUAyGe23if1jkzsR4b4gJshFIJkwGoncSBkrkS5AoGv+6+rQDRD7EoEbSbO15d/Zy+rYdb68NGUpHanIvTekSORISV6XP/UBS0sNaPKuBfex5ll3ZkQS76nI9RQ8xRwIpSwlfFE/OiHMWuSBpKeA9ogxREZ9idyA+e9LEJXxB8naGEuui8Zzwhg9eIS5Jlj0hkb6TN674V/d/1TQ7vZyxzWoS4LvoUZcB5oBkUKDFOjCNbsD2JCmNMdobo8egjlx94v3KkujrWA36aDyUNlwdmHx4B3j9FWVMwLwJb4Us+nILWwd+F6/V1E5QfLQxvzIrZwTPgyk3Mh0c6qXMbfRoTc8RUNkQy1Fn3+p5TsY+feOBHi28dWrcTdZNeYI1Mqwqj3NYljjC6taZmoOe/8Xiup1uWe/GTxywBnfdcYfysTKK13gSWS5/0XU/7div5zGFkpdL5zLF3WU9mT/VX2e0TJyeouE/zeLsPH6/dlWrfnP6zYq7Z/5rN9iaSq6un4veOgUFq6I3rpTq78nFwhdyO7JZlt36/5V1Fc6bEhMFwq3NdrUGer0D/JdyC3QHAAA="

		$shell = New-Object -ComObject "WScript.Shell"
	}

	process {

		Get-ChildItem -recurse $source -filter "*.*" | ForEach-Object { # need files only

			# deal with the defined filetypes only
			if ($_.extension -in @(".lnk", ".url")) {

				# try to unadvertise shortcut first
				ConvertTo-Unadvertised -shortcut $_.fullName

				# remove "readonly" flag, if present
				$_.attributes = $_.attributes -bxor ($_.attributes -band [System.IO.FileAttributes]::ReadOnly)

				# clarifying base
				$base = $_.directory.fullName

				# are we under "start menu\programs"
				if ($base.toLower().contains("start menu\programs")) {
					$base = "{0}Programs" -f ($base -split "programs")
				}

				if ($sourceBase) {
					$base = $sourceBase
				}

				# copy shortcut
				if ($prefix) {
					$rebaseRes = Copy-RebasedFile -source $_.fullName -base $base -target $target -prefix $prefix -prefixAction add
				}
				else {
					$rebaseRes = Copy-RebasedFile -source $_.fullName -base $base -target $target
				}

				# define scripts
				if ($scripts -eq '') {$scripts = "$target\scripts"}
				if (!(Test-Path $scripts)) { $null = New-Item -Path $scripts -ItemType Directory -Force }

				$scriptFile = $scripts + "\" + ([IO.FileInfo]$rebaseRes.target).baseName + ".ps1"

				# -- DEBUG --
				# write-output "===== $($_.baseName) ====="
				# "" | select `
				# @{n="shortcut to process"; e={$source}},
				# @{n="shortcut base"; e={$base}},
				# @{n="put to"; e={$rebaseRes.target}},
				# @{n="script"; e={$scriptFile}} | fl
				# write-output "------------"

				if (!($template)) {
					# put PS script template
					[IO.File]::writeAllBytes($scriptFile, (ConvertTo-UnPackedBytes -packedString $scriptTemplate))
				}
				else {
					copy-item -path $template -destination $scriptFile
				}

				$scriptContent = [IO.File]::readAllText($scriptFile)

				$s = $shell.createShortcut($rebaseRes.target)

				$wkdir = $s.workingDirectory
				if (!([string]::isNullOrEmpty($wkdir))) {

					# replace CMD environment variables with PS ones
					[regex]::matches($wkdir, "%([^%]+)%") | ForEach-Object {
						$wkdir = $wkdir.replace($_.groups[0].value, '$($env:' + $_.groups[1].value + ')')
					}
					$scriptContent = $scriptContent.replace("<# -WorkingDirectory `"`" #>", "-WorkingDirectory `"$wkdir`" # environment variables (if any) were replaced as-is. ensure, that working directory is resolved as expected")
				}
				$s.workingDirectory = ""

				# take care of icon
				if ($s.iconLocation.startsWith(",")) {
					$s.iconLocation = $s.targetPath + $s.iconLocation
				}

				$scriptContent = $scriptContent.replace("<filepath>", $s.targetPath)
				$s.targetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

				$arguments = $s.arguments
				if (!([string]::isNullOrEmpty($arguments))) {
					# replace CMD environment variables with PS ones
					[regex]::matches($arguments, "%([^%]+)%") | ForEach-Object {
						$arguments = $arguments.replace($_.groups[0].value, '$($env:' + $_.groups[1].value + ')')
					}
					$scriptContent = $scriptContent.replace("<# -ArgumentList `"`" #>", "-ArgumentList `"$($arguments.replace('"','``"'))`" # environment variables (if any) were replaced as-is. ensure, those are resolved as expected")
				}

				# save PS script
				[IO.File]::writeAllText($scriptFile, $scriptContent)

				$s.arguments = "-windowstyle hidden -executionpolicy bypass -file `"$scriptFile`""
				$s.description = $scriptFile
				$s.save()
			}
		}
	}
}