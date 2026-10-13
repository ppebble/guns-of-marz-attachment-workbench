# Install ONLY owned workbench UI/visual profile files after PZ shuts down.
# Does not touch saves, presets, the actual firearm mods or Steam publishing.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repo 'Contents\mods\GoMAttachmentWorkbench\42\media\lua\client\GMAW'
$oldWindowHash = '68BD2FD81977A65CB83187D0D39CF2342D4ADA1A72AD81C1B83C144DD0E28C2E'
$files = [ordered]@{
    'Window.lua'                  = '3A479820148A3668B334FD8A7499FB76C7DA2009D6574146743F25B7A95B9D5D'
    'UI\AttachmentAnchors.lua'    = '93BEFBD511E490C0FAA974B696B4A717C1DE6AC41ACC16C2A43351F0477F8095'
    'UI\ProfileRegistry.lua'      = '15E42E562BD3A65A5CDAB4289ECF6FDC20E8D3B092BD3BF26253D0571ADF1A47'
    'UI\Profiles\Gael.lua'       = '56123A8B3FEBA84E3626297D540D6A109FCA641DD3DA531337E5B52D291FF26E'
    'UI\Profiles\GoM.lua'        = 'C08CF31C0CAF3D72D4E852A65BC8398666A81F90D91E9C462272E833ACE8D5DB'
}
$destinations = @(
    [pscustomobject]@{ Name='local'; Root=(Join-Path $env:USERPROFILE 'Zomboid\mods\GoMAttachmentWorkbench\42\media\lua\client\GMAW') },
    [pscustomobject]@{ Name='workshop-staged'; Root=(Join-Path $env:USERPROFILE 'Zomboid\Workshop\GoMAttachmentWorkbench\Contents\mods\GoMAttachmentWorkbench\42\media\lua\client\GMAW') }
)
$active = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('ProjectZomboid64.exe', 'ProjectZomboid.exe') -or
    ($_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine -match 'zombie[.]network[.]GameServer')
})
if ($active.Count -gt 0) { throw 'Close Project Zomboid client and all dedicated servers first. No files copied.' }

foreach ($relative in $files.Keys) {
    $path=Join-Path $sourceRoot $relative
    if (-not (Test-Path -LiteralPath $path) -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $files[$relative]) {
        throw "Source changed since verification: $relative. No files copied."
    }
}
# Full preflight before ANY writes; refuse to overwrite unrelated local edits.
foreach ($dest in $destinations) {
    foreach ($relative in $files.Keys) {
        $path=Join-Path $dest.Root $relative
        if ($relative -eq 'Window.lua' -and -not (Test-Path -LiteralPath $path)) {
            throw "Expected installed Window.lua was not found: $($dest.Name)"
        }
        if (Test-Path -LiteralPath $path) {
            $actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            if ($relative -eq 'Window.lua') {
                if ($actual -ne $oldWindowHash -and $actual -ne $files[$relative]) {
                    throw "$($dest.Name) Window.lua changed unexpectedly. No files copied."
                }
            } elseif ($actual -ne $files[$relative]) {
                throw "$($dest.Name) has modified UI profile file: $relative. No files copied."
            }
        }
    }
}
$backupRoot = Join-Path $repo ('evidence\backups\ui-profiles-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$changes = @()
# Preserve existing files and remember new ones for rollback.
foreach ($dest in $destinations) {
    foreach ($relative in $files.Keys) {
        $target=Join-Path $dest.Root $relative
        $existed=Test-Path -LiteralPath $target
        $backup=Join-Path (Join-Path $backupRoot $dest.Name) $relative
        if ($existed) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $backup -Force
        }
        $changes += [pscustomobject]@{ Target=$target; Backup=$backup; Existed=$existed }
    }
}
try {
    foreach ($dest in $destinations) {
        foreach ($relative in $files.Keys) {
            $source=Join-Path $sourceRoot $relative
            $target=Join-Path $dest.Root $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
            $actual=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            if ($actual -ne $files[$relative]) { throw "$($dest.Name) hash mismatch: $relative" }
            Write-Output "PASS $($dest.Name) $relative"
        }
    }
} catch {
    $installError=$_
    foreach ($change in $changes) {
        if ($change.Existed) {
            Copy-Item -LiteralPath $change.Backup -Destination $change.Target -Force
        } elseif (Test-Path -LiteralPath $change.Target) {
            Remove-Item -LiteralPath $change.Target -Force
        }
    }
    throw $installError
}
Write-Output "BACKUP $backupRoot"
Write-Output 'Source and both installed trees match for five workbench client UI files.'
Write-Output 'No Steam upload, upstream mod edits, world/save or server-configuration changes.'
