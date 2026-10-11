param([string]$ServerRoot = (Join-Path $env:USERPROFILE 'Zomboid/Server'))
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$base = Join-Path $ServerRoot 'b42211002.ini'
$target = Join-Path $ServerRoot 'gael-test.ini'
$baseHash = (Get-FileHash -LiteralPath $base).Hash
$source = [IO.File]::ReadAllText($base)
$old = [IO.File]::ReadAllText($target)
function Setting([string]$text,[string]$key) {
    $m=[regex]::Match($text,'(?m)^'+[regex]::Escape($key)+'=([^\r\n]*)')
    if(-not $m.Success){throw "Missing setting $key"}
    return $m.Groups[1].Value
}
$removedMods=@('SWMG','GunsOfMarz','Hx_KR_GoM','OpenAllAmmoBoxes_GoMPatch')
$removedWorkshop=@('3722064198','3722134990','3040632900','3803472926')
$mods=@()
foreach($id in (Setting $source 'Mods').Split(';')) {
    if($id -eq 'GunsOfMarz'){$mods+='GaelGunStore_B42'}
    if($id -and $id -notin $removedMods -and $id -ne 'GaelGunStore_B42'){$mods+=$id}
}
if('GaelGunStore_B42' -notin $mods){throw 'Expected base GoM entry not found'}
$workshop=@((Setting $source 'WorkshopItems').Split(';') | Where-Object {$_ -and $_ -notin $removedWorkshop -and $_ -ne '3616176188'}) + @('3616176188')
$settings=@{Mods=($mods -join ';');WorkshopItems=($workshop -join ';');Map=(Setting $source 'Map')}
$new=$old
foreach($key in $settings.Keys){
    $value=$key+'='+$settings[$key]
    $new=[regex]::Replace($new,'(?m)^'+$key+'=[^\r\n]*',[Text.RegularExpressions.MatchEvaluator]{param($m)$value})
}
$backup=Join-Path $repo ('evidence/backups/gael-profile-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $target -Destination $backup
$regions=Join-Path $ServerRoot 'gael-test_spawnregions.lua'
Copy-Item -LiteralPath $regions -Destination $backup
[IO.File]::WriteAllText($target,$new,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $ServerRoot 'b42211002_spawnregions.lua') -Destination $regions -Force
if((Get-FileHash -LiteralPath $base).Hash -ne $baseHash){throw 'Base profile changed'}
$saved=[IO.File]::ReadAllText($target)
foreach($key in $settings.Keys){if((Setting $saved $key) -ne $settings[$key]){throw "Mismatch $key"}}
$strip='(?m)^(Mods|WorkshopItems|Map)=[^\r\n]*'
if([regex]::Replace($saved,$strip,'') -ne [regex]::Replace($old,$strip,'')){throw 'Unrelated INI settings changed'}
@{base=$base;target=$target;backup=$backup;mods=$mods.Count;workshop=$workshop.Count;removedMods=$removedMods;addedMod='GaelGunStore_B42';baseHash=$baseHash} |
    ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $repo 'evidence/gael-base-profile-update.json')
Write-Output "PASS gael-test: $($mods.Count) mods; $($workshop.Count) Workshop entries; base maps/spawn regions; unrelated settings preserved."
Write-Output 'No saves, running processes, sandbox settings, or installed workbench files changed. Restart required.'
