function Show-Tree {
    param (
        [string]$Path = ".",
        [string]$Prefix = "",
        [bool]$IsRoot = $true
    )

    # Resolve and validate path
    $Path = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $Path) {
        Write-Host "Path not found." -ForegroundColor Red
        return
    }

    # Print root folder
    if ($IsRoot) {
        $rootName = Split-Path $Path -Leaf
        Write-Host "📁 $rootName"
    }

    # Get all items (folders first, then files)
    $items = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue |
             Sort-Object { -not $_.PSIsContainer }, Name

    for ($i = 0; $i -lt $items.Count; $i++) {
        $item      = $items[$i]
        $isLast    = ($i -eq $items.Count - 1)
        $connector = if ($isLast) { "└── " } else { "├── " }
        $childPfx  = if ($isLast) { "    " } else { "│   " }

        if ($item.PSIsContainer) {
            Write-Host "$Prefix$connector📁 $($item.Name)" -ForegroundColor Cyan
            Show-Tree -Path $item.FullName -Prefix "$Prefix$childPfx" -IsRoot $false
        } else {
            Write-Host "$Prefix$connector📄 $($item.Name)" -ForegroundColor White
        }
    }
}