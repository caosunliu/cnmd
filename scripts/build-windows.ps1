#
# build-windows.ps1 - Windows build script for CNMD
#

param(
    [string]$Prefix = "C:\cnmd",
    [int]$Jobs = (Get-CimInstance Win32_Processor).NumberOfCores,
    [switch]$Debug,
    [switch]$Clean,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$Version = "1.0.0"

if ($Help) {
    Write-Host "Usage: .\build-windows.ps1 -Prefix C:\cnmd"
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$SrcDir = Join-Path $ProjectRoot "src\postgresql-18"
$BuildDir = Join-Path $ProjectRoot "build\windows"
$GmSSLDir = Join-Path $ProjectRoot "src\gmssl"

Write-Host "=========================================="
Write-Host "  CNMD Windows Build Script"
Write-Host "  Version: $Version"
Write-Host "=========================================="
Write-Host ""
Write-Host "Config:"
Write-Host "  Prefix: $Prefix"
Write-Host "  Jobs: $Jobs"
Write-Host ""

# Check tools
function Test-Command {
    param([string]$Cmd)
    $null -ne (Get-Command $Cmd -ErrorAction SilentlyContinue)
}

Write-Host "[Check] Verifying build tools..."

if (-not (Test-Command "meson")) { throw "meson not found. Install: pip install meson" }
if (-not (Test-Command "ninja")) { throw "ninja not found. Install: pip install ninja" }
if (-not (Test-Command "cmake")) { throw "cmake not found. Install CMake" }
if (-not (Test-Command "perl")) { throw "perl not found. Install Strawberry Perl" }

Write-Host "[OK] Build tools verified"

# Clean
if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "[Info] Cleaning previous build..."
    Remove-Item -Recurse -Force $BuildDir
}

# Create build directory
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

# ===== Build GmSSL =====
Write-Host ""
Write-Host "[Step 1/4] Building GmSSL..."

$GmSSLBuildDir = Join-Path $BuildDir "gmssl-build"

if (-not (Test-Path $GmSSLDir)) {
    Write-Host "[Info] Downloading GmSSL..."
    git clone --branch v3.2.0 --depth 1 https://github.com/guanzhi/GmSSL.git $GmSSLDir
}

if (-not (Test-Path $GmSSLBuildDir)) {
    New-Item -ItemType Directory -Path $GmSSLBuildDir -Force | Out-Null
}

$GmSSLInstallDir = Join-Path $BuildDir "gmssl-install"
if (-not (Test-Path $GmSSLInstallDir)) {
    New-Item -ItemType Directory -Path $GmSSLInstallDir -Force | Out-Null
}

Push-Location $GmSSLBuildDir
try {
    $cmakeArgs = @(
        "-S", $GmSSLDir,
        "-B", $GmSSLBuildDir,
        "-DCMAKE_INSTALL_PREFIX=$GmSSLInstallDir",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_SHARED_LIBS=ON",
        "-DBUILD_TESTING=OFF"
    )
    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { throw "CMake configure GmSSL failed" }

    & cmake --build . --config Release --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw "Build GmSSL failed" }

    & cmake --install . --config Release --prefix $GmSSLInstallDir
    if ($LASTEXITCODE -ne 0) { throw "Install GmSSL failed" }
}
finally {
    Pop-Location
}

Write-Host "[Done] GmSSL built successfully"

# ===== Apply patches =====
Write-Host ""
Write-Host "[Step 2/4] Applying CNMD patches..."

$PatchesDir = Join-Path $ProjectRoot "patches"
Push-Location $SrcDir
try {
    $patches = Get-ChildItem -Path $PatchesDir -Filter "*.patch" | Sort-Object Name
    foreach ($patch in $patches) {
        Write-Host "  Applying: $($patch.Name)"
        try {
            & git apply --check $patch.FullName 2>$null
            if ($LASTEXITCODE -eq 0) {
                & git apply $patch.FullName
                Write-Host "    Applied"
            } else {
                Write-Host "    [Skip] Already applied"
            }
        } catch {
            Write-Host "    [Skip] Patch failed: $_"
        }
    }
}
finally {
    Pop-Location
}

# ===== Build PostgreSQL (CNMD) =====
Write-Host ""
Write-Host "[Step 3/4] Building CNMD..."

$PgBuildDir = Join-Path $BuildDir "postgresql-build"
if (-not (Test-Path $PgBuildDir)) {
    New-Item -ItemType Directory -Path $PgBuildDir -Force | Out-Null
}

# Meson options
$MesonOptions = @(
    "prefix=$Prefix",
    "ssl=openssl",
    "ldap=disabled",
    "icu=disabled",
    "zlib=enabled",
    "readline=disabled",
    "libxml=disabled",
    "libxslt=disabled",
    "uuid=ossp",
    "plpython=disabled",
    "plperl=disabled"
)

# OpenSSL path
if ($env:OPENSSL_ROOT_DIR) {
    $MesonOptions += "extra_include_dirs=$($env:OPENSSL_ROOT_DIR)/include"
    $MesonOptions += "extra_lib_dirs=$($env:OPENSSL_ROOT_DIR)/lib"
}

# GmSSL path
$MesonOptions += "extra_include_dirs=$GmSSLInstallDir/include"
$MesonOptions += "extra_lib_dirs=$GmSSLInstallDir/lib"

Push-Location $SrcDir
try {
    Write-Host "  Configuring Meson..."
    $mesonSetup = @("setup", $PgBuildDir, "-Dprefix=$Prefix")
    
    foreach ($opt in $MesonOptions) {
        $key, $value = $opt -split '=', 2
        if ($value) {
            $mesonSetup += "-D$key=$value"
        }
    }

    & meson @mesonSetup
    if ($LASTEXITCODE -ne 0) { throw "Meson configure failed" }

    Write-Host "  Building (using $Jobs threads)..."
    & meson compile -C $PgBuildDir -j $Jobs
    if ($LASTEXITCODE -ne 0) { throw "Build failed" }
}
finally {
    Pop-Location
}

# ===== Install =====
Write-Host ""
Write-Host "[Step 4/4] Installing CNMD..."

Push-Location $SrcDir
try {
    & meson install -C $PgBuildDir --no-rebuild
    if ($LASTEXITCODE -ne 0) { throw "Install failed" }
}
finally {
    Pop-Location
}

# Copy GmSSL DLLs
$GmSSLDlls = Get-ChildItem -Path (Join-Path $GmSSLInstallDir "bin") -Filter "*.dll" -ErrorAction SilentlyContinue
$PgBinDir = Join-Path $Prefix "bin"
foreach ($dll in $GmSSLDlls) {
    Copy-Item $dll.FullName -Destination $PgBinDir -Force
    Write-Host "  Copied $($dll.Name)"
}

# Copy config files
$ConfigDir = Join-Path $ProjectRoot "config"
if (Test-Path $ConfigDir) {
    $DataDir = Join-Path $Prefix "data"
    if (-not (Test-Path $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    }
    Copy-Item (Join-Path $ConfigDir "postgresql.conf") -Destination $DataDir -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $ConfigDir "pg_hba.conf") -Destination $DataDir -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  Build Complete!"
Write-Host "  Install: $Prefix"
Write-Host "=========================================="
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Init DB: $Prefix\bin\cnmd-initdb.exe -D $Prefix\data"
Write-Host "  2. Start: net start cnmd"
Write-Host ""
