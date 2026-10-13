# Installs ONLY the UI 3D preview correction after both game and dedicated server exit.
# Refuses to overwrite a different/modified local or Workshop-staged Window.lua.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$rel = '42\media\lua\client\GMAW\Window.lua'
$source = Join-Path $repo ('Contents\mods\GoMAttachmentWorkbench\' + $rel)
$expectedSource = '46D23531DED00A885057A01B579823890B5C3D919A389D169E4D1B9F81A6E824'
$expectedPrior = 'CB2B13CBD7300B10ACBACC2B1B92B8A2A77E25ED92D87D67CE3C3DF35C52D0F5'
$destinations = @(
    [pscustomobject]@{ Name = 'local'; Path = (Join-Path $env:USERPROFILE ('Zomboid\mods\GoMAttachmentWorkbench\' + $rel)) },
    [pscustomobject]@{ Name = 'workshop-staging'; Path = (Join-Path $env:USERPROFILE ('Zomboid\Workshop\GoMAttachmentWorkbench\Contents\mods\GoMAttachmentWorkbench\' + $rel)) }
)
$active = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('ProjectZomboid64.exe', 'ProjectZomboid.exe') -or
    ($_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine -match 'zombie[.]network[.]GameServer')
})
if ($active.Count -gt 0) {
    throw "Close the PZ client AND every dedicated server first. Nothing was copied."
}
if (-not (Test-Path -LiteralPath $source)) { throw 'Workbench source Window.lua is missing.' }
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $expectedSource) {
    throw 'Workbench source Window.lua changed since verification. Re-test before installing.'
}
foreach ($dest in $destinations) {
    if (-not (Test-Path -LiteralPath $dest.Path)) { throw "Missing $($dest.Name) Window.lua: $($dest.Path)" }
    if ((Get-FileHash -LiteralPath $dest.Path -Algorithm SHA256).Hash -ne $expectedPrior) {
        throw "$($dest.Name) Window.lua differs from the verified prior version. Preserve those changes; no files copied."
    }
}
$backups = Join-Path $repo ('evidence\backups\fixed-camera-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force -Path $backups | Out-Null
foreach ($dest in $destinations) {
    Copy-Item -LiteralPath $dest.Path -Destination (Join-Path $backups ($dest.Name + '-Window.lua'))
}
foreach ($dest in $destinations) {
    Copy-Item -LiteralPath $source -Destination $dest.Path -Force
    $hash = (Get-FileHash -LiteralPath $dest.Path -Algorithm SHA256).Hash
    if ($hash -ne $expectedSource) { throw "$($dest.Name) copy verification failed." }
    Write-Output "PASS $($dest.Name): $hash"
}
Write-Output "Backups: $backups"
Write-Output 'Only the two Window.lua copies changed. No Steam upload, saved-game edits, dependency edits or server preset changes.'
