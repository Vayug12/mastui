$root = 'C:\Users\sanje\apps\mastui'
Get-ChildItem $root -Directory | ForEach-Object {
    $name = $_.Name
    $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "$name : $([math]::Round($size)) MB"
}
