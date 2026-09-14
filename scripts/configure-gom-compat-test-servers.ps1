param(
    [string]$ZomboidRoot = (Join-Path $HOME 'Zomboid'),
    [string]$DedicatedRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Dedicated Server',
    [string]$DesktopPath = (Join-Path $HOME 'Desktop')
)

$ErrorActionPreference = 'Stop'

# b42204 stays the current-GoM test world.  b42204-gom-old is a separate,
# fresh world because its Mod ID changes from GunsOfMarz to MarzGuns.
$currentName = 'b42204'
$legacyName = 'b42204-gom-old'
$serverRoot = Join-Path $ZomboidRoot 'Server'
$presetPath = Join-Path $ZomboidRoot 'Lua\pz_modlist_settings.cfg'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Get-Tokens([string]$value) {
    return @($value -split ';' | Where-Object { $_ -ne '' })
}

function Set-Tokens([string[]]$tokens) {
    return ($tokens -join ';')
}

function Ensure-Token([string[]]$tokens, [string]$token) {
    if ($tokens -notcontains $token) { $tokens += $token }
    return $tokens
}

function Update-ServerIni([string]$path, [bool]$isLegacy) {
    $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $path)
    $foundMods = $false
    $foundWorkshop = $false

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^Mods=(.*)$') {
            $mods = Get-Tokens $Matches[1]
            if ($isLegacy) {
                $mods = @($mods | Where-Object { $_ -ne 'GunsOfMarz' })
                $mods = Ensure-Token $mods 'MarzGuns'
            }
            $mods = Ensure-Token $mods 'SimpleSuppressors'
            $lines[$index] = 'Mods=' + (Set-Tokens $mods)
            $foundMods = $true
        }
        elseif ($line -match '^WorkshopItems=(.*)$') {
            $workshop = Ensure-Token (Get-Tokens $Matches[1]) '3782565181'
            $lines[$index] = 'WorkshopItems=' + (Set-Tokens $workshop)
            $foundWorkshop = $true
        }
        elseif ($isLegacy -and $line -match '^DefaultPort=') { $lines[$index] = 'DefaultPort=16263' }
        elseif ($isLegacy -and $line -match '^UDPPort=') { $lines[$index] = 'UDPPort=16264' }
        elseif ($isLegacy -and $line -match '^PublicName=') { $lines[$index] = 'PublicName=B42204 GoM Old Compatibility' }
    }

    if (-not $foundMods -or -not $foundWorkshop) { throw "Invalid server configuration: $path" }
    Set-Content -LiteralPath $path -Value $lines -Encoding utf8
}

foreach ($path in @($serverRoot, (Split-Path -Parent $presetPath), $DedicatedRoot, $DesktopPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required path is missing: $path" }
}

$currentIni = Join-Path $serverRoot "$currentName.ini"
if (-not (Test-Path -LiteralPath $currentIni)) { throw "Missing base server preset: $currentIni" }
Copy-Item -LiteralPath $currentIni -Destination "$currentIni.before-simple-suppressors-$stamp.bak"
Copy-Item -LiteralPath $presetPath -Destination "$presetPath.before-simple-suppressors-gom-old-$stamp.bak"

# Current GoM server: retain GunsOfMarz and add Simple Suppressors to both
# the dedicated-server list and the Mod Manager preset.
Update-ServerIni -path $currentIni -isLegacy $false

# Old GoM server: clone settings, map settings and sandbox settings, but do
# not copy Saves\Multiplayer\b42204.  The -servername creates an isolated save.
foreach ($suffix in @('.ini', '_SandboxVars.lua', '_spawnpoints.lua', '_spawnregions.lua')) {
    Copy-Item -LiteralPath (Join-Path $serverRoot "$currentName$suffix") -Destination (Join-Path $serverRoot "$legacyName$suffix") -Force
}
Update-ServerIni -path (Join-Path $serverRoot "$legacyName.ini") -isLegacy $true

$presetLines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $presetPath)
$currentIndex = -1
for ($index = 0; $index -lt $presetLines.Count; $index++) {
    if ($presetLines[$index] -match '^b42204:') { $currentIndex = $index; break }
}
if ($currentIndex -lt 0) { throw 'The b42204 Mod Manager preset was not found.' }

$currentMods = Ensure-Token (Get-Tokens $presetLines[$currentIndex].Substring('b42204:'.Length)) 'SimpleSuppressors'
$presetLines[$currentIndex] = 'b42204:' + (Set-Tokens $currentMods)
$legacyMods = @($currentMods | Where-Object { $_ -ne 'GunsOfMarz' })
$legacyMods = Ensure-Token $legacyMods 'MarzGuns'
$legacyRecord = "${legacyName}:$($legacyMods -join ';')"
$legacyIndex = -1
for ($index = 0; $index -lt $presetLines.Count; $index++) {
    if ($presetLines[$index] -match '^b42204-gom-old:') { $legacyIndex = $index; break }
}
if ($legacyIndex -ge 0) { $presetLines[$legacyIndex] = $legacyRecord } else { $presetLines.Add($legacyRecord) }
Set-Content -LiteralPath $presetPath -Value $presetLines -Encoding utf8

$launcher = Join-Path $DedicatedRoot 'StartServer64b42204-gom-old.bat'
@'
@setlocal enableextensions
@cd /d "%~dp0"
SET PZ_CLASSPATH=java/;java/projectzomboid.jar
".\jre64\bin\java.exe" -Djava.awt.headless=true -Dzomboid.steam=1 -Dzomboid.znetlog=1 -XX:+UseZGC -XX:-CreateCoredumpOnCrash -XX:-OmitStackTraceInFastThrow -Xms16g -Xmx16g -Djava.library.path=natives/ -cp %PZ_CLASSPATH% zombie.network.GameServer -statistic 0 %1 %2 -servername b42204-gom-old
PAUSE
'@ | Set-Content -LiteralPath $launcher -Encoding ascii

$shortcutPath = Join-Path $DesktopPath 'StartServer64b42204-gom-old.bat - 바로 가기.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcher
$shortcut.WorkingDirectory = $DedicatedRoot
$shortcut.IconLocation = "$launcher,0"
$shortcut.Description = 'Project Zomboid Dedicated Server - B42204 GoM Old Compatibility'
$shortcut.Save()

Write-Output "Configured ${currentName}: GunsOfMarz + GoMAttachmentWorkbench + ImprovisedSilencers + SimpleSuppressors."
Write-Output "Configured ${legacyName}: MarzGuns + GoMAttachmentWorkbench + ImprovisedSilencers + SimpleSuppressors."
Write-Output "Legacy server ports: 16263/16264; current b42204 remains 16261/16262."
Write-Output "Created desktop shortcut: $shortcutPath"
