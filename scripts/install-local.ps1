param([string]$ModsPath = (Join-Path $env:USERPROFILE 'Zomboid/mods'))
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'Contents/mods/GoMAttachmentWorkbench'
$root = [IO.Path]::GetFullPath($ModsPath)
$target = [IO.Path]::GetFullPath((Join-Path $root 'GoMAttachmentWorkbench'))
if (-not $target.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escaped mods directory' }
if ($root -match '(?i)steamapps[\\/]workshop') { throw 'Workshop folders are never installation targets' }
if (Test-Path -LiteralPath $target) {
    $backupRoot = Join-Path $repo 'evidence/backups'
    New-Item -ItemType Directory -Force $backupRoot | Out-Null
    Copy-Item -LiteralPath $target -Destination (Join-Path $backupRoot ('GoMAttachmentWorkbench-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))) -Recurse
    # The exact resolved target was bounded above. Backup first; do not retain stale Lua.
    Remove-Item -LiteralPath $target -Recurse -Force
}
New-Item -ItemType Directory -Force $root | Out-Null
Copy-Item -LiteralPath $source -Destination $target -Recurse
New-Item -ItemType Directory -Force (Join-Path $target 'common') | Out-Null
$evidence = @()
foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
    $relative = $file.FullName.Substring($source.Length).TrimStart('\','/')
    $installed = Join-Path $target $relative
    $expected = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $actual = (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash
    if ($expected -ne $actual) { throw "Installed hash mismatch: $relative" }
    $evidence += [pscustomobject]@{ path=$relative; sha256=$actual }
}
New-Item -ItemType Directory -Force (Join-Path $repo 'evidence') | Out-Null
[pscustomobject]@{ captured=(Get-Date -Format o); target=$target; files=$evidence } |
    ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $repo 'evidence/local-install.json')
Write-Output "PASS installed $($evidence.Count) matching files: $target"
Write-Output 'No save, mod preset, Workshop package, or running game was changed.'
