param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$Javac = 'C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lua = Join-Path $repo 'Contents/mods/GoMAttachmentWorkbench/42/media/lua'
New-Item -ItemType Directory -Force (Join-Path $repo '.build') | Out-Null
& $Javac -d (Join-Path $repo '.build') (Join-Path $repo 'tests/LuaHarness.java') (Join-Path $repo 'tests/TranslationHarness.java')
if ($LASTEXITCODE -ne 0) { throw 'Harness compilation failed' }
$files = @((Join-Path $repo 'tests/bootstrap.lua'))
foreach ($name in @('Model','Planner','Sources','Batch','Presentation','Authority')) { $files += Join-Path $lua "shared/GMAW/$name.lua" }
$files += Join-Path $repo 'tests/ui-bootstrap.test.lua'
$files += Join-Path $repo 'tests/actions-bootstrap.test.lua'
$files += Join-Path $lua 'shared/GMAW/NativeCompletion.lua'
$files += Join-Path $lua 'client/GMAW/Actions.lua'
$files += Join-Path $lua 'client/GMAW/Window.lua'
$files += Join-Path $lua 'server/GMAW/Server.lua'
foreach ($test in @('planner','batch','sources','presentation','window','authority','server-authority','actions')) { $files += Join-Path $repo "tests/$test.test.lua" }
Push-Location $GamePath
try {
    & (Join-Path $GamePath 'jre64/bin/java.exe') -cp "$(Join-Path $repo '.build');$(Join-Path $GamePath 'projectzomboid.jar')" LuaHarness @files
    if ($LASTEXITCODE -ne 0) { throw 'Lua tests failed' }
    & (Join-Path $GamePath 'jre64/bin/java.exe') -cp "$(Join-Path $repo '.build');$(Join-Path $GamePath 'projectzomboid.jar')" TranslationHarness (Split-Path (Split-Path $lua -Parent) -Parent)
    if ($LASTEXITCODE -ne 0) { throw 'Native translation reader failed' }
} finally { Pop-Location }
& node (Join-Path $repo 'tests/contracts.test.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Contracts failed' }
