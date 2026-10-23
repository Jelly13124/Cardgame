# One-command test runner: isolated user data, import, smoke boot, scene tests,
# expected-failure bookkeeping and the layering check.
#
# Usage (Windows PowerShell 5.1 or pwsh):
#   $env:GODOT_BIN = "C:\path\to\Godot_v4.6.3-stable_win64_console.exe"
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Only "save_io*"
#
# Exit codes: 0 = all passed (expected failures allowed), 1 = a test failed or an
# expected failure unexpectedly passed (XPASS), 2 = environment problem.
param(
    [string]$Only = "*",
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ErrorPatterns = @(
    'SCRIPT ERROR',
    'Failed to load script',
    'Compile Error',
    'Parse Error',
    'DataValidator: \d+ JSON schema failure'
)

function Resolve-Godot {
    if ($env:GODOT_BIN) {
        if (Test-Path -LiteralPath $env:GODOT_BIN) { return $env:GODOT_BIN }
        Write-Host "GODOT_BIN points to a missing file: $($env:GODOT_BIN)" -ForegroundColor Red
        return $null
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    Write-Host "Godot not found. Set GODOT_BIN to the Godot 4.6 console executable." -ForegroundColor Red
    return $null
}

# Runs Godot with the given arguments; returns @{ ExitCode; Log; TimedOut }.
function Invoke-Godot([string[]]$GodotArgs, [string]$LogPath, [int]$Timeout) {
    $quoted = $GodotArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    $errPath = "$LogPath.err"
    $proc = Start-Process -FilePath $script:Godot -ArgumentList ($quoted -join ' ') `
        -NoNewWindow -PassThru -RedirectStandardOutput $LogPath -RedirectStandardError $errPath
    $null = $proc.Handle  # keep the handle so ExitCode is available after exit
    $timedOut = -not $proc.WaitForExit($Timeout * 1000)
    if ($timedOut) {
        # The *_console.exe wrapper starts the real Godot as a child process:
        # kill the whole tree, otherwise the child keeps the log files open.
        & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
        $proc.WaitForExit(10000) | Out-Null
    }
    $text = (Read-Shared $LogPath) + "`n" + (Read-Shared $errPath)
    [IO.File]::WriteAllText($LogPath, $text)
    Remove-Item -LiteralPath $errPath -ErrorAction SilentlyContinue
    $code = if ($timedOut) { -1 } else { $proc.ExitCode }
    return @{ ExitCode = $code; Log = $text; TimedOut = $timedOut }
}

# Reads a file even if another process still has it open for writing.
function Read-Shared([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    for ($i = 0; $i -lt 20; $i++) {
        try {
            $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite, Delete')
            try { return (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
        } catch [IO.IOException] {
            Start-Sleep -Milliseconds 250
        }
    }
    return "<log unreadable: $Path>"
}

function Test-LogHasErrors([string]$Text) {
    foreach ($pattern in $ErrorPatterns) {
        if ($Text -match $pattern) { return $true }
    }
    return $false
}

function Read-ExpectedFailures {
    $result = @{}
    $path = Join-Path $ProjectRoot "tests/expected_failures.txt"
    if (-not (Test-Path -LiteralPath $path)) { return $result }
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $name = ($trimmed -split '\s+', 2)[0]
        $result[$name] = $trimmed
    }
    return $result
}

$script:Godot = Resolve-Godot
if (-not $script:Godot) { exit 2 }

$runDir = Join-Path ([IO.Path]::GetTempPath()) ("cardgame-tests-" + [Guid]::NewGuid().ToString("N"))
$userDir = Join-Path $runDir "userdata"
$logDir = Join-Path $runDir "logs"
New-Item -ItemType Directory -Force -Path $userDir, $logDir | Out-Null
$savedAppData = $env:APPDATA
$savedXdg = $env:XDG_DATA_HOME
$env:APPDATA = $userDir
$env:XDG_DATA_HOME = $userDir

$exitCode = 0
try {
    Write-Host "Godot:    $($script:Godot)"
    Write-Host "Project:  $ProjectRoot"
    Write-Host "UserData: $userDir (isolated)"

    # 1. Import when the project has no import cache. The first full import of a
    #    fresh checkout can crash intermittently inside Godot; retry it.
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".godot"))) {
        $imported = $false
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $r = Invoke-Godot @("--headless", "--path", $ProjectRoot, "--import") (Join-Path $logDir "import_$attempt.log") 1200
            if ($r.ExitCode -eq 0 -and $r.Log -notmatch 'FATAL') {
                $imported = $true
                if ($attempt -gt 1) { Write-Host "import: retried $($attempt - 1)" -ForegroundColor Yellow }
                break
            }
        }
        if (-not $imported) {
            Write-Host "import: failed 3 times, see $logDir" -ForegroundColor Red
            $exitCode = 2
            exit 2
        }
        Write-Host "import: ok"
    }

    $fullRun = ($Only -eq "*")

    # 2. Smoke boot (full runs only).
    if ($fullRun) {
        $smoke = Invoke-Godot @("--headless", "--path", $ProjectRoot, "--quit-after", "5") (Join-Path $logDir "smoke.log") 120
        if ($smoke.ExitCode -ne 0 -or (Test-LogHasErrors $smoke.Log)) {
            Write-Host "smoke: FAIL (log: $logDir\smoke.log)" -ForegroundColor Red
            $exitCode = 1
        } else {
            Write-Host "smoke: ok"
        }
    }

    # 3. Scene tests.
    $expected = Read-ExpectedFailures
    $tests = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "tests") -Filter "*_test.tscn" |
        Where-Object { $_.BaseName -like $Only -and $_.BaseName -notlike "*visual_capture*" } |
        Sort-Object Name
    if (-not $tests) {
        Write-Host "No tests match '$Only'." -ForegroundColor Red
        $exitCode = 2
        exit 2
    }
    $counts = @{ PASS = 0; FAIL = 0; XFAIL = 0; XPASS = 0 }
    $rows = @()
    foreach ($t in $tests) {
        $name = $t.BaseName
        $log = Join-Path $logDir "$name.log"
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-Godot @("--headless", "--path", $ProjectRoot, "res://tests/$($t.Name)") $log $TimeoutSeconds
        $watch.Stop()
        $passed = ($r.ExitCode -eq 0) -and -not (Test-LogHasErrors $r.Log)
        $isExpected = $expected.ContainsKey($name)
        $status = if ($passed -and $isExpected) { "XPASS" } elseif ($passed) { "PASS" } elseif ($isExpected) { "XFAIL" } else { "FAIL" }
        if ($r.TimedOut) { $status = if ($isExpected) { "XFAIL" } else { "FAIL" } }
        $counts[$status]++
        $rows += [pscustomobject]@{ Test = $name; Result = $status; Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1) }
        if ($status -eq "FAIL" -or $status -eq "XPASS") {
            $exitCode = 1
            Write-Host "---- $name ($status) last lines ----" -ForegroundColor Red
            ($r.Log -split "`n" | Select-Object -Last 30) | ForEach-Object { Write-Host "  $_" }
        }
        if ($status -eq "XFAIL") {
            ($r.Log -split "`n" | Where-Object { $_ -match '^MISMATCH' } | Select-Object -First 20) |
                ForEach-Object { Write-Host "  [$name] $_" -ForegroundColor DarkYellow }
        }
    }
    $rows | Format-Table -AutoSize | Out-String | Write-Host

    # 4. Layering check (full runs only; exists from Task 7 on).
    if ($fullRun) {
        $checker = Join-Path $ProjectRoot "tools/check_layers.py"
        if (Test-Path -LiteralPath $checker) {
            $out = & python $checker 2>&1
            $out | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
        } else {
            Write-Host "layers: skipped"
        }
    }

    $summary = "passed=$($counts.PASS) failed=$($counts.FAIL) xfail=$($counts.XFAIL) xpass=$($counts.XPASS)"
    $color = if ($exitCode -eq 0) { "Green" } else { "Red" }
    Write-Host $summary -ForegroundColor $color
    if ($counts.XPASS -gt 0) {
        Write-Host "XPASS: remove the fixed tests from tests/expected_failures.txt" -ForegroundColor Red
    }
}
catch {
    Write-Host "runner error: $_" -ForegroundColor Red
    $exitCode = 2
}
finally {
    $env:APPDATA = $savedAppData
    $env:XDG_DATA_HOME = $savedXdg
    if ($exitCode -eq 0) {
        Remove-Item -LiteralPath $runDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "Logs kept at $logDir"
        Remove-Item -LiteralPath $userDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
exit $exitCode
