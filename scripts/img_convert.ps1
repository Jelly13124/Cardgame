param(
    [string]$src,
    [string]$dest
)

Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($src)
$img.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Write-Host "Converted $src to $dest as PNG"
