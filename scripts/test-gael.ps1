param(
    [switch]$Installed,
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$WorkshopPath = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600',
    [string]$Javac = 'C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe'
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
    & node "$PSScriptRoot/audit-ggs-anchors.cjs" $gael
    if ($LASTEXITCODE -ne 0) { throw 'GGS attachment audit failed' }
    $files += "$repo/evidence/gael-fixtures.test.lua"
    $files += "$gael/media/lua/shared/GGS_AttachmentDependenciesData.lua"
    $files += "$gael/media/lua/shared/GGS_AttachmentDependencies.lua"
    $files += "$gael/media/lua/shared/FixCode/GGS_WeaponPartTimedActionFix.lua"
}
foreach ($name in @('Framework','Providers/GoM','Providers/Gael','Adapters','Attachments','Model','Planner','Sources','Batch','Presentation','Authority','NativeCompletion')) {
    $files += "$lua/shared/GMAW/$name.lua"
}
$files += "$lua/client/GMAW/Actions.lua"
foreach ($name in @('UI/Profiles/GoM','UI/Profiles/Gael','UI/ProfileRegistry','UI/AttachmentAnchors','UI/LayoutPreferences')) {
    $files += "$lua/client/GMAW/$name.lua"
}
$files += "$lua/client/GMAW/Window.lua"
$files += "$lua/server/GMAW/Server.lua"
$files += "$repo/tests/gael-provider.test.lua"
if ($Installed) {
    $files += "$repo/evidence/ggs-anchor-audit/fixtures.test.lua"
    $files += "$repo/tests/ggs-anchors-installed.test.lua"
}
Push-Location $GamePath
try {
    & "$GamePath/jre64/bin/java.exe" -cp "$repo/.build;$GamePath/projectzomboid.jar" LuaHarness @files
    if ($LASTEXITCODE -ne 0) { throw 'Gael provider tests failed' }
    if ($Installed) {
        & $Javac -d "$repo/.build" "$repo/tests/NativeSceneProjectionCheck.java"
        if ($LASTEXITCODE -ne 0) { throw 'Native projection probe compilation failed' }
        & "$GamePath/jre64/bin/java.exe" -cp "$repo/.build;$GamePath/projectzomboid.jar" NativeSceneProjectionCheck "$gael/media/scripts/Firearms_model/Rifles_automaticos_model.txt"
        if ($LASTEXITCODE -ne 0) { throw 'Native scene projection contract failed' }
    }
} finally { Pop-Location }
