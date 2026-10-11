param(
    [string]$ZomboidRoot = (Join-Path $env:USERPROFILE 'Zomboid'),
    [string]$DedicatedRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Dedicated Server',
    [string]$DesktopPath = [Environment]::GetFolderPath('Desktop')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$serverRoot = Join-Path $ZomboidRoot 'Server'
$name = 'gael-test'
$suffixes = @('.ini', '_SandboxVars.lua', '_spawnpoints.lua', '_spawnregions.lua')
$base = Join-Path $serverRoot 'emre-test.ini'
$launcher = Join-Path $DedicatedRoot 'StartServer64gael-test.bat'
$shortcutPath = Join-Path $DesktopPath 'gael-test-server.lnk'
$utf8 = New-Object System.Text.UTF8Encoding($false)
# Steam searches local Workshop staging before Zomboid/mods. An older staged
# copy with require=SWMG can make the workbench unavailable on a Gael server.
$sourceMod = Join-Path $repo 'Contents/mods/GoMAttachmentWorkbench'
$stagedMod = Join-Path $ZomboidRoot 'Workshop/GoMAttachmentWorkbench/Contents/mods/GoMAttachmentWorkbench'
foreach ($copyRoot in @((Join-Path $ZomboidRoot 'mods/GoMAttachmentWorkbench'), $stagedMod)) {
    if ($copyRoot -eq $stagedMod -and -not (Test-Path -LiteralPath $copyRoot)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $sourceMod -Recurse -File) {
        $relative = $file.FullName.Substring($sourceMod.Length + 1)
        $copy = Join-Path $copyRoot $relative
        if (-not (Test-Path -LiteralPath $copy) -or
            (Get-FileHash -LiteralPath $copy).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) {
            throw "Workbench copy missing or outdated: $copy. Synchronize local/staged mod content before creating a Steam test server; preserve Workshop metadata."
        }
    }
}
foreach ($path in @($base, (Join-Path $serverRoot 'emre-test_SandboxVars.lua'),
    (Join-Path $DedicatedRoot 'StartServer64emre-test.bat'), $DesktopPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing prerequisite: $path" }
}
# A new name creates a separate world and account database. Never overwrite a
# previously used test profile or copy an existing multiplayer save/database.
foreach ($path in @($launcher, $shortcutPath, (Join-Path $ZomboidRoot 'Saves/Multiplayer/gael-test'),
    (Join-Path $ZomboidRoot 'db/gael-test.db')) + @($suffixes | ForEach-Object {Join-Path $serverRoot "$name$_"})) {
    if (Test-Path -LiteralPath $path) { throw "New test target already exists: $path" }
}
foreach ($ini in Get-ChildItem -LiteralPath $serverRoot -Filter '*.ini') {
    if ([IO.File]::ReadAllText($ini.FullName) -match '(?m)^(?:DefaultPort|UDPPort|RCONPort)=(?:16269|16270|27019)\s*$') {
        throw "Chosen test ports already configured in $($ini.Name)"
    }
}
$occupied = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -in @(16269,16270)})
$occupied += @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -eq 27019})
if ($occupied.Count) { throw 'A selected test port is in use.' }
$preserved = @{}
foreach ($profile in @('b42211002','emre-test')) {
    foreach ($suffix in $suffixes) {
        $path = Join-Path $serverRoot "$profile$suffix"
        $preserved[$path] = (Get-FileHash -LiteralPath $path).Hash
    }
}
$text = [IO.File]::ReadAllText($base)
$batch = [IO.File]::ReadAllText((Join-Path $DedicatedRoot 'StartServer64emre-test.bat'))
if ($batch -notmatch '-servername emre-test') { throw 'Base launcher profile not found' }
$batch = $batch.Replace('-servername emre-test','-servername gael-test')
$settings = [ordered]@{
    Mods='GaelGunStore_B42;GoMAttachmentWorkbench'
    WorkshopItems='3616176188'
    Map='Muldraugh, KY'
    Public='false'
    PublicName='GaelGunStore Workbench Test'
    DefaultPort='16269'
    UDPPort='16270'
    RCONPort='27019'
    UPnP='false'
    ResetID=(Get-Random -Minimum 10000000 -Maximum 99999999).ToString()
    ServerPlayerID=(Get-Random -Minimum 100000000 -Maximum 999999999).ToString()
}
foreach ($key in $settings.Keys) {
    $pattern = '(?m)^' + [regex]::Escape($key) + '=.*$'
    if (-not [regex]::IsMatch($text,$pattern)) { throw "Missing base setting: $key" }
    $replacement = $key + '=' + $settings[$key]
    $text = [regex]::Replace($text,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{param($match) $replacement})
}
[IO.File]::WriteAllText((Join-Path $serverRoot "$name.ini"),$text,$utf8)
Copy-Item -LiteralPath (Join-Path $serverRoot 'emre-test_SandboxVars.lua') -Destination (Join-Path $serverRoot "${name}_SandboxVars.lua")
Copy-Item -LiteralPath (Join-Path $serverRoot 'emre-test_spawnpoints.lua') -Destination (Join-Path $serverRoot "${name}_spawnpoints.lua")
$regions = @'
function SpawnRegions()
    return {
        { name = "Muldraugh, KY", file = "media/maps/Muldraugh, KY/spawnpoints.lua" },
        { name = "Riverside, KY", file = "media/maps/Riverside, KY/spawnpoints.lua" },
        { name = "Rosewood, KY", file = "media/maps/Rosewood, KY/spawnpoints.lua" },
        { name = "West Point, KY", file = "media/maps/West Point, KY/spawnpoints.lua" },
    }
end
'@
[IO.File]::WriteAllText((Join-Path $serverRoot "${name}_spawnregions.lua"),$regions,$utf8)
[IO.File]::WriteAllText($launcher,$batch,[Text.Encoding]::ASCII)
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcher
$shortcut.WorkingDirectory = $DedicatedRoot
$shortcut.Description = 'GaelGunStore + local Attachment Workbench test server (16269)'
$shortcut.Save()
foreach ($path in $preserved.Keys) {
    if ((Get-FileHash -LiteralPath $path).Hash -ne $preserved[$path]) { throw "Existing profile changed: $path" }
}
$saved = $shell.CreateShortcut($shortcutPath)
if ($saved.TargetPath -ne $launcher -or $saved.WorkingDirectory -ne $DedicatedRoot) { throw 'Shortcut verification failed' }
$files = @($launcher,$shortcutPath) + @($suffixes | ForEach-Object {Join-Path $serverRoot "$name$_"})
New-Item -ItemType Directory -Force (Join-Path $repo 'evidence') | Out-Null
@{profile=$name; sourceProfile='emre-test'; ports=@(16269,16270,27019);
    files=@($files | ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}});
    preservedProfiles=$preserved} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $repo 'evidence/gael-test-server-setup.json') -Encoding UTF8
Write-Output "PASS new profile $name; existing GoM and Emre profiles unchanged."
Write-Output "PASS shortcut: $shortcutPath"
Write-Output 'Gael + local workbench only; vanilla maps; ports 16269/16270; no existing world or account copied.'
