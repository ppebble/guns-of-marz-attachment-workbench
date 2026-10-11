param(
    [switch]$Installed,
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$WorkshopPath = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lua = Join-Path $repo 'Contents/mods/GoMAttachmentWorkbench/42/media/lua'
$gael = Join-Path $WorkshopPath '3616176188/mods/GaelGunStore/42'
$files = @("$repo/tests/bootstrap.lua", "$repo/tests/ui-bootstrap.test.lua", "$repo/tests/actions-bootstrap.test.lua",
    "$repo/tests/provider-bootstrap.test.lua",
    "$GamePath/media/lua/shared/TimedActions/ISUpgradeWeapon.lua",
    "$GamePath/media/lua/shared/TimedActions/ISRemoveWeaponUpgrade.lua")
if ($Installed) {
    & node "$PSScriptRoot/extract-gael.cjs" $gael
    if ($LASTEXITCODE -ne 0) { throw 'Gael extraction failed' }
    $files += "$repo/evidence/gael-fixtures.test.lua"
    $files += "$gael/media/lua/shared/GGS_AttachmentDependenciesData.lua"
    $files += "$gael/media/lua/shared/GGS_AttachmentDependencies.lua"
    $files += "$gael/media/lua/shared/FixCode/GGS_WeaponPartTimedActionFix.lua"
}
foreach ($name in @('Framework','Providers/GoM','Providers/Gael','Adapters','Attachments','Model','Planner','Sources','Batch','Presentation','Authority','NativeCompletion')) {
    $files += "$lua/shared/GMAW/$name.lua"
}
$files += "$lua/client/GMAW/Actions.lua"
$files += "$lua/client/GMAW/Window.lua"
$files += "$lua/server/GMAW/Server.lua"
$files += "$repo/tests/gael-provider.test.lua"
Push-Location $GamePath
try {
    & "$GamePath/jre64/bin/java.exe" -cp "$repo/.build;$GamePath/projectzomboid.jar" LuaHarness @files
    if ($LASTEXITCODE -ne 0) { throw 'Gael provider tests failed' }
} finally { Pop-Location }
