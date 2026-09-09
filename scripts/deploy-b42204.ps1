param(
    [string]$ZomboidRoot = (Join-Path $HOME 'Zomboid'),
    [string]$PresetPath = (Join-Path $HOME 'Zomboid\Lua\pz_modlist_settings.cfg'),
    [string]$ServerPath = (Join-Path $HOME 'Zomboid\Server\b42204.ini')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'Contents\mods\GoMAttachmentWorkbench'
$modsPath = Join-Path $ZomboidRoot 'mods'
$workshopRoot = Join-Path $ZomboidRoot 'Workshop'

# The local Mods copy is used by the local client/server preset.  The Workshop
# staging copy is also refreshed because the current b42204 log resolves this
# development item through Zomboid\Workshop before a Steam ID exists.
& (Join-Path $PSScriptRoot 'install-local.ps1') -ModsPath $modsPath
& (Join-Path $PSScriptRoot 'stage-workshop.ps1') -DestinationRoot $workshopRoot
& (Join-Path $PSScriptRoot 'add-to-b42204-preset.ps1') -PresetPath $PresetPath -ServerPath $ServerPath

$targets = @(
    (Join-Path $modsPath 'GoMAttachmentWorkbench'),
    (Join-Path $workshopRoot 'GoMAttachmentWorkbench\Contents\mods\GoMAttachmentWorkbench')
)
foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target)) { throw "Missing deployment target: $target" }
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
        $relative = $file.FullName.Substring($source.Length).TrimStart('\','/')
        $deployed = Join-Path $target $relative
        if (-not (Test-Path -LiteralPath $deployed)) { throw "Missing deployed file: $deployed" }
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $deployed -Algorithm SHA256).Hash) {
            throw "Deployment hash mismatch: $relative ($target)"
        }
    }
    Write-Output "PASS synchronized $target"
}

$serverMods = ([regex]::Match([IO.File]::ReadAllText($ServerPath), '(?m)^Mods=(.*)$')).Groups[1].Value -split ';'
$presetMods = ([regex]::Match([IO.File]::ReadAllText($PresetPath), '(?m)^b42204:(.*)$')).Groups[1].Value -split ';'
foreach ($list in @($serverMods, $presetMods)) {
    $gunIndex = [Array]::IndexOf([string[]]$list, 'GunsOfMarz')
    if ($gunIndex -lt 0 -or $gunIndex + 1 -ge $list.Count -or $list[$gunIndex + 1] -ne 'GoMAttachmentWorkbench') {
        throw 'GoMAttachmentWorkbench must load immediately after GunsOfMarz'
    }
}
Write-Output 'PASS b42204 client preset and server Mods load GoMAttachmentWorkbench immediately after GunsOfMarz.'
Write-Output 'Restart the host and reconnect clients after this deployment. WorkshopItems remains empty until Steam assigns this mod its own Workshop ID.'
