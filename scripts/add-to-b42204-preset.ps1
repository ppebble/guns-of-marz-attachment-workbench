param(
    [string]$PresetPath = (Join-Path $HOME 'Zomboid\Lua\pz_modlist_settings.cfg'),
    [string]$ServerPath = (Join-Path $HOME 'Zomboid\Server\b42204.ini')
)

$ErrorActionPreference = 'Stop'
$modId = 'GoMAttachmentWorkbench'
$dependency = 'GunsOfMarz'

function Add-AfterDependency([string]$value) {
    $values = @($value -split ';' | Where-Object { $_ -and $_ -ne $modId })
    $index = [Array]::IndexOf([string[]]$values, $dependency)
    if ($index -lt 0) { throw "Required mod $dependency is missing from the target list" }
    $before = @($values[0..$index])
    $after = if ($index + 1 -lt $values.Count) { @($values[($index + 1)..($values.Count - 1)]) } else { @() }
    return (@($before + $modId + $after) -join ';')
}

foreach ($path in @($PresetPath, $ServerPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing target: $path" }
}

$preset = [IO.File]::ReadAllText($PresetPath)
$updatedPreset = [regex]::Replace($preset, '(?m)^b42204:([^\r\n]*)\r?$', {
    param($match)
    'b42204:' + (Add-AfterDependency $match.Groups[1].Value)
}, 1)
if ($updatedPreset -eq $preset -and -not [regex]::IsMatch($preset, '(?m)^b42204:')) { throw 'b42204 preset line was not found' }

$server = [IO.File]::ReadAllText($ServerPath)
$updatedServer = [regex]::Replace($server, '(?m)^Mods=([^\r\n]*)\r?$', {
    param($match)
    'Mods=' + (Add-AfterDependency $match.Groups[1].Value)
}, 1)
if ($updatedServer -eq $server -and -not [regex]::IsMatch($server, '(?m)^Mods=')) { throw 'Server Mods line was not found' }

if ($updatedPreset -eq $preset -and $updatedServer -eq $server) {
    Write-Output "PASS $modId is already directly after $dependency in b42204 client preset and server Mods list"
    exit 0
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
Copy-Item -LiteralPath $PresetPath -Destination "$PresetPath.before-gom-workbench-$stamp.bak"
Copy-Item -LiteralPath $ServerPath -Destination "$ServerPath.before-gom-workbench-$stamp.bak"
[IO.File]::WriteAllText($PresetPath, $updatedPreset, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($ServerPath, $updatedServer, [Text.UTF8Encoding]::new($false))
Write-Output "PASS added $modId after $dependency to b42204 client preset and server Mods list"
Write-Output 'WorkshopItems was intentionally left unchanged: add the newly assigned Workshop ID there only after publishing.'
