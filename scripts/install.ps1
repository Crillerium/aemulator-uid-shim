[CmdletBinding()]
param(
    [string]$Serial = "",
    [string]$Adb = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$suFile = Join-Path $repoRoot "src\su"
$jarFile = Join-Path $repoRoot "dist\aemu-su.jar"

function Resolve-Adb {
    param([string]$Requested)

    $candidates = @(
        $Requested,
        $env:ADB,
        (Get-Command adb.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source),
        (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe")
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "adb not found. Pass -Adb, set ADB, or add adb to PATH."
}

function Get-OnlineDevices {
    param([string]$AdbPath)

    $devices = & $AdbPath devices
    foreach ($line in $devices) {
        if ($line -match "^(\S+)\s+device(?:\s|$)") {
            $Matches[1]
        }
    }
}

$adbPath = Resolve-Adb $Adb

if (-not (Test-Path -LiteralPath $suFile)) {
    throw "Missing source file: $suFile"
}
if (-not (Test-Path -LiteralPath $jarFile)) {
    Write-Host "dist\aemu-su.jar not found; building it now."
    & (Join-Path $PSScriptRoot "build.ps1")
}
if (-not (Test-Path -LiteralPath $jarFile)) {
    throw "Missing JAR after build: $jarFile"
}

if (-not $Serial) {
    $online = @(Get-OnlineDevices $adbPath)
    if ($online.Count -ne 1) {
        throw "Expected exactly one online ADB device, found $($online.Count). Pass -Serial <address:port>."
    }
    $Serial = $online[0]
}

$deviceState = (& $adbPath -s $Serial get-state | Out-String).Trim()
if ($deviceState -ne "device") {
    throw "ADB device $Serial is not ready: $deviceState"
}

$state = (& $adbPath -s $Serial shell "if [ -f /system/bin/su ]; then if grep -q 'aemu.su.Main' /system/bin/su; then echo ours; else echo other; fi; else echo absent; fi" | Out-String).Trim()
if ($state -eq "other" -and -not $Force) {
    throw "/system/bin/su exists and is not managed by this project. Re-run with -Force only after backing it up."
}

& $adbPath -s $Serial push $suFile /system/bin/su
if ($LASTEXITCODE -ne 0) {
    throw "Failed to push /system/bin/su."
}
& $adbPath -s $Serial push $jarFile /system/framework/aemu-su.jar
if ($LASTEXITCODE -ne 0) {
    throw "Failed to push /system/framework/aemu-su.jar."
}
& $adbPath -s $Serial shell chmod 755 /system/bin/su
if ($LASTEXITCODE -ne 0) {
    throw "Failed to set permissions on /system/bin/su."
}

$version = (& $adbPath -s $Serial shell su -v | Out-String).Trim()
$identity = (& $adbPath -s $Serial shell su -c id | Out-String).Trim()
if ($identity -notmatch "uid=0\(root\)") {
    throw "Installation completed, but su -c id did not return UID 0: $identity"
}

Write-Host "Installed AEmulator UID Shim on $Serial"
Write-Host "  su -v:    $version"
Write-Host "  su -c id: $identity"
Write-Host "This is an emulated identity, not Magisk or a real kernel root."
