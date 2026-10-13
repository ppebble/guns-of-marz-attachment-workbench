param(
    [string]$GamePath='C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$WorkshopPath='C:\Program Files (x86)\Steam\steamapps\workshop\content\108600',
    [string]$Javac='C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe'
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force "$repo/.build" | Out-Null
& $Javac -d "$repo/.build" "$repo/tests/NativeInstalledModelsCheck.java"
if ($LASTEXITCODE -ne 0) { throw 'Native installed-model probe compilation failed' }
Push-Location $GamePath
try {
    foreach ($mod in @('GunsOfMarz','GunsOfMarzPreviousVersion')) {
        $script="$WorkshopPath/3722134990/mods/$mod/42.16/media/scripts/MarzWeapons/items/weapons/shotguns.txt"
        if (-not (Test-Path -LiteralPath $script)) { throw "Missing installed shotgun script: $script" }
        & "$GamePath/jre64/bin/java.exe" -cp "$repo/.build;$GamePath/projectzomboid.jar" NativeInstalledModelsCheck "$repo/Contents/mods/GoMAttachmentWorkbench/42/media/lua/client/GMAW/UI/InstalledModels.lua" $script
        if ($LASTEXITCODE -ne 0) { throw "Native installed-model probe failed: $mod" }
    }
    $ggsScripts="$WorkshopPath/3616176188/mods/GaelGunStore/42/media/scripts"
    if (-not (Test-Path -LiteralPath $ggsScripts)) { throw "Missing installed GGS scripts: $ggsScripts" }
    & "$GamePath/jre64/bin/java.exe" -cp "$repo/.build;$GamePath/projectzomboid.jar" NativeInstalledModelsCheck "$repo/Contents/mods/GoMAttachmentWorkbench/42/media/lua/client/GMAW/UI/InstalledModels.lua" $ggsScripts
    if ($LASTEXITCODE -ne 0) { throw 'Native installed-model probe failed: GGS' }
} finally { Pop-Location }
