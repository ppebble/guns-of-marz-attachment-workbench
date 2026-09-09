param(
    [Parameter(Mandatory=$true)][ValidatePattern('^\d+$')][string]$WorkshopId,
    [string]$MetadataPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'workshop\workshop.txt'),
    [string]$ServerPath = (Join-Path $HOME 'Zomboid\Server\b42204.ini')
)

$ErrorActionPreference = 'Stop'
foreach ($path in @($MetadataPath, $ServerPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing target: $path" }
}
$metadata = [IO.File]::ReadAllText($MetadataPath)
$metadata = [regex]::Replace($metadata, '(?m)^id=\d+\r?\n?', '')
$metadata = [regex]::Replace($metadata, '(?m)^version=1\r?$', "version=1`nid=$WorkshopId", 1)
if (-not [regex]::IsMatch($metadata, "(?m)^id=$WorkshopId$")) { throw 'Could not set Workshop metadata ID' }

$server = [IO.File]::ReadAllText($ServerPath)
$match = [regex]::Match($server, '(?m)^WorkshopItems=([^\r\n]*)\r?$')
if (-not $match.Success) { throw 'WorkshopItems line was not found' }
$items = @($match.Groups[1].Value -split ';' | Where-Object { $_ })
if ($items -notcontains $WorkshopId) { $items += $WorkshopId }
$updatedServer = $server.Substring(0, $match.Index) + 'WorkshopItems=' + ($items -join ';') + $server.Substring($match.Index + $match.Length)

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
Copy-Item -LiteralPath $MetadataPath -Destination "$MetadataPath.before-workshop-id-$stamp.bak"
Copy-Item -LiteralPath $ServerPath -Destination "$ServerPath.before-workshop-id-$stamp.bak"
[IO.File]::WriteAllText($MetadataPath, $metadata, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($ServerPath, $updatedServer, [Text.UTF8Encoding]::new($false))
Write-Output "PASS stored Workshop ID $WorkshopId in metadata and b42204 WorkshopItems"
