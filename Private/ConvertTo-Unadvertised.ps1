function ConvertTo-Unadvertised {
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[alias("FullName")][string]$shortcut
	)

	# use ConvertTo-PackedString -byteArray ([IO.File]::ReadAllBytes("<full path to>\DISABLEADVTSHORTCUTS.mst"))
	$transform = "H4sIAAAAAAAEAO2cPWzTQBTHn91P2oJSvgYG5AFBJeQQN4njUqmNE7ukUqVKTYqAzTSmMUoTSF0BQpUqBGJmY+JjZgJWBthYEB0QEluROjB3YyDh7HNKFATUgYFW/5/1dPV75/u/2rfcu1PW3w9vPH1+7DO1MUHdVG8MUW9wL7SYT4RIDO7rjUaj6W6AXUX7dwcAAAAAAAAAsDf5xtaA9RYDAAAAAAAAAADA3mOOquxySSKTKqyt0a1Q9YOj1LO959/F7u9Ehnz/ax6eau27rmTn1958FLx+6S7uS+cumltGyUyd66x+MUSi0Pr/7OQZ79xC81xDOjc5ecMsG1cnXhhncuH1I4F+N/GzDzt5RvDzbtMf3zRPdKjvjSeG0Pc4ErQ9lKcVWmKX5X/7aTYLrrAZUfM9Ljns78pvxhlhymHfv/fpS+JOM/0zYfX/NdCHPvShD33oQx/60Ic+9KG/G/Rb9/69NWwP8bVxH7N+ZvuYDTAbJL5mxRkBAAAAAAAAAABg92FM5/XMjKkb5wv53OxcITtfyCsh6geb3USHSfCvThBEgf5mK7jeIOoVfx7By2bj3uOtr7OlyLMH/XT61MtPMebTWNcDQfwm8X3zNeJ70k+YeTWQV8TrIB+I10K+EK99zLCHDrL2AmsPsbYk8DrJNYHXSu4KvF7yUOAaI6L/MwkUE7mO966Ok3dmgmi6suxa5bLlOtWKZFiuddlatonHh4O4WZSUaDKqJKOjKgWx/cwcFrOLjhtdqC41/QM/xrRrge8Ss0LJWZacZkAqBkrSQrXiWswvuSVbKlcXnQXJqhT9uFSzr684NbsoudXmo1J7PlE2dtoTP7u48ujkO8HT69vOm79PMchj0Pe7dnlcicXjv/bdZ3Zbz6ZMPZlKyuqUYsiJuJqUdVU15YyWmMoqmp7SEsbqdhrjoftrxtioYWYUWU8qqpzIxOKyloorshobSyVUbTSjjmVXef5vg3kx2enkBAAAAAAAAID/iO+X1gr7AFAAAA=="

	if (test-path $shortcut) {
		$target = $shell.createShortcut($shortcut).targetPath
		if ($target.toLower().startsWith("c:\windows\installer")) {
			$ProductCode = (get-item $target).Directory.BaseName
		}
	}

	if ($ProductCode) {
		if (!(test-path "$($env:windir)\Installer\$ProductCode\DISABLEADVTSHORTCUTS.mst")) {
			[IO.File]::WriteAllBytes("$($env:windir)\Installer\$ProductCode\DISABLEADVTSHORTCUTS.mst", (ConvertTo-UnPackedBytes -packedString $transform))

			$bytes = $ProductCode.replace("{", "").replace("-", "").replace("}", "").toCharArray()
			$PackedGUID = [string]::join("", ($bytes[7..0] + $bytes[11..8] + $bytes[15..12] + $bytes[17..16] + $bytes[19..18] + $bytes[21..20] + $bytes[23..22] + $bytes[25..24] + $bytes[27..26] + $bytes[29..28] + $bytes[31..30]))
			$transforms = (get-itemProperty "HKLM:\SOFTWARE\Classes\Installer\Products\$PackedGUID").'Transforms'

			if ($transforms) {
				$transforms += ";"
			}
			$transforms += "$($env:windir)\Installer\$ProductCode\DISABLEADVTSHORTCUTS.mst"
			New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\$PackedGUID" -Name "Transforms" -PropertyType "String" -Value $transforms -Force | out-null
			Start-Process -FilePath "msiexec.exe" -ArgumentList "/fs $ProductCode /qb" -WindowStyle Normal -Wait
		}
	}
}