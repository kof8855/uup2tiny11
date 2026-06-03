<# 
.SYNOPSIS
    UUP → Tiny11 本地一键构建 PowerShell 脚本
.DESCRIPTION
    放在 UUPDump 下载文件夹中，以管理员身份运行。
    自动完成：构建 ISO → 挂载 → 精简 → 输出最终 ISO
.NOTES
    Administrator 密码: 123456
    OOBE 已完全跳过
#>

param(
    [ValidateSet("standard", "core", "nano")]
    [string]$Variant = "core",

    [int]$ImageIndex = 1
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  UUP → Tiny11 Local Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "当前目录: $scriptDir"
Write-Host "精简变体: $Variant"
Write-Host ""

# ---- Step 1: 检查 UUPDump 文件 ----
if (-not (Test-Path "uup_download_windows.cmd")) {
    Write-Error "未找到 uup_download_windows.cmd！请在 UUPDump 下载文件夹中运行此脚本。"
    exit 1
}
Write-Host "[OK] 找到 uup_download_windows.cmd" -ForegroundColor Green

# ---- Step 2: 下载 tiny11 脚本（如不存在）----
if (-not (Test-Path "scripts")) { New-Item -ItemType Directory -Path "scripts" -Force | Out-Null }

$scriptsNeeded = @{
    "standard" = "tiny11maker-headless.ps1"
    "core"     = "tiny11coremaker-headless.ps1"
    "nano"     = "nano11builder-headless.ps1"
}

# 检查所有脚本
$allExist = $true
$scriptsNeeded.Values | ForEach-Object {
    if (-not (Test-Path "scripts\$_")) { $allExist = $false }
}

if (-not $allExist) {
    Write-Host "[下载] 下载 tiny11 脚本..." -ForegroundColor Yellow
    $scriptsNeeded.Values | ForEach-Object {
        $url = "https://raw.githubusercontent.com/kof8855/uup2tiny11/main/scripts/$_"
        Invoke-WebRequest -Uri $url -OutFile "scripts\$_" -UseBasicParsing
        Write-Host "  ✓ $_"
    }
    Write-Host "[OK] 脚本下载完成" -ForegroundColor Green
} else {
    Write-Host "[OK] tiny11 脚本已存在" -ForegroundColor Green
}

# ---- Step 3: 下载 autounattend.xml ----
if (-not (Test-Path "autounattend.xml")) {
    Write-Host "[下载] 下载 autounattend.xml..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kof8855/uup2tiny11/main/autounattend.xml" `
        -OutFile "autounattend.xml" -UseBasicParsing
    Write-Host "[OK] autounattend.xml 下载完成" -ForegroundColor Green
} else {
    Write-Host "[OK] autounattend.xml 已存在" -ForegroundColor Green
}

# ---- Step 4: 确保 AutoExit=1 ----
if (Test-Path "ConvertConfig.ini") {
    $config = Get-Content "ConvertConfig.ini"
    if ($config -notmatch "^AutoExit=1") {
        Add-Content "ConvertConfig.ini" "`nAutoExit=1"
        Write-Host "[OK] 已添加 AutoExit=1" -ForegroundColor Green
    }
}

# ---- Step 5: 构建 ISO ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  步骤 1/3: 构建 Windows ISO" -ForegroundColor Cyan
Write-Host "  这可能需要 30分钟 ~ 2小时..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[开始] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

$buildStart = Get-Date
& .\uup_download_windows.cmd
if ($LASTEXITCODE -ne 0) {
    Write-Error "ISO 构建失败！请查看上方日志。"
    exit 1
}
$buildTime = (Get-Date) - $buildStart
Write-Host "[完成] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') (耗时: $($buildTime.TotalMinutes.ToString('F1')) 分钟)" -ForegroundColor Green

# ---- Step 6: 查找 ISO ----
$iso = Get-ChildItem -Path $scriptDir -Filter "*.iso" | Select-Object -First 1
if (-not $iso) {
    Write-Error "未找到生成的 ISO 文件！"
    Get-ChildItem -Path $scriptDir -Filter "*.iso" -Recurse
    exit 1
}
$isoPath = $iso.FullName
$isoSize = [math]::Round($iso.Length / 1GB, 2)
Write-Host "[OK] 找到 ISO: $isoPath (${isoSize} GB)" -ForegroundColor Green

# ---- Step 7: 挂载 ISO ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  步骤 2/3: 挂载 ISO 并运行精简" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "[信息] 正在挂载 ISO..." -ForegroundColor Yellow
$mount = Mount-DiskImage -ImagePath $isoPath -PassThru -StorageType ISO
Start-Sleep 3

$driveLetter = $null
for ($i = 0; $i -lt 12; $i++) {
    Start-Sleep -Seconds 5
    try {
        $vol = Get-Volume -DiskImage $mount -ErrorAction SilentlyContinue
        if ($vol -and $vol.DriveLetter) {
            $driveLetter = $vol.DriveLetter
            break
        }
    } catch { }
}

if (-not $driveLetter) {
    # WMI fallback
    $drive = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 5 } | Select-Object -First 1
    if ($drive) {
        $driveLetter = $drive.DeviceID.TrimEnd(':')
    } else {
        Write-Error "无法获取 ISO 挂载盘符"
        exit 1
    }
}

$drivePath = "${driveLetter}:"
Write-Host "[OK] ISO 已挂载到 $drivePath" -ForegroundColor Green

# ---- Step 8: 复制 autounattend.xml ----
Copy-Item "autounattend.xml" "scripts\autounattend.xml" -Force
Write-Host "[OK] autounattend.xml 已复制到 scripts\" -ForegroundColor Green

# ---- Step 9: 运行 tiny11 精简 ----
$scriptMap = @{
    "standard" = "scripts\tiny11maker-headless.ps1"
    "core"     = "scripts\tiny11coremaker-headless.ps1"
    "nano"     = "scripts\nano11builder-headless.ps1"
}
$targetScript = $scriptMap[$Variant]

Write-Host "[信息] 运行: $targetScript" -ForegroundColor Yellow
Write-Host "[信息] ISO: $drivePath, Index: $ImageIndex" -ForegroundColor Yellow
Write-Host "[开始] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

$tinyStart = Get-Date
& $targetScript -ISO $drivePath -INDEX $ImageIndex
$tinyTime = (Get-Date) - $tinyStart
Write-Host "[完成] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') (耗时: $($tinyTime.TotalMinutes.ToString('F1')) 分钟)" -ForegroundColor Green

# ---- Step 10: 卸载 ISO ----
Write-Host "[信息] 卸载 ISO..." -ForegroundColor Yellow
Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue | Out-Null

# ---- Step 11: 查找输出 ISO ----
$outputNames = @{
    "standard" = "tiny11.iso"
    "core"     = "tiny11-core.iso"
    "nano"     = "nano11.iso"
}
$outputName = $outputNames[$Variant]
$outputPath = Join-Path $scriptDir "scripts\$outputName"

if (Test-Path $outputPath) {
    $finalSize = [math]::Round((Get-Item $outputPath).Length / 1GB, 2)
    $finalName = "UUP-Tiny11-${Variant}-$(Get-Date -Format 'yyyyMMdd-HHmmss').iso"
    Copy-Item $outputPath (Join-Path $scriptDir $finalName) -Force

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✅ 全部完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  输出文件: $finalName" -ForegroundColor White
    Write-Host "  文件大小: ${finalSize} GB" -ForegroundColor White
    Write-Host "  变体:     $Variant" -ForegroundColor White
    Write-Host ""
    Write-Host "  安装信息:" -ForegroundColor Yellow
    Write-Host "  • 用户名:  Administrator" -ForegroundColor Yellow
    Write-Host "  • 密码:     123456" -ForegroundColor Yellow
    Write-Host "  • OOBE:    已跳过（直接进桌面）" -ForegroundColor Yellow
    Write-Host "  • 时区:    UTC+8（中国标准时间）" -ForegroundColor Yellow
} else {
    Write-Warning "未在 scripts\ 下找到输出 ISO，请检查: $outputPath"
    Write-Host "搜索所有 ISO:" -ForegroundColor Yellow
    Get-ChildItem -Path $scriptDir -Recurse -Filter "*.iso" | Format-Table FullName, Length, LastWriteTime -AutoSize
}

Write-Host ""
Write-Host "总耗时: $((Get-Date - $buildStart).TotalMinutes.ToString('F1')) 分钟"
Write-Host ""
