param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$WorkshopPath = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$gom = Join-Path $WorkshopPath '3722134990/mods/GunsOfMarz/42.16'
$framework = Join-Path $WorkshopPath '3722064198/mods/Gunworks_gang_framework/42.13'
& node (Join-Path $PSScriptRoot 'extract-installed.cjs') $gom
if ($LASTEXITCODE -ne 0) { throw 'Extraction failed' }
if (-not (Test-Path (Join-Path $repo '.build/LuaHarness.class'))) { throw 'Run scripts/test.ps1 first' }
$files = @((Join-Path $repo 'tests/bootstrap.lua'), (Join-Path $repo 'tests/installed-bootstrap.test.lua'))
foreach ($name in @('RequiredAttachment','PreventRemovals','UpgradeExclusives','UniversalAttachment')) {
    $files += Join-Path $framework "media/lua/shared/WeaponSystems/Utils/$name.lua"
}
foreach ($name in @('AttachmentsRequiredParts','PermanentAttachments','UniversalAttachments','UpgradeExclusives')) {
    $files += Join-Path $gom "media/lua/shared/MarzWeapons/Registries/$name.lua"
}
$files += Join-Path $gom 'media/lua/shared/MarzWeapons/OnCreate/AttachAndDetach.lua'
foreach ($name in @('Model','Planner')) { $files += Join-Path $repo "Contents/mods/GoMAttachmentWorkbench/42/media/lua/shared/GMAW/$name.lua" }
$files += Join-Path $repo 'evidence/installed-fixtures.test.lua'
$files += Join-Path $repo 'tests/installed.test.lua'
$files += Join-Path $repo 'tests/native-actions-bootstrap.test.lua'
$files += Join-Path $GamePath 'media/lua/shared/TimedActions/ISUpgradeWeapon.lua'
$files += Join-Path $GamePath 'media/lua/shared/TimedActions/ISRemoveWeaponUpgrade.lua'
$files += Join-Path $framework 'media/lua/shared/WeaponSystems/Hooks/WeaponUpgradeHooks.lua'
$files += Join-Path $repo 'tests/native-actions.test.lua'
Push-Location $GamePath
try {
    & (Join-Path $GamePath 'jre64/bin/java.exe') -cp "$(Join-Path $repo '.build');$(Join-Path $GamePath 'projectzomboid.jar')" LuaHarness @files
    if ($LASTEXITCODE -ne 0) { throw 'Installed-data tests failed' }
} finally { Pop-Location }
