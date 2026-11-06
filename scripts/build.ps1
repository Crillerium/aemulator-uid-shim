[CmdletBinding()]
param(
    [string]$AndroidSdk = "",
    [string]$OutputPath = "dist"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $repoRoot "src\aemu\su\Main.java"

function Resolve-AndroidSdk {
    param([string]$Requested)

    $candidates = @(
        $Requested,
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk"),
        (Join-Path $env:USERPROFILE "AppData\Local\Android\Sdk")
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        if ((Test-Path -LiteralPath (Join-Path $candidate "platforms")) -and
            (Test-Path -LiteralPath (Join-Path $candidate "build-tools"))) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Android SDK not found. Pass -AndroidSdk, or set ANDROID_SDK_ROOT / ANDROID_HOME."
}

function Resolve-AndroidJar {
    param([string]$Sdk)

    $platforms = Get-ChildItem -LiteralPath (Join-Path $Sdk "platforms") -Directory |
        ForEach-Object {
            if ($_.Name -match "^android-(\d+)$") {
                [pscustomobject]@{
                    Api = [int]$Matches[1]
                    Jar = Join-Path $_.FullName "android.jar"
                }
            }
        } |
        Where-Object { Test-Path -LiteralPath $_.Jar } |
        Sort-Object Api -Descending

    if (-not $platforms) {
        throw "No Android platform containing android.jar was found under $Sdk\platforms."
    }
    return $platforms[0].Jar
}

function Resolve-D8 {
    param([string]$Sdk)

    $buildTools = Get-ChildItem -LiteralPath (Join-Path $Sdk "build-tools") -Directory |
        Sort-Object Name -Descending

    foreach ($toolDir in $buildTools) {
        $d8 = Join-Path $toolDir.FullName "d8.bat"
        if (Test-Path -LiteralPath $d8) {
            return $d8
        }
    }

    throw "d8.bat was not found under $Sdk\build-tools."
}

$sdk = Resolve-AndroidSdk $AndroidSdk
$androidJar = Resolve-AndroidJar $sdk
$d8 = Resolve-D8 $sdk
$javac = (Get-Command javac.exe -ErrorAction Stop).Source
$jarTool = (Get-Command jar.exe -ErrorAction Stop).Source

$buildDir = Join-Path $repoRoot "build"
$classesDir = Join-Path $buildDir "classes"
$dexDir = Join-Path $buildDir "dex"
$outputDir = if ([IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path $repoRoot $OutputPath
}
$jarPath = Join-Path $outputDir "aemu-su.jar"

if (Test-Path -LiteralPath $buildDir) {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
}
New-Item -ItemType Directory -Path $classesDir -Force | Out-Null
New-Item -ItemType Directory -Path $dexDir -Force | Out-Null
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

& $javac -encoding UTF-8 -source 8 -target 8 -classpath $androidJar -d $classesDir $sourceFile
if ($LASTEXITCODE -ne 0) {
    throw "javac failed with exit code $LASTEXITCODE."
}

$classFile = Join-Path $classesDir "aemu\su\Main.class"
& $d8 --min-api 21 --lib $androidJar --output $dexDir $classFile
if ($LASTEXITCODE -ne 0) {
    throw "d8 failed with exit code $LASTEXITCODE."
}

& $jarTool --create --file $jarPath -C $dexDir classes.dex
if ($LASTEXITCODE -ne 0) {
    throw "jar failed with exit code $LASTEXITCODE."
}

Write-Host "Built $jarPath"
Write-Host "Android SDK: $sdk"
