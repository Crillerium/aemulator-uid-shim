[CmdletBinding()]
param(
    [string]$Serial = "",
    [string]$Adb = ""
)

$ErrorActionPreference = "Stop"

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
if ($state -eq "ours") {
    & $adbPath -s $Serial shell rm -f /system/bin/su
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove /system/bin/su."
    }
} elseif ($state -eq "other") {
    Write-Warning "Leaving /system/bin/su in place because it is not managed by this project."
}

& $adbPath -s $Serial shell rm -f /system/framework/aemu-su.jar
if ($LASTEXITCODE -ne 0) {
    throw "Failed to remove /system/framework/aemu-su.jar."
}

Write-Host "Uninstalled AEmulator UID Shim from $Serial"
