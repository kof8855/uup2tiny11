# UUP → Tiny11 Builder

整合 [UUPDumpOnGitHub](https://github.com/Enderxity/UUPDumpOnGitHub) 和 [tiny11-automated](https://github.com/kelexine/tiny11-automated) 两个项目，一键从 UUPDump 构建精简版 Windows 11 ISO。

## 工作流程

```
① 本地用 UUPDump 生成 zip → 上传到 Filebin
② GitHub Actions 下载 UUPDump zip
③ 构建完整 Windows ISO
④ 运行 tiny11 精简脚本（Standard / Core / Nano 可选）
⑤ 生成最终 ISO → 上传到 Artifacts
```

## 系统特性

- **Administrator 账号已启用**，密码：`123456`
- **OOBE 完全跳过**——安装后直接进入桌面
- **系统需求绕过**——TPM、CPU、RAM、SecureBoot 检查全部跳过
- 时区预设为 **中国标准时间 (UTC+8)**

## 使用步骤

### 第一步：Fork 本仓库

点击 GitHub 页面右上角的 **Fork** 按钮，把本仓库复制到你的账号下。

### 第二步：获取 UUPDump Zip

1. 打开 [UUPDump](https://uupdump.net/)
2. 选择你想要的 Windows 版本和语言
3. 在下载页面，选择 **"Download and convert to ISO"** 选项（确保选择包含 `ConvertConfig.ini` 的 ZIP 包）
4. 下载生成的 ZIP 文件到本地

> ⚠️ 注意：UUPDump 生成的 ZIP 文件里必须包含 `uup_download_windows.cmd`、`ConvertConfig.ini`、`files/converter_multi/` 等文件。标准 UUPDump 下载包都符合这个结构。

### 第三步：上传到 Filebin

1. 打开 [Filebin](https://filebin.net/)
2. 把你的 UUPDump ZIP 文件拖进去
3. 上传完成后，浏览器地址栏会显示类似 `https://filebin.net/0uv3y9tjqm0hjb51` 的链接
4. 记下最后这段 **code**（例如 `0uv3y9tjqm0hjb51`）

### 第四步：运行工作流

1. 在你自己 Fork 的仓库中，点击 **Actions** 标签
2. 在左侧选择 **UUP → Tiny11 Build**
3. 点击 **Run workflow** 按钮
4. 填写参数：

| 参数 | 说明 | 示例 |
|---|---|---|
| `filebin_code` | Filebin 的 code | `0uv3y9tjqm0hjb51` |
| `tiny11_variant` | 精简模式 | `standard` / `core` / `nano` |
| `image_index` | 镜像索引 | `1`=Home, `4`=Education, `6`=Pro |
| `enable_dotnet35` | 启用 .NET 3.5（仅 Core 变体） | 默认 `false` |
| `skip_cleanup` | 保留临时文件（调试用） | 默认 `false` |

### 第五步：下载结果

工作流完成后，在 **Summary** 页面底部的 **Artifacts** 区域找到 ISO 文件并下载。

## 精简变体对比

| 变体 | 脚本 | 体积 | 特性 |
|---|---|---|---|
| **Standard** | `tiny11maker-headless.ps1` | ~3-4 GB | 保留 Windows Update，适合日常使用 |
| **Core** | `tiny11coremaker-headless.ps1` | ~2 GB | WinSxS 极致精简，不可更新，适合 VM/测试 |
| **Nano** | `nano11builder-headless.ps1` | ~1.5 GB | 最激进精简（驱动/字体/服务），仅限 VM |

## 文件结构

```
.
├── .github/workflows/build.yml        # GitHub Actions 工作流
├── autounattend.xml                    # 自动应答文件（Admin + OOBE）
├── upload.cmd                          # GoFile 上传脚本（可选）
├── scripts/
│   ├── tiny11maker-headless.ps1        # Standard 精简脚本
│   ├── tiny11coremaker-headless.ps1    # Core 精简脚本
│   ├── nano11builder-headless.ps1      # Nano 精简脚本
│   ├── tiny11maker-BASE.ps1            # Standard 基础脚本（参考）
│   ├── tiny11Coremaker-BASE.ps1        # Core 基础脚本（参考）
│   ├── nano11builder-BASE.ps1          # Nano 基础脚本（参考）
│   ├── discord_notify.py               # Discord 通知脚本（预留）
│   └── microsoft_direct_downloader.py  # 微软直链下载脚本（预留）
└── README.md
```

## 注意事项

1. **管理员密码** `123456` — 请在生产环境前自行修改
2. **Core 和 Nano** 变体移除了 Windows Update 功能，不可安装后续更新
3. 构建耗时约 **60–120 分钟**（取决于 UUPDump 下载速度和 tiny11 精简复杂度）
4. 需要 GitHub Actions 的 Windows runner，免费额度足够使用
5. 所有 PS1 脚本来自 [tiny11-automated](https://github.com/kelexine/tiny11-automated)，未经修改

## Credits

- [Enderxity/UUPDumpOnGitHub](https://github.com/Enderxity/UUPDumpOnGitHub) — Actions 中从 UUPDump 构建 ISO
- [kelexine/tiny11-automated](https://github.com/kelexine/tiny11-automated) — 自动精简 Windows 11
- [ntdevlabs/tiny11builder](https://github.com/ntdevlabs/tiny11builder) — 原始 tiny11 构建脚本
