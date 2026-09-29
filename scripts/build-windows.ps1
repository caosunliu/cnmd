#
# build-windows.ps1 - Windows平台编译CNMD数据库
#
# 用法: .\build-windows.ps1 [选项]
#   -Prefix DIR      安装路径 (默认: C:\cnmd)
#   -Jobs N          并行编译数 (默认: CPU核心数)
#   -Debug           启用调试模式
#   -Clean           清理之前的编译
#   -Help            显示帮助
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

function Show-Help {
    Write-Host @"
==========================================
  CNMD 数据库 Windows 编译脚本
  版本: $Version
  基础版本: PostgreSQL 18
==========================================

用法: .\build-windows.ps1 [选项]

选项:
  -Prefix DIR      安装路径 (默认: C:\cnmd)
  -Jobs N          并行编译数 (默认: CPU核心数)
  -Debug           启用调试模式
  -Clean           清理之前的编译
  -Help            显示此帮助信息

前置要求:
  1. Visual Studio 2019/2022 (含C++桌面开发工作负载)
  2. Meson >= 0.54
  3. Ninja
  4. Strawberry Perl
  5. CMake (用于GmSSL)
  6. OpenSSL 开发库

环境变量:
  Visual Studio: 确保已安装Visual Studio并配置好环境
  Perl: Strawberry Perl需要在PATH中
"@
    exit 0
}

if ($Help) { Show-Help }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$SrcDir = Join-Path $ProjectRoot "src\postgresql-18"
$BuildDir = Join-Path $ProjectRoot "build\windows"
$GmSSLDir = Join-Path $ProjectRoot "src\gmssl"

Write-Host "=========================================="
Write-Host "  CNMD 数据库 Windows 编译脚本"
Write-Host "  版本: $Version"
Write-Host "  基础版本: PostgreSQL 18"
Write-Host "=========================================="
Write-Host ""
Write-Host "编译配置:"
Write-Host "  安装路径: $Prefix"
Write-Host "  并行编译: $Jobs 线程"
Write-Host "  调试模式: $Debug"
Write-Host "  构建目录: $BuildDir"
Write-Host ""

# 检查必要工具
function Test-Command {
    param([string]$Cmd)
    $null -ne (Get-Command $Cmd -ErrorAction SilentlyContinue)
}

Write-Host "[检查] 验证编译环境..."

# 检查 Meson
if (-not (Test-Command "meson")) {
    Write-Error "未找到 meson。请安装: pip install meson"
    exit 1
}

# 检查 Ninja
if (-not (Test-Command "ninja")) {
    Write-Error "未找到 ninja。请安装: pip install ninja"
    exit 1
}

# 检查 CMake
if (-not (Test-Command "cmake")) {
    Write-Error "未找到 cmake。请安装 CMake"
    exit 1
}

# 检查 Perl
if (-not (Test-Command "perl")) {
    Write-Error "未找到 perl。请安装 Strawberry Perl"
    exit 1
}

Write-Host "[通过] 编译工具检查完成"

# 清理
if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "[信息] 清理之前的编译..."
    Remove-Item -Recurse -Force $BuildDir
}

# 创建构建目录
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

# ===== 编译 GmSSL =====
Write-Host ""
Write-Host "[步骤 1/4] 编译 GmSSL 国密算法库..."

$GmSSLBuildDir = Join-Path $BuildDir "gmssl-build"

if (-not (Test-Path $GmSSLDir)) {
    Write-Host "[信息] GmSSL源码不存在，开始获取..."
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
    if ($LASTEXITCODE -ne 0) { throw "CMake 配置 GmSSL 失败" }

    & cmake --build . --config Release --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw "编译 GmSSL 失败" }

    & cmake --install . --config Release
    if ($LASTEXITCODE -ne 0) { throw "安装 GmSSL 失败" }
}
finally {
    Pop-Location
}

Write-Host "[完成] GmSSL 编译成功"

# ===== 应用CNMD补丁 =====
Write-Host ""
Write-Host "[步骤 2/4] 应用CNMD补丁..."

$PatchesDir = Join-Path $ProjectRoot "patches"
Push-Location $SrcDir
try {
    $patches = Get-ChildItem -Path $PatchesDir -Filter "*.patch" | Sort-Object Name
    foreach ($patch in $patches) {
        Write-Host "  应用补丁: $($patch.Name)"
        & git apply --check $patch.FullName 2>$null
        if ($LASTEXITCODE -eq 0) {
            & git apply $patch.FullName
        } else {
            Write-Host "  [跳过] 补丁可能已应用"
        }
    }
}
finally {
    Pop-Location
}

# ===== 编译 PostgreSQL (CNMD) =====
Write-Host ""
Write-Host "[步骤 3/4] 编译 CNMD 数据库..."

$PgBuildDir = Join-Path $BuildDir "postgresql-build"
if (-not (Test-Path $PgBuildDir)) {
    New-Item -ItemType Directory -Path $PgBuildDir -Force | Out-Null
}

# PostgreSQL Meson 构建选项
$MesonOptions = @(
    "prefix=$Prefix",
    "ssl=openssl",
    "ldap=disabled",
    "icu=disabled",
    "zlib=system",
    "readline=disabled",
    "libxml=disabled",
    "libxslt=disabled",
    "uuid=ossp",
    "plpython=disabled",
    "plperl=disabled",
    "contrib_extra_modules=cnmd_security"
)

# 设置 OpenSSL 路径 (vcpkg 或系统)
if ($env:OPENSSL_ROOT_DIR) {
    $MesonOptions += "extra_include_dirs=$($env:OPENSSL_ROOT_DIR)/include"
    $MesonOptions += "extra_lib_dirs=$($env:OPENSSL_ROOT_DIR)/lib"
}

# 添加 GmSSL 路径
$MesonOptions += "extra_include_dirs=$GmSSLInstallDir/include"
$MesonOptions += "extra_lib_dirs=$GmSSLInstallDir/lib"

Push-Location $SrcDir
try {
    Write-Host "  配置 Meson 构建..."
    $mesonSetup = @("setup", $PgBuildDir, "-Dprefix=$Prefix")
    
    foreach ($opt in $MesonOptions) {
        $key, $value = $opt -split '=', 2
        if ($value) {
            $mesonSetup += "-D$key=$value"
        }
    }

    & meson @mesonSetup
    if ($LASTEXITCODE -ne 0) { throw "Meson 配置失败" }

    Write-Host "  编译 (使用 $Jobs 个线程)..."
    & meson compile -C $PgBuildDir -j $Jobs
    if ($LASTEXITCODE -ne 0) { throw "编译失败" }
}
finally {
    Pop-Location
}

# ===== 安装 =====
Write-Host ""
Write-Host "[步骤 4/4] 安装 CNMD..."

Push-Location $SrcDir
try {
    & meson install -C $PgBuildDir --no-rebuild
    if ($LASTEXITCODE -ne 0) { throw "安装失败" }
}
finally {
    Pop-Location
}

# 复制 GmSSL DLL 到安装目录的 bin 目录
$GmSSLDlls = Get-ChildItem -Path (Join-Path $GmSSLInstallDir "bin") -Filter "*.dll" -ErrorAction SilentlyContinue
$PgBinDir = Join-Path $Prefix "bin"
foreach ($dll in $GmSSLDlls) {
    Copy-Item $dll.FullName -Destination $PgBinDir -Force
    Write-Host "  复制 $($dll.Name) -> $PgBinDir"
}

# 复制配置文件
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
Write-Host "  CNMD Windows 编译完成!"
Write-Host "  安装路径: $Prefix"
Write-Host "=========================================="
Write-Host ""
Write-Host "下一步操作:"
Write-Host "  1. 初始化数据库: $Prefix\bin\cnmd-initdb.exe -D $Prefix\data"
Write-Host "  2. 注册服务: $Prefix\bin\cnmd-register.exe -D $Prefix\data"
Write-Host "  3. 启动服务: net start cnmd"
Write-Host ""
