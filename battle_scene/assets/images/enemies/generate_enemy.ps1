
# PixelLab Enemy Generator — Generic Template
# All images: 64x64 native, no resizing. Transparent background.
# Usage: powershell -ExecutionPolicy Bypass -File generate_enemy.ps1 -SpriteId "trash_robot" -Description "..." -AttackAction "..."
# Output: enemies/{SpriteId}/{SpriteId}_attack_N.png  (+ idle frames)

param(
    [Parameter(Mandatory)][string]$SpriteId,
    [Parameter(Mandatory)][string]$Description,
    [string]$IdleAction   = "breathing idle, shifting weight, staying in place",
    [string]$AttackAction = "attacking in place, striking forward without advancing, stationary attack motion",
    [string]$ApiKey       = "af914cb9-7951-4263-aff2-9e490fb9d61d",
    [int]$NFrames         = 4
)

$OutDir  = "$PSScriptRoot\$SpriteId"
$BaseUrl = "https://api.pixellab.ai/v1"
$Headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type"  = "application/json"
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
Write-Host "`nGenerating enemy: $SpriteId"
Write-Host "Output folder  : $OutDir"

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
        Write-Host "  WARNING: No frames found."
        Write-Host ($Resp | ConvertTo-Json -Depth 6)
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

# ─── Step 1: Generate 64x64 reference — no resize needed ─────────────────────
$refPath = "$OutDir\${SpriteId}_ref.png"
Write-Host "`n[1/3] Generating 64x64 reference image..."
$refResp = Invoke-PixelLab -Endpoint "/generate-image-pixflux" -Body @{
    description             = $Description
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
if (-not $refResp -or -not $refResp.image) { Write-Host "Failed to generate reference. Exiting."; exit 1 }
Save-Base64Image -Base64 $refResp.image.base64 -Path $refPath
$refBase64 = $refResp.image.base64   # use directly — no resize step

# ─── Step 2: Idle animation ───────────────────────────────────────────────────
Write-Host "`n[2/3] Generating idle animation ($NFrames frames)..."
$idleResp = Invoke-PixelLab -Endpoint "/animate-with-text" -Body @{
    description     = $Description
    action          = $IdleAction
    image_size      = @{ width = 64; height = 64 }
    view            = "side"
    direction       = "east"
    n_frames        = $NFrames
    start_frame_index = 0
    reference_image = @{ type = "base64"; base64 = $refBase64; format = "png" }
    no_background   = $true
}
if ($idleResp) { Save-AnimFrames -Resp $idleResp -Prefix "${SpriteId}_idle" -Dir $OutDir }

# ─── Step 3: Attack animation ─────────────────────────────────────────────────
Write-Host "`n[3/3] Generating attack animation ($NFrames frames)..."
$attackResp = Invoke-PixelLab -Endpoint "/animate-with-text" -Body @{
    description     = $Description
    action          = $AttackAction
    image_size      = @{ width = 64; height = 64 }
    view            = "side"
    direction       = "east"
    n_frames        = $NFrames
    start_frame_index = 0
    reference_image = @{ type = "base64"; base64 = $refBase64; format = "png" }
    no_background   = $true
}
if ($attackResp) { Save-AnimFrames -Resp $attackResp -Prefix "${SpriteId}_attack" -Dir $OutDir }

# ─── Cleanup ──────────────────────────────────────────────────────────────────
Remove-Item $refPath -Force -ErrorAction SilentlyContinue
Write-Host "`nCleaning up intermediates... Done."
Write-Host "`n==========================================`nDone! Frames saved to:`n  $OutDir`n=========================================="
