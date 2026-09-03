function Unzip-File {
    param([string]$Path, [string]$DestinationPath)

    $null = New-Item -Path $DestinationPath -ItemType Directory
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
}