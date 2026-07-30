$root = 'C:\Users\sanje\apps\mastui'
Write-Host "=== build ==="
Get-ChildItem "$root\build" -Directory | ForEach-Object {
    $name = $_.Name
    $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  $name : $([math]::Round($size)) MB"
}
Write-Host ""
Write-Host "=== assets ==="
Get-ChildItem "$root\assets" -Directory | ForEach-Object {
    $name = $_.Name
    $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  $name : $([math]::Round($size)) MB"
}
Write-Host ""
Write-Host "=== .dart_tool ==="
Get-ChildItem "$root\.dart_tool" -Directory | ForEach-Object {
    $name = $_.Name
    $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  $name : $([math]::Round($size)) MB"
}
Write-Host ""
Write-Host "=== .git ==="
$gitSize = (Get-ChildItem "$root\.git" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "  .git : $([math]::Round($gitSize)) MB"
