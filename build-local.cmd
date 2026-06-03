@echo off
REM ============================================================
REM UUP → Tiny11 本地一键构建脚本
REM ============================================================
REM 使用方法：
REM   1. 把本脚本放到你的 UUPDump 下载文件夹中
REM   2. 以管理员身份运行
REM   3. 选择精简变体（standard / core / nano）
REM ============================================================

setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ========================================
echo   UUP → Tiny11 Local Builder
echo ========================================
echo.
echo 当前目录: %CD%

REM ---- 步骤1：检查 UUPDump 文件是否存在 ----
if not exist "uup_download_windows.cmd" (
    echo [错误] 未找到 uup_download_windows.cmd！
    echo        请确保本脚本放在 UUPDump 下载文件夹中运行。
    pause
    exit /b 1
)
echo [OK] 找到 uup_download_windows.cmd

REM ---- 步骤2：检查/下载 tiny11 脚本 ----
if not exist "scripts" mkdir scripts

if not exist "scripts\tiny11coremaker-headless.ps1" (
    echo [信息] 正在下载 tiny11 还原脚本...
    REM 从 kof8855/uup2tiny11 下载
    curl -L -o "scripts\tiny11maker-headless.ps1" ^
        "https://raw.githubusercontent.com/kof8855/uup2tiny11/main/scripts/tiny11maker-headless.ps1"
    curl -L -o "scripts\tiny11coremaker-headless.ps1" ^
        "https://raw.githubusercontent.com/kof8855/uup2tiny11/main/scripts/tiny11coremaker-headless.ps1"
    curl -L -o "scripts\nano11builder-headless.ps1" ^
        "https://raw.githubusercontent.com/kof8855/uup2tiny11/main/scripts/nano11builder-headless.ps1"
    echo [OK] 脚本下载完成
) else (
    echo [OK] tiny11 脚本已存在
)

REM ---- 步骤3：下载 autounattend.xml ----
if not exist "autounattend.xml" (
    echo [信息] 正在下载 autounattend.xml...
    curl -L -o "autounattend.xml" ^
        "https://raw.githubusercontent.com/kof8855/uup2tiny11/main/autounattend.xml"
    echo [OK] autounattend.xml 下载完成
) else (
    echo [OK] autounattend.xml 已存在
)

REM ---- 步骤4：确认 ConvertConfig.ini 设置 ----
echo.
echo ========================================
echo   检查 ConvertConfig.ini 设置
echo ========================================
if exist "ConvertConfig.ini" (
    findstr /b "AddUpdates" ConvertConfig.ini >nul
    if !errorlevel! equ 0 (
        REM 读取当前值
        for /f "tokens=2 delims==" %%a in ('findstr /b "AddUpdates" ConvertConfig.ini') do set ADD_UPDATES=%%a
        echo 当前 AddUpdates=!ADD_UPDATES!
        if "!ADD_UPDATES!"=="1" (
            echo [警告] AddUpdates=1 会集成 Windows 更新，构建时间可能很长（1-3小时）
            echo [提示] 如想加速，可编辑 ConvertConfig.ini 改为 AddUpdates=0
        )
    ) else (
        echo [信息] ConvertConfig.ini 中未找到 AddUpdates 设置
    )
) else (
    echo [警告] 未找到 ConvertConfig.ini
)

REM ---- 步骤5：选择精简变体 ----
echo.
echo ========================================
echo   请选择精简变体:
echo ========================================
echo   1) Standard  - 标准精简（保留大部分功能）
echo   2) Core      - 核心精简（推荐，最平衡）
echo   3) Nano      - 极限精简（最小体积）
echo.
set /p VARIANT_CHOICE="请选择 (1/2/3, 默认 2): "
if "%VARIANT_CHOICE%"=="" set VARIANT_CHOICE=2

set VARIANT=core
if "%VARIANT_CHOICE%"=="1" set VARIANT=standard
if "%VARIANT_CHOICE%"=="2" set VARIANT=core
if "%VARIANT_CHOICE%"=="3" set VARIANT=nano

echo 已选择: %VARIANT%
echo.

REM ---- 步骤6：检查 AutoExit 设置 ----
echo [信息] 确保 ConvertConfig.ini 中有 AutoExit=1...
REM 如果没设置，追加一行
findstr /b "AutoExit" ConvertConfig.ini >nul
if errorlevel 1 (
    echo AutoExit=1>> ConvertConfig.ini
    echo [OK] 已添加 AutoExit=1
)

REM ---- 步骤7：构建 ISO ----
echo.
echo ========================================
echo   开始构建 Windows ISO ...
echo   这需要较长时间（通常 30 分钟 ~ 2 小时）
echo ========================================
echo [开始] %date% %time%
call uup_download_windows.cmd
if errorlevel 1 (
    echo [错误] ISO 构建失败，请检查上方日志
    pause
    exit /b 1
)
echo [完成] %date% %time%

REM ---- 步骤8：查找生成的 ISO ----
echo.
echo ========================================
echo   查找生成的 ISO 文件...
echo ========================================
set ISO_FILE=
for /r %%i in (*.iso) do set ISO_FILE=%%i
if not defined ISO_FILE (
    echo [错误] 未找到 ISO 文件！
    dir *.iso /s
    pause
    exit /b 1
)
echo [OK] 找到 ISO: %ISO_FILE%

REM ---- 步骤9：复制 autounattend.xml ----
copy /y autounattend.xml scripts\ >nul
echo [OK] autounattend.xml 已复制到 scripts\

REM ---- 步骤10：运行 tiny11 精简 ----
echo.
echo ========================================
echo   开始 %VARIANT% 精简 ...
echo ========================================
echo 源 ISO: %ISO_FILE%

REM 挂载 ISO（获取盘符）
echo [信息] 正在挂载 ISO ...
for /f "tokens=2 delims=:" %%a in ('powershell -Command ^
    "$mount = Mount-DiskImage -ImagePath '%ISO_FILE%' -PassThru -StorageType ISO; ^
    Start-Sleep 3; ^
    $vol = Get-Volume -DiskImage $mount; ^
    Write-Output $vol.DriveLetter"') do set DRIVE=%%a

if not defined DRIVE (
    echo [错误] ISO 挂载失败！
    pause
    exit /b 1
)
set DRIVE=!DRIVE!:
echo [OK] ISO 已挂载到 %DRIVE%

REM 运行对应的 tiny11 脚本
set SCRIPT=scripts\tiny11coremaker-headless.ps1
if "%VARIANT%"=="standard" set SCRIPT=scripts\tiny11maker-headless.ps1
if "%VARIANT%"=="nano" set SCRIPT=scripts\nano11builder-headless.ps1

echo [信息] 运行脚本: %SCRIPT%
echo [信息] ISO 盘符: %DRIVE%
echo [信息] Image Index: 1
echo [开始] %date% %time%

powershell -ExecutionPolicy Bypass -Command ^
    "& '%SCRIPT%' -ISO '%DRIVE%' -INDEX 1"

echo [完成] %date% %time%

REM ---- 步骤11：卸载 ISO ----
echo [信息] 卸载 ISO ...
powershell -Command ^
    "Dismount-DiskImage -ImagePath '%ISO_FILE%' -ErrorAction SilentlyContinue"

REM ---- 步骤12：查找最终输出 ----
echo.
echo ========================================
echo   查找最终输出 ISO ...
echo ========================================
set OUTPUT_ISO=
for /r scripts %%i in (*.iso) do set OUTPUT_ISO=%%i
if defined OUTPUT_ISO (
    for %%i in ("%OUTPUT_ISO%") do (
        set SIZE_GB=%%~zi
        set SIZE_GB=!SIZE_GB!/1073741824
    )
    echo [OK] 构建完成！
    echo 输出文件: %OUTPUT_ISO%
    REM 复制到当前目录
    copy /y "%OUTPUT_ISO%" "%~dp0" >nul
    echo 已复制到当前目录
) else (
    echo [信息] 未在 scripts/ 下找到 ISO，尝试搜索全部 *.iso
    dir *.iso /s
)
echo.
echo ========================================
echo   全部完成！
echo   Administrator 密码: 123456
echo   OOBE 已跳过，直接进入桌面
echo ========================================
pause
