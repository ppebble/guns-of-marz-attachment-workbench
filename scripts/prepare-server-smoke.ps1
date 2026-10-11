param([switch]$Legacy, [ValidateSet('Current','Legacy','Gael','Emre')][string]$Provider = 'Current')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$variant = if ($Legacy) { 'Legacy' } else { $Provider }
$cache = Join-Path $repo ('evidence/server-smoke-' + $variant + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$workshop = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600'
$gom = if ($variant -eq 'Legacy') { 'GunsOfMarzPreviousVersion' } else { 'GunsOfMarz' }
$id = if ($variant -eq 'Legacy') { 'MarzGuns' } else { 'GunsOfMarz' }
New-Item -ItemType Directory -Path "$cache/Server", "$cache/mods", "$cache/mods/GMAWServerProbe/42/media/lua/server", "$cache/mods/GMAWServerProbe/common" -Force | Out-Null
$links = @{
    Gunworks = "$workshop/3722064198/mods/Gunworks_gang_framework"
    GoM = "$workshop/3722134990/mods/$gom"
    Improvised = "$workshop/3779164273/mods/Improvised Silencers"
    Simple = "$workshop/3782565181/mods/simple-suppressors"
    GoMAttachmentWorkbench = "$repo/Contents/mods/GoMAttachmentWorkbench"
}
$mods = "SWMG;$id;ImprovisedSilencers;SimpleSuppressors;GoMAttachmentWorkbench;GMAWServerProbe"
if ($variant -eq 'Gael') {
    $links = @{ Gael = "$workshop/3616176188/mods/GaelGunStore"; GoMAttachmentWorkbench = "$repo/Contents/mods/GoMAttachmentWorkbench" }
    $mods = 'GaelGunStore_B42;GoMAttachmentWorkbench;GMAWServerProbe'
} elseif ($variant -eq 'Emre') {
    $links.Remove('Improvised'); $links.Remove('Simple')
    $links.Emre = "$workshop/3799972370/mods/EmreFirearmsPack"
    $links.EmreBridge = "$workshop/3805214250/mods/EmreFPGoMCompat"
    $mods = 'SWMG;GunsOfMarz;EmreFirearmsPack_B42;EmreFPGoMCompat;GoMAttachmentWorkbench;GMAWServerProbe'
}
# Use isolated copies: PZ's file index must not resolve outside its local mod root.
# Upstream originals remain untouched and these ignored copies are never staged.
foreach ($name in $links.Keys) { Copy-Item -LiteralPath $links[$name] -Destination "$cache/mods/$name" -Recurse }
# Record the exact workbench snapshot exercised by this server instance.
Get-ChildItem -LiteralPath "$cache/mods/GoMAttachmentWorkbench" -Recurse -File | ForEach-Object {
    [pscustomobject]@{ Path = $_.FullName.Substring($cache.Length + 1); SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
} | ConvertTo-Json | Set-Content -LiteralPath "$cache/workbench-source-hashes.json" -Encoding utf8
@"
name=GMAW isolated server probe
id=GMAWServerProbe
require=GoMAttachmentWorkbench
loadModAfter=GoMAttachmentWorkbench
"@ | Set-Content "$cache/mods/GMAWServerProbe/42/mod.info" -Encoding ascii
$probe = if ($variant -in @('Gael','Emre')) { 'provider-server-runtime-probe.lua' } else { 'server-runtime-probe.lua' }
$probeText = "GMAWSmokeProvider = '$variant'`n" + (Get-Content -LiteralPath "$repo/tests/$probe" -Raw)
[IO.File]::WriteAllText("$cache/mods/GMAWServerProbe/42/media/lua/server/Probe.lua", $probeText, [Text.UTF8Encoding]::new($false))
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
Mods=$mods
WorkshopItems=
"@ | Set-Content "$cache/Server/gmaw-smoke.ini" -Encoding ascii
Write-Output $cache
