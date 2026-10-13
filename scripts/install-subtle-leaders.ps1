# Install a style-only UI update after both the game and dedicated server exit.
# Keep other source changes, dependency mods, Workshop metadata, and saves intact.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$relative = '42\media\lua\client\GMAW\Window.lua'
$source = Join-Path $repo ('Contents\mods\GoMAttachmentWorkbench\' + $relative)
$sourceHash = '68BD2FD81977A65CB83187D0D39CF2342D4ADA1A72AD81C1B83C144DD0E28C2E'
$installedHash = '1C401CF99D9206FAD98FC879FF8729BBB5FFBFD44B361196FA172BA3112582E4'
$destinations = @(
    [pscustomobject]@{
        Name = 'local'
        Path = Join-Path $env:USERPROFILE ('Zomboid\mods\GoMAttachmentWorkbench\' + $relative)
    },
    [pscustomobject]@{
        Name = 'staged'
        Path = Join-Path $env:USERPROFILE ('Zomboid\Workshop\GoMAttachmentWorkbench\Contents\mods\GoMAttachmentWorkbench\' + $relative)
    }
)
$active = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('ProjectZomboid64.exe', 'ProjectZomboid.exe') -or
    ($_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine -match 'zombie[.]network[.]GameServer')
})
if ($active.Count -gt 0) {
    throw 'Close Project Zomboid AND all dedicated servers before installing. No files were copied.'
}
if (-not (Test-Path -LiteralPath $source) -or
    (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $sourceHash) {
    throw 'Source differs from verified styling changes. No files were copied.'
}
foreach ($d in $destinations) {
    if (-not (Test-Path -LiteralPath $d.Path) -or
        (Get-FileHash -LiteralPath $d.Path -Algorithm SHA256).Hash -ne $installedHash) {
        throw "$($d.Name) installation has changed. Preserve it and re-verify before copying."
    }
}
$backup = Join-Path $repo ('evidence\backups\subtle-leaders-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach ($d in $destinations) {
    Copy-Item -LiteralPath $d.Path -Destination (Join-Path $backup ($d.Name + '-Window.lua'))
}
foreach ($d in $destinations) {
    Copy-Item -LiteralPath $source -Destination $d.Path -Force
    $actual = (Get-FileHash -LiteralPath $d.Path -Algorithm SHA256).Hash
    if ($actual -ne $sourceHash) { throw "Hash mismatch: $($d.Name)" }
    Write-Output "PASS $($d.Name): $actual"
}
Write-Output "Backups: $backup"
Write-Output 'Updated only both workbench Window.lua files; no Steam upload or server changes.'
