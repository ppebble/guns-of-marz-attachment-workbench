param(
    [string]$DestinationRoot = (Join-Path $HOME 'Zomboid\Workshop')
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$sourceContents = Join-Path $repo 'Contents'
$sourceMetadata = Join-Path $repo 'workshop\workshop.txt'
$sourcePreview = Join-Path $repo 'workshop\preview.png'
$destinationRoot = [IO.Path]::GetFullPath($DestinationRoot).TrimEnd([char[]]@('\','/'))
$destination = [IO.Path]::GetFullPath((Join-Path $destinationRoot 'GoMAttachmentWorkbench'))

foreach ($required in @($sourceContents, $sourceMetadata, $sourcePreview)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing Workshop source: $required" }
}
if (-not $destination.StartsWith($destinationRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to stage outside destination root: $destination"
}

New-Item -ItemType Directory -Force $destinationRoot | Out-Null
if (Test-Path -LiteralPath $destination) {
    # Preserve any manual edits to a previous staged Workshop description.
    $backupRoot = Join-Path $repo 'evidence\backups\workshop-stage'
    New-Item -ItemType Directory -Force $backupRoot | Out-Null
    $backup = Join-Path $backupRoot ('GoMAttachmentWorkbench-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    Copy-Item -LiteralPath $destination -Destination $backup -Recurse
    Write-Output "PASS previous staging backed up: $backup"
    Remove-Item -LiteralPath $destination -Recurse -Force
}
New-Item -ItemType Directory -Force $destination | Out-Null
Copy-Item -LiteralPath $sourceContents -Destination (Join-Path $destination 'Contents') -Recurse
Copy-Item -LiteralPath $sourceMetadata -Destination (Join-Path $destination 'workshop.txt')
Copy-Item -LiteralPath $sourcePreview -Destination (Join-Path $destination 'preview.png')

$verified = 0
foreach ($file in Get-ChildItem -LiteralPath $sourceContents -Recurse -File) {
    $relative = $file.FullName.Substring($sourceContents.Length).TrimStart('\','/')
    $copy = Join-Path (Join-Path $destination 'Contents') $relative
    if (-not (Test-Path -LiteralPath $copy)) { throw "Staged mod file missing: $relative" }
    if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash) {
        throw "Staged mod file hash mismatch: $relative"
    }
    $verified++
}
foreach ($name in @('workshop.txt','preview.png')) {
    $source = if ($name -eq 'workshop.txt') { $sourceMetadata } else { $sourcePreview }
    $copy = Join-Path $destination $name
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash) {
        throw "Staged Workshop metadata hash mismatch: $name"
    }
}
Write-Output "PASS Workshop staging created: $destination"
Write-Output "PASS verified $verified mod files and matching workshop.txt / preview.png."
Write-Output 'Update existing Steam Workshop item 3798555914 using Project Zomboid Workshop tools; do not create a new item.'
