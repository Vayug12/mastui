$root = 'C:\Users\sanje\apps\mastui'
Write-Host "=== assets/designs ==="
Get-ChildItem "$root\assets\designs" | ForEach-Object {
    $name = $_.Name
    if ($_.PSIsContainer) {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "  [DIR] $name : $([math]::Round($size)) MB"
    } else {
        $size = $_.Length / 1MB
        Write-Host "  [FILE] $name : $([math]::Round($size,2)) MB"
    }
}
Write-Host ""
Write-Host "=== pipeline ==="
Get-ChildItem "$root\pipeline" | ForEach-Object {
    $name = $_.Name
    if ($_.PSIsContainer) {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "  [DIR] $name : $([math]::Round($size)) MB"
    } else {
        $size = $_.Length / 1MB
        Write-Host "  [FILE] $name : $([math]::Round($size,2)) MB"
    }
}
