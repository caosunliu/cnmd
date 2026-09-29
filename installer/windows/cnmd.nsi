; ==========================================
; CNMD Database NSIS Installer Script
; 生成 .exe 安装包
; ==========================================

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "WinMessages.nsh"
!include "x64.nsh"

; ===== 版本信息 =====
!define PRODUCT_NAME "CNMD"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "CNMD Team"
!define PRODUCT_WEB_SITE "https://github.com/cnmd/cnmd"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"
!define PRODUCT_STARTMENU_REGVAL "NSIS:StartMenuDir"

; ===== 安装包属性 =====
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "cnmd-${PRODUCT_VERSION}-windows-x64.exe"
InstallDir "C:\cnmd"
InstallDirRegKey HKLM "Software\${PRODUCT_NAME}" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
Unicode True

; ===== 版本信息 =====
VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME} Database Installer"
VIAddVersionKey "LegalCopyright" "Copyright (C) 2024 ${PRODUCT_PUBLISHER}"

; ===== 界面设置 =====
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\modern.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\modern.bmp"

; ===== 欢迎页面 =====
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU "Application" $STARTMENU_FOLDER
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; ===== 卸载页面 =====
!insertmacro MUI_UNPAGE_INSTFILES

; ===== 语言 =====
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

; ===== 初始化 =====
Function .onInit
    ${If} ${RunningX64}
        SetRegView 64
    ${EndIf}
FunctionEnd

Function un.onInit
    ${If} ${RunningX64}
        SetRegView 64
    ${EndIf}
FunctionEnd

; ===== 安装区段 =====
Section "CNMD 核心文件 (必须)" SecCore
    SectionIn RO
    
    SetOutPath "$INSTDIR"
    SetOverwrite on
    
    ; 复制核心文件
    File /r "staging\cnmd\*.*"
    
    ; 创建数据目录
    CreateDirectory "$INSTDIR\data"
    
    ; 创建卸载程序
    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    ; 写入注册表
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
    WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoModify" 1
    WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoRepair" 1
    
    ; 获取安装大小
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "EstimatedSize" "$0"
    
    ; 开始菜单
    !insertmacro MUI_STARTMENU_WRITE_BEGIN "Application"
        CreateDirectory "$SMPROGRAMS\$STARTMENU_FOLDER"
        CreateShortCut "$SMPROGRAMS\$STARTMENU_FOLDER\CNMD Shell.lnk" "$INSTDIR\bin\psql.exe" "--host=localhost --port=5432 --username=cnmd"
        CreateShortCut "$SMPROGRAMS\$STARTMENU_FOLDER\CNMD Server.lnk" "$INSTDIR\bin\pg_ctl.exe" "-D $INSTDIR\data start"
        CreateShortCut "$SMPROGRAMS\$STARTMENU_FOLDER\Uninstall.lnk" "$INSTDIR\uninstall.exe"
    !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

Section "环境变量配置" SecEnv
    ; 添加到系统 PATH
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\bin"
    
    ; 设置 CNMD_HOME 环境变量
    System::Call 'advapi32::SetEnvironmentVariable(t "CNMD_HOME", t "$INSTDIR") i'
SectionEnd

Section "Windows 服务" SecService
    ; 安装为 Windows 服务
    DetailPrint "注册 CNMD 服务..."
    nsExec::ExecToLog '"$INSTDIR\bin\pg_ctl.exe" register -N "cnmd" -D "$INSTDIR\data" -w'
SectionEnd

Section "初始化数据库" SecInit
    ; 初始化数据库集群
    DetailPrint "初始化数据库..."
    nsExec::ExecToLog '"$INSTDIR\bin\initdb.exe" -D "$INSTDIR\data" -U cnmd --encoding=UTF8 --locale=C'
SectionEnd

Section "-Post"
    ; 完成信息
    DetailPrint ""
    DetailPrint "=========================================="
    DetailPrint "  CNMD ${PRODUCT_VERSION} 安装完成!"
    DetailPrint "=========================================="
    DetailPrint ""
    DetailPrint "安装路径: $INSTDIR"
    DetailPrint "数据目录: $INSTDIR\data"
    DetailPrint ""
    DetailPrint "使用方法:"
    DetailPrint "  1. 启动服务: net start cnmd"
    DetailPrint "  2. 连接数据库: $INSTDIR\bin\psql.exe -U cnmd"
    DetailPrint "  3. 停止服务: net stop cnmd"
SectionEnd

; ===== 卸载区段 =====
Section "Uninstall"
    ; 停止并删除服务
    nsExec::ExecToLog '"$INSTDIR\bin\pg_ctl.exe" stop -D "$INSTDIR\data" -m fast -w" 2>$1
    
    ; 使用 sc 命令删除服务
    nsExec::ExecToLog 'sc stop cnmd' 2>$1
    nsExec::ExecToLog 'sc delete cnmd' 2>$1
    
    ; 从 PATH 移除
    ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\bin"
    
    ; 删除环境变量
    System::Call 'advapi32::SetEnvironmentVariable(t "CNMD_HOME", t "") i'
    
    ; 删除文件
    RMDir /r "$INSTDIR"
    
    ; 删除开始菜单
    !insertmacro MUI_STARTMENU_GETFOLDER "Application" $STARTMENU_FOLDER
    RMDir /r "$SMPROGRAMS\$STARTMENU_FOLDER"
    
    ; 删除注册表
    DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
    
    SetAutoClose true
SectionEnd

; ===== 回调 =====
Function .onInstSuccess
    MessageBox MB_ICONINFORMATION "CNMD ${PRODUCT_VERSION} 安装完成!$\n$\n点击确定完成安装。"
FunctionEnd

Function un.onUninstSuccess
    MessageBox MB_ICONINFORMATION "CNMD 已成功卸载。"
FunctionEnd
