param(
    [Parameter(Mandatory=$true)][string]$GeometryPath,
    [Parameter(Mandatory=$true)][string]$TexturePath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$layout = Get-Content -LiteralPath $GeometryPath -Raw | ConvertFrom-Json
$scale = 2
$bitmap = [Drawing.Bitmap]::new([int]($layout.width*$scale), [int](($layout.height+30)*$scale))
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.ScaleTransform($scale,$scale)
$graphics.Clear([Drawing.Color]::FromArgb(14,17,20))
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$font = [Drawing.Font]::new('Malgun Gothic',10,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$orange = [Drawing.Pen]::new([Drawing.Color]::FromArgb(239,151,64),1)
$brush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(235,235,235))
$muted = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(151,160,169))
$labels = @{Scope='조준경'; Stock='개머리판'; Canon='총구 부착물'; Laser='레이저'; LaserRifle='레이저'; Light='전술 조명'; LightRifle='전술 조명'; Grip='손잡이'; Foregrip='손잡이'; Bipod='양각대'; RailUp='상단 레일'; Mount='마운트'; Sling='멜빵'; Handguard='핸드가드'}
$labels.Handguard='총열덮개';$labels.Barrel_Shroud='총열 슈라우드';$labels.Misc='기타 부품';$labels.Clip='탄창';$labels.L_Scope='측면 조준경'
try {
    $graphics.DrawString('SOURCE LAYOUT PREVIEW - NOT AN IN-GAME SCREENSHOT',$font,$muted,8,8)
    $graphics.TranslateTransform(0,30)
    $gun=$layout.gun
    $texture=[Drawing.Image]::FromFile($TexturePath)
    try {
        $state=$graphics.Save()
        $graphics.SetClip([Drawing.RectangleF]::new($gun.x,$gun.y,$gun.width,$gun.height))
        if($layout.textureQuad){
            $quad=$layout.textureQuad
            $corners=[Drawing.PointF[]]@([Drawing.PointF]::new($quad[0].x,$quad[0].y),[Drawing.PointF]::new($quad[1].x,$quad[1].y),[Drawing.PointF]::new($quad[3].x,$quad[3].y))
            $graphics.DrawImage($texture,$corners)
        } else {
            $side=[single]([Math]::Min($gun.width,$gun.height))
            $graphics.DrawImage($texture,[single]($gun.x+($gun.width-$side)/2),[single]$gun.y,$side,$side)
        }
        $graphics.Restore($state)
    } finally { $texture.Dispose() }
    foreach($node in $layout.nodes){
        $points=@($node.points | ForEach-Object { @{x=$_[0];y=$_[1]} })
        if(-not $node.points){
            $cx=$node.x+$node.width/2
            $startY=if($node.top){$node.y+$node.height}else{$node.y}
            $points=@(@{x=$cx;y=$startY},@{x=$cx;y=$node.elbowY},@{x=$node.anchorX;y=$node.elbowY},@{x=$node.anchorX;y=$node.anchorY})
        }
        for($i=1;$i -lt $points.Count;$i++){
            $graphics.DrawLine($orange,[single]$points[$i-1].x,[single]$points[$i-1].y,[single]$points[$i].x,[single]$points[$i].y)
        }
        $graphics.FillRectangle([Drawing.Brushes]::Black,[single]$node.x,[single]$node.y,[single]$node.width,[single]$node.height)
        $graphics.DrawRectangle($orange,[single]$node.x,[single]$node.y,[single]$node.width,[single]$node.height)
        $label=if($labels.ContainsKey($node.slot)){$labels[$node.slot]}else{$node.slot}
        $graphics.DrawString($label,$font,$brush,[single]($node.x+5),[single]($node.y+4))
        if($node.height -ge 34){$graphics.DrawString('비어 있음',$font,$muted,[single]($node.x+5),[single]($node.y+20))}
    }
    $bitmap.Save($OutputPath,[Drawing.Imaging.ImageFormat]::Png)
} finally {
    $font.Dispose();$orange.Dispose();$brush.Dispose();$muted.Dispose();$graphics.Dispose();$bitmap.Dispose()
}
