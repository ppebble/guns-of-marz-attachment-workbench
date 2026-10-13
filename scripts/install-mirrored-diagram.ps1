# Safely mirror the workbench diagram on the next game restart.
# Replaces only owned Window.lua copies, never dependency mods or game files.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$rel = '42\media\lua\client\GMAW\Window.lua'
$source = Join-Path $repo ('Contents\mods\GoMAttachmentWorkbench\' + $rel)
$expectedSource = '1C401CF99D9206FAD98FC879FF8729BBB5FFBFD44B361196FA172BA3112582E4'
$expectedPrevious = '46D23531DED00A885057A01B579823890B5C3D919A389D169E4D1B9F81A6E824'
$destinations = @(
    [pscustomobject]@{
        Name = 'local'
        Path = (Join-Path $env:USERPROFILE ('Zomboid\mods\GoMAttachmentWorkbench\' + $rel))
    },
    [pscustomobject]@{
        Name = 'staged'
        Path = (Join-Path $env:USERPROFILE ('Zomboid\Workshop\GoMAttachmentWorkbench\Contents\mods\GoMAttachmentWorkbench\' + $rel))
    }
)
$active = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('ProjectZomboid64.exe','ProjectZomboid.exe') -or
    ($_.Name -in @('java.exe','javaw.exe') -and $_.CommandLine -match 'zombie[.]network[.]GameServer')
})
if ($active.Count -gt 0) {
    throw 'Close the PZ client and ALL dedicated servers first. Nothing was copied.'
}
if (-not (Test-Path -LiteralPath $source) -or
    (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $expectedSource) {
    throw 'Source Window.lua differs from tested mirror patch. Nothing was copied.'
}
foreach($d in $destinations) {
    if (-not (Test-Path -LiteralPath $d.Path) -or
        (Get-FileHash -LiteralPath $d.Path -Algorithm SHA256).Hash -ne $expectedPrevious) {
        throw "$($d.Name) Window.lua has changed. Nothing was copied."
    }
}
$backupDir = Join-Path $repo ('evidence\backups\mirrored-diagram-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
foreach($d in $destinations) {
    Copy-Item -LiteralPath $d.Path -Destination (Join-Path $backupDir ($d.Name + '-Window.lua'))
}
foreach($d in $destinations) {
    Copy-Item -LiteralPath $source -Destination $d.Path -Force
    $actual = (Get-FileHash -LiteralPath $d.Path -Algorithm SHA256).Hash
    if ($actual -ne $expectedSource) { throw "Hash mismatch after installing $($d.Name)" }
    Write-Output "PASS $($d.Name): $actual"
}
Write-Output "Backups: $backupDir"
Write-Output 'Only the two Window.lua copies changed. No Steam upload or dependency edits.'
