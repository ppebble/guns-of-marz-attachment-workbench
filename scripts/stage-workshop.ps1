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
if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
Copy-Item -LiteralPath $sourceContents -Destination (Join-Path $destination 'Contents') -Recurse
Copy-Item -LiteralPath $sourceMetadata -Destination (Join-Path $destination 'workshop.txt')
Copy-Item -LiteralPath $sourcePreview -Destination (Join-Path $destination 'preview.png')

Write-Output "PASS Workshop staging created: $destination"
Write-Output 'Upload this folder with Project Zomboid Workshop tools; add Guns of Marz as a Steam Required Item after the first upload.'
