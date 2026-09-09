$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'assets\poster-source.png'
$poster = Join-Path $repo 'Contents\mods\GoMAttachmentWorkbench\common\poster.png'
$preview = Join-Path $repo 'workshop\preview.png'
if (-not (Test-Path -LiteralPath $source)) { throw "Missing source artwork: $source" }

function Resize-Png([string]$Destination, [int]$Size) {
    $input = [Drawing.Image]::FromFile($source)
    try {
        $bitmap = [Drawing.Bitmap]::new($Size, $Size)
        try {
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([Drawing.Color]::Transparent)
                $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.DrawImage($input, 0, 0, $Size, $Size)
                New-Item -ItemType Directory -Force (Split-Path -Parent $Destination) | Out-Null
                $bitmap.Save($Destination, [Drawing.Imaging.ImageFormat]::Png)
            } finally { $graphics.Dispose() }
        } finally { $bitmap.Dispose() }
    } finally { $input.Dispose() }
}

Resize-Png $poster 512
Resize-Png $preview 256
Write-Output "PASS generated poster and preview from $source"
