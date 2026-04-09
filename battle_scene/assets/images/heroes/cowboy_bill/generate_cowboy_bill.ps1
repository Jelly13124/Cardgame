
# Cowboy Bill Hero Generator — Human-like Robot Cowboy
# All images: 64x64 native, no resizing. Transparent background.
# Output: heroes/cowboy_bill/cowboy_bill_{anim}_{n}.png

param(
    [string]$ApiKey = "af914cb9-7951-4263-aff2-9e490fb9d61d",
    [int]$NFrames = 4
)

$BaseUrl  = "https://api.pixellab.ai/v1"
$OutDir   = "$PSScriptRoot"
$SpriteId = "cowboy_bill"

$Headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type"  = "application/json"
}

# ─── Character Description ────────────────────────────────────────────────────
# Human-shaped robot body with cowboy aesthetic. NOT a human — metallic android.
$StyleSuffix = "wasteland punk style, post-apocalyptic scrap aesthetic, rusted metal and salvaged parts, single color bold black pixel art outlines, cel-shaded flat colors, earth tone palette with ONE neon electric blue accent color, transparent background, side view, full body, pixel art"

$CharDesc = "a rugged wasteland robot cowboy, chassis built from rusted salvaged scrap metal and industrial junk, a wide-brim cowboy hat fashioned from a dented satellite dish, a single large shiny electric-blue glowing cyclopean eye lens in the center of the face, a poncho made of tattered dirty canvas and wire mesh, one arm is a heavy piston-driven hydraulic revolver-cannon, legs are reinforced with rebar and truck suspension springs, visible gears and spark-spitting wires at the joints, weathered and caked in desert grime, $StyleSuffix"

Write-Host "=== Cowboy Bill Robot Cowboy Generator ==="
Write-Host "Output: $OutDir"

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Invoke-PixelLab {
    param([string]$Endpoint, [hashtable]$Body)
    $json = $Body | ConvertTo-Json -Depth 10
    Write-Host "  POST $Endpoint ..."
    try {
        return Invoke-RestMethod -Uri "$BaseUrl$Endpoint" -Method POST -Headers $Headers -Body $json
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)"
        Write-Host "  Body : $($_.ErrorDetails.Message)"
        return $null
    }
}

function Save-Base64Image {
    param([string]$Base64, [string]$Path)
    $bytes = [Convert]::FromBase64String($Base64)
    [IO.File]::WriteAllBytes($Path, $bytes)
    $header = [BitConverter]::ToString($bytes[0..3])
    $ok = if ($header -eq "89-50-4E-47") { "PNG OK" } else { "BAD: $header" }
    Write-Host "  Saved: $(Split-Path $Path -Leaf) ($([math]::Round($bytes.Length/1KB,1)) KB) $ok"
}

function Save-AnimFrames {
    param($Resp, [string]$Prefix, [string]$Dir)
    $frames = $null
    if ($Resp.frames)     { $frames = $Resp.frames }
    elseif ($Resp.images) { $frames = $Resp.images }
    elseif ($Resp.data)   { $frames = $Resp.data }
    if (-not $frames) {
        Write-Host "  WARNING: No frames. Response:"
        Write-Host ($Resp | ConvertTo-Json -Depth 4)
        return 0
    }
    $i = 0
    foreach ($frame in $frames) {
        $b64 = if ($frame.base64) { $frame.base64 } elseif ($frame -is [string]) { $frame } else { $null }
        if ($b64) {
            Save-Base64Image -Base64 $b64 -Path "$Dir\${Prefix}_$i.png"
            $i++
        }
    }
    Write-Host "  $i frames saved."
    return $i
}

# ─── Step 1: Generate 64x64 reference (no resize needed) ─────────────────────
$refPath   = "$OutDir\cowboy_bill_ref.png"
$refBase64 = $null

Write-Host "`n[1/3] Generating 64x64 reference image..."
$refResp = Invoke-PixelLab -Endpoint "/generate-image-pixflux" -Body @{
    description             = $CharDesc
    image_size              = @{ width = 64; height = 64 }
    text_guidance_scale     = 8
    outline                 = "single color black outline"
    shading                 = "basic shading"
    detail                  = "medium detail"
    view                    = "side"
    direction               = "east"
    no_background           = $true
    background_removal_task = "remove_simple_background"
}
if (-not $refResp -or -not $refResp.image) { Write-Host "FAILED: No reference."; exit 1 }
Save-Base64Image -Base64 $refResp.image.base64 -Path $refPath
$refBase64 = $refResp.image.base64   # use directly — no resize step

$refImg = @{ type = "base64"; base64 = $refBase64; format = "png" }

# ─── Step 2: ATTACK animation ────────────────────────────────────────────────
# In-place gunslinger shot — feet planted, NO lunge or forward movement
Write-Host "`n[2/3-a] Generating ATTACK animation ($NFrames frames)..."
$attackResp = Invoke-PixelLab -Endpoint "/animate-with-text" -Body @{
    description     = $CharDesc
    action          = "planted cowboy stance, drawing arm cannon and firing from the hip, muzzle flash and recoil, feet stay rooted, no forward movement"
    image_size      = @{ width = 64; height = 64 }
    view            = "side"; direction = "east"
    n_frames        = $NFrames; start_frame_index = 0
    reference_image = $refImg
    no_background   = $true
}
if ($attackResp) { Save-AnimFrames -Resp $attackResp -Prefix "cowboy_bill_attack" -Dir $OutDir }

# ─── Step 3: BLOCK animation ─────────────────────────────────────────────────
# In-place defensive arm raise — no stepping
Write-Host "`n[2/3-b] Generating BLOCK animation ($NFrames frames)..."
$blockResp = Invoke-PixelLab -Endpoint "/animate-with-text" -Body @{
    description     = $CharDesc
    action          = "raising mechanical forearm to block, energy shield crackling, bracing stance, feet planted firmly, no forward movement"
    image_size      = @{ width = 64; height = 64 }
    view            = "side"; direction = "east"
    n_frames        = $NFrames; start_frame_index = 0
    reference_image = $refImg
    no_background   = $true
}
if ($blockResp) { Save-AnimFrames -Resp $blockResp -Prefix "cowboy_bill_block" -Dir $OutDir }

# ─── Cleanup ──────────────────────────────────────────────────────────────────
Remove-Item $refPath -Force -ErrorAction SilentlyContinue
Write-Host "`nCleaning up intermediates... Done."
Write-Host "`n==========================================`nDone! Frames saved to:`n  $OutDir`n=========================================="
