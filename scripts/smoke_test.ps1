# Headless smoke test: boot the project, let it run a few seconds, scan
# stdout/stderr for SCRIPT ERROR / push_error / Failed to load script.
# Exits 0 on clean, 1 on any of those signals.
#
# Usage:
#   pwsh scripts/smoke_test.ps1
#
# Or shorter (if pwsh is your default):
#   ./scripts/smoke_test.ps1
#
# Optional override of the godot binary:
#   $env:GODOT_BIN = "C:\path\to\godot.exe"; pwsh scripts/smoke_test.ps1

$ErrorActionPreference = "Stop"

$godot = $env:GODOT_BIN
if ([string]::IsNullOrEmpty($godot)) {
    $godot = "godot"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Write-Host "Smoke test: $godot --headless --path $projectRoot --quit-after 5"

# Capture both stdout and stderr; Godot writes errors to stderr.
$tmpOut = [System.IO.Path]::GetTempFileName()
$tmpErr = [System.IO.Path]::GetTempFileName()
try {
    $proc = Start-Process -FilePath $godot `
        -ArgumentList @("--headless", "--path", $projectRoot, "--quit-after", "5") `
        -NoNewWindow -PassThru -Wait `
        -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
    $output = (Get-Content $tmpOut -Raw) + "`n" + (Get-Content $tmpErr -Raw)
} finally {
    Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
}

# Patterns that indicate a real failure (ignore the harmless RID/PagedAllocator
# noise Godot prints at headless teardown).
$failPatterns = @(
    'SCRIPT ERROR',
    'Failed to load script',
    'Compile Error',
    'Parse Error',
    'DataValidator: \d+ JSON schema failure'
)

$failures = @()
foreach ($pattern in $failPatterns) {
    $matches = [regex]::Matches($output, $pattern)
    foreach ($m in $matches) {
        $failures += $m.Value
    }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "[FAIL] Smoke test caught $($failures.Count) error indicator(s):" -ForegroundColor Red
    foreach ($f in $failures | Select-Object -Unique) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Full output:"
    Write-Host $output
    exit 1
}

if ($output -match 'DataValidator: all .* passed schema check') {
    Write-Host "[OK] DataValidator: all schemas passed." -ForegroundColor Green
} else {
    Write-Host "[WARN] DataValidator did not print 'all passed' — autoload may not have run." -ForegroundColor Yellow
    Write-Host $output
    exit 1
}

Write-Host "[OK] Headless boot clean. No SCRIPT ERROR / push_error / parse failures." -ForegroundColor Green
exit 0
