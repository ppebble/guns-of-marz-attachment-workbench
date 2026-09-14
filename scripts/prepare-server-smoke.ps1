param([switch]$Legacy)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$variant = if ($Legacy) { 'legacy' } else { 'current' }
$cache = Join-Path $repo ('evidence/server-smoke-' + $variant + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$workshop = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600'
$gom = if ($Legacy) { 'GunsOfMarzPreviousVersion' } else { 'GunsOfMarz' }
$id = if ($Legacy) { 'MarzGuns' } else { 'GunsOfMarz' }
New-Item -ItemType Directory -Path "$cache/Server", "$cache/mods", "$cache/mods/GMAWServerProbe/42/media/lua/server", "$cache/mods/GMAWServerProbe/common" -Force | Out-Null
$links = @{
    Gunworks = "$workshop/3722064198/mods/Gunworks_gang_framework"
    GoM = "$workshop/3722134990/mods/$gom"
    Improvised = "$workshop/3779164273/mods/Improvised Silencers"
    Simple = "$workshop/3782565181/mods/simple-suppressors"
    GoMAttachmentWorkbench = "$repo/Contents/mods/GoMAttachmentWorkbench"
}
# Use isolated copies: PZ's file index must not resolve outside its local mod root.
# Upstream originals remain untouched and these ignored copies are never staged.
foreach ($name in $links.Keys) { Copy-Item -LiteralPath $links[$name] -Destination "$cache/mods/$name" -Recurse }
@"
name=GMAW isolated server probe
id=GMAWServerProbe
require=GoMAttachmentWorkbench
loadModAfter=GoMAttachmentWorkbench
"@ | Set-Content "$cache/mods/GMAWServerProbe/42/mod.info" -Encoding ascii
Copy-Item "$repo/tests/server-runtime-probe.lua" "$cache/mods/GMAWServerProbe/42/media/lua/server/Probe.lua"
@"
Public=false
Open=false
UPnP=false
PauseEmpty=true
DefaultPort=16491
UDPPort=16492
RCONPort=0
MaxPlayers=1
Map=Muldraugh, KY
Mods=SWMG;$id;ImprovisedSilencers;SimpleSuppressors;GoMAttachmentWorkbench;GMAWServerProbe
WorkshopItems=
"@ | Set-Content "$cache/Server/gmaw-smoke.ini" -Encoding ascii
Write-Output $cache
