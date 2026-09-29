#
# package-windows.ps1 - 构建并打包CNMD Windows安装包
#
# 生成 .exe (NSIS) 和 .msi (WiX) 安装包
#
# 用法: .\package-windows.ps1 [选项]
#   -Prefix DIR      安装路径 (默认: C:\cnmd)
#   -SkipBuild       跳过编译步骤，直接打包
#   -ExeOnly         仅生成 .exe 安装包
#   -MsiOnly         仅生成 .msi 安装包
#   -Help            显示帮助
#

param(
    [string]$Prefix = "C:\cnmd",
    [switch]$SkipBuild,
    [switch]$ExeOnly,
    [switch]$MsiOnly,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$Version = "1.0.0"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

function Show-Help {
    Write-Host @"
==========================================
  CNMD Windows 安装包打包脚本
  版本: $Version
==========================================

用法: .\package-windows.ps1 [选项]

选项:
  -Prefix DIR      安装路径 (默认: C:\cnmd)
  -SkipBuild       跳过编译步骤，直接打包
  -ExeOnly         仅生成 .exe 安装包 (NSIS)
  -MsiOnly         仅生成 .msi 安装包 (WiX)
  -Help            显示此帮助信息

前置要求:
  1. NSIS (用于生成 .exe)
  2. WiX Toolset 3.x 或 4.x (用于生成 .msi)
  3. Visual Studio Build Tools (编译所需)

说明:
  此脚本将:
  1. 编译CNMD数据库 (除非指定 -SkipBuild)
  2. 准备安装文件目录结构
  3. 使用 NSIS 生成 .exe 安装包
  4. 使用 WiX 生成 .msi 安装包
"@
    exit 0
}

if ($Help) { Show-Help }

Write-Host "=========================================="
Write-Host "  CNMD Windows 安装包打包脚本"
Write-Host "  版本: $Version"
Write-Host "=========================================="
Write-Host ""

# ===== 步骤 1: 编译 (可选) =====
if (-not $SkipBuild) {
    Write-Host "[步骤 1/5] 编译 CNMD..."
    & "$ScriptDir\build-windows.ps1" -Prefix $Prefix
    if ($LASTEXITCODE -ne 0) { throw "编译失败" }
} else {
    Write-Host "[步骤 1/5] 跳过编译步骤"
}

# ===== 步骤 2: 准备 staging 目录 =====
Write-Host ""
Write-Host "[步骤 2/5] 准备安装文件..."

$StagingDir = Join-Path $ProjectRoot "installer\windows\staging\cnmd"
$PackageDir = Join-Path $ProjectRoot "build\windows\packages"

if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

# 复制编译产物
$InstallDir = $Prefix
if (Test-Path $InstallDir) {
    Write-Host "  复制安装文件..."
    Copy-Item -Path "$InstallDir\*" -Destination $StagingDir -Recurse -Force
} else {
    throw "安装目录不存在: $InstallDir。请先运行编译步骤。"
}

Write-Host "  staging 目录: $StagingDir"

# ===== 步骤 3: 生成 .exe (NSIS) =====
if (-not $MsiOnly) {
    Write-Host ""
    Write-Host "[步骤 3/5] 生成 .exe 安装包 (NSIS)..."

    $NsisScript = Join-Path $ProjectRoot "installer\windows\cnmd.nsi"
    $NsisExe = $null

    # 查找 NSIS
    $nsisPaths = @(
        "$env:ProgramFiles\NSIS\makensis.exe",
        "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
        "C:\Program Files\NSIS\makensis.exe",
        "C:\Program Files (x86)\NSIS\makensis.exe"
    )
    foreach ($path in $nsisPaths) {
        if (Test-Path $path) {
            $NsisExe = $path
            break
        }
    }

    # 也尝试从 PATH 查找
    if (-not $NsisExe) {
        $NsisExe = (Get-Command makensis.exe -ErrorAction SilentlyContinue)?.Source
    }

    if ($NsisExe) {
        Write-Host "  NSIS 路径: $NsisExe"
        Push-Location (Split-Path $NsisScript)
        try {
            & $NsisExe /DPRODUCT_VERSION=$Version $NsisScript
            if ($LASTEXITCODE -ne 0) { throw "NSIS 打包失败" }
            
            $ExeFile = Join-Path (Split-Path $NsisScript) "cnmd-${Version}-windows-x64.exe"
            if (Test-Path $ExeFile) {
                Copy-Item $ExeFile -Destination $PackageDir -Force
                Write-Host "  [完成] .exe 安装包: $PackageDir\cnmd-${Version}-windows-x64.exe"
            }
        }
        finally {
            Pop-Location
        }
    } else {
        Write-Warning "未找到 NSIS。跳过 .exe 生成。请安装 NSIS: https://nsis.sourceforge.io/"
    }
} else {
    Write-Host ""
    Write-Host "[步骤 3/5] 跳过 .exe 生成"
}

# ===== 步骤 4: 生成 .msi (WiX) =====
if (-not $ExeOnly) {
    Write-Host ""
    Write-Host "[步骤 4/5] 生成 .msi 安装包 (WiX)..."

    $WxsScript = Join-Path $ProjectRoot "installer\windows\cnmd.wxs"
    $WixDir = $null

    # 查找 WiX
    $wixPaths = @(
        "$env:ProgramFiles\WiX Toolset v3.11\bin",
        "$env:ProgramFiles\WiX Toolset v4.0\bin",
        "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin",
        "C:\Program Files\WiX Toolset v3.11\bin",
        "C:\Program Files\WiX Toolset v4.0\bin"
    )
    foreach ($path in $wixPaths) {
        if (Test-Path $path) {
            $WixDir = $path
            break
        }
    }

    # 也尝试从 PATH 查找
    if (-not $WixDir) {
        $wixExe = (Get-Command wixl -ErrorAction SilentlyContinue)?.Source
        if ($wixExe) {
            $WixDir = Split-Path $wixExe
        }
    }

    if ($WixDir) {
        Write-Host "  WiX 路径: $WixDir"
        
        # 生成 LICENSE.rtf (WiX UI 需要)
        $LicenseRtf = Join-Path (Split-Path $WxsScript) "LICENSE.rtf"
        $LicenseTxt = Join-Path $ProjectRoot "LICENSE"
        if (Test-Path $LicenseTxt) {
            $content = Get-Content $LicenseTxt -Raw
            $rtfContent = "{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss\fcharset0 Arial;}}\fs20 " + ($content -replace "`r`n", "\par ") + "}"
            Set-Content -Path $LicenseRtf -Value $rtfContent -Encoding UTF8
        }

        $Candle = Join-Path $WixDir "candle.exe"
        $Light = Join-Path $WixDir "light.exe"
        $Wixl = Join-Path $WixDir "wixl.exe"

        if (Test-Path $Candle) {
            # WiX v3
            $MsiFile = Join-Path $PackageDir "cnmd-${Version}-windows-x64.msi"
            $ObjFile = Join-Path $PackageDir "cnmd.wixobj"
            
            & $Candle -nologo -arch x64 -out $ObjFile $WxsScript
            if ($LASTEXITCODE -ne 0) { throw "WiX Candle 失败" }
            
            & $Light -nologo -out $MsiFile $ObjFile
            if ($LASTEXITCODE -ne 0) { throw "WiX Light 失败" }
            
            Write-Host "  [完成] .msi 安装包: $MsiFile"
        } elseif (Test-Path $Wixl) {
            # WiX v4 (wixl)
            $MsiFile = Join-Path $PackageDir "cnmd-${Version}-windows-x64.msi"
            
            & $Wixl -nologo -arch x64 -d ProductVersion=$Version -o $MsiFile $WxsScript
            if ($LASTEXITCODE -ne 0) { throw "WiX wixl 失败" }
            
            Write-Host "  [完成] .msi 安装包: $MsiFile"
        } else {
            Write-Warning "未找到 WiX 编译工具 (candle.exe 或 wixl.exe)。跳过 .msi 生成。"
        }
    } else {
        Write-Warning "未找到 WiX Toolset。跳过 .msi 生成。请安装 WiX: https://wixtoolset.org/"
    }
} else {
    Write-Host ""
    Write-Host "[步骤 4/5] 跳过 .msi 生成"
}

# ===== 步骤 5: 生成便携版 =====
Write-Host ""
Write-Host "[步骤 5/5] 生成便携版压缩包..."

$PortableFile = Join-Path $PackageDir "cnmd-${Version}-windows-x64-portable.zip"
if (Test-Path $PortableFile) {
    Remove-Item -Force $PortableFile
}

Compress-Archive -Path $StagingDir -DestinationPath $PortableFile -CompressionLevel Optimal
Write-Host "  [完成] 便携版: $PortableFile"

# ===== 完成 =====
Write-Host ""
Write-Host "=========================================="
Write-Host "  打包完成!"
Write-Host "=========================================="
Write-Host ""
Write-Host "生成的文件:"
Get-ChildItem -Path $PackageDir -File | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  $($_.Name) ($sizeMB MB)"
}
Write-Host ""
Write-Host "输出目录: $PackageDir"
