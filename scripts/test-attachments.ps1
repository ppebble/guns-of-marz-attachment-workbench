param(
    [switch]$Legacy,
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$WorkshopPath = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$variant = if ($Legacy) { 'GunsOfMarzPreviousVersion' } else { 'GunsOfMarz' }
$gom = Join-Path $WorkshopPath "3722134990/mods/$variant/42.16"
$gw = Join-Path $WorkshopPath '3722064198/mods/Gunworks_gang_framework/42.13/media/lua/shared'
$isil = Join-Path $WorkshopPath '3779164273/mods/Improvised Silencers/common/media/lua/shared'
$simple = Join-Path $WorkshopPath '3782565181/mods/simple-suppressors/42/media/lua/shared'
$lua = Join-Path $repo 'Contents/mods/GoMAttachmentWorkbench/42/media/lua/shared'
Push-Location $repo
try {
    & node scripts/extract-installed.cjs $gom
    if ($LASTEXITCODE -ne 0) { throw 'GoM extraction failed' }
    & node scripts/extract-attachments.cjs $WorkshopPath $gom
    if ($LASTEXITCODE -ne 0) { throw 'Attachment extraction failed' }
    $files = @("$repo/tests/bootstrap.lua", "$repo/evidence/installed-fixtures.test.lua",
        "$repo/evidence/attachment-fixtures.test.lua", "$repo/tests/attachments-installed-bootstrap.test.lua")
    foreach ($name in @('RequiredAttachment','PreventRemovals','UpgradeExclusives','UniversalAttachment')) {
        $files += "$gw/WeaponSystems/Utils/$name.lua"
    }
    foreach ($name in @('AttachmentsRequiredParts','PermanentAttachments','UniversalAttachments','UpgradeExclusives')) {
        $files += "$gom/media/lua/shared/MarzWeapons/Registries/$name.lua"
    }
    $files += "$isil/ISIL_MarzGunsCompatibility.lua"
    $files += "$simple/simple-suppressors/compatibility.lua"
    $files += "$simple/simple-suppressors/weaponsystemscompat.lua"
    foreach ($name in @('Attachments','Model','Planner','Sources','Batch','Presentation','Authority')) { $files += "$lua/GMAW/$name.lua" }
    $files += "$repo/tests/native-actions-bootstrap.test.lua"
    $files += "$GamePath/media/lua/shared/TimedActions/ISUpgradeWeapon.lua"
    $files += "$GamePath/media/lua/shared/TimedActions/ISRemoveWeaponUpgrade.lua"
    $files += "$gw/WeaponSystems/Hooks/WeaponUpgradeHooks.lua"
    if ($Legacy) { $files += "$gom/media/lua/shared/MarzWeapons/Hooks/UpgradeRemoveUpgradeReequipt.lua" }
    $files += "$isil/ISIL_SilencerStats.lua"
    $files += "$lua/GMAW/NativeCompletion.lua"
    $files += "$simple/simple-suppressors/suppressoractions.lua"
    $files += "$repo/Contents/mods/GoMAttachmentWorkbench/42/media/lua/server/GMAW/Server.lua"
    $files += "$repo/tests/attachments-installed.test.lua"
    Push-Location $GamePath
    try {
        $ErrorActionPreference = 'Continue' # Keep the full JVM/Kahlua trace on Windows PowerShell.
        & "$GamePath/jre64/bin/java.exe" -cp "$repo/.build;$GamePath/projectzomboid.jar" LuaHarness @files
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0) { throw 'Installed attachment integration failed' }
    } finally { Pop-Location }
} finally { Pop-Location }
